#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

ALLOWED_STATUSES = {
    "PROPOSED", "IN_PROGRESS", "IMPLEMENTED", "VALIDATED", "APPROVED", "MERGED",
    "DEPLOYED", "SUPERSEDED", "STALE", "BLOCKED", "UNKNOWN",
}
FORBIDDEN_KEY = re.compile(r"(password|passwd|secret|token|private.?key|cookie|authorization|dsn|api.?key|client.?secret)", re.I)
FORBIDDEN_VALUE = re.compile(r"(-----BEGIN [A-Z ]*PRIVATE KEY-----|\bBearer\s+[A-Za-z0-9._\-+/=]{8,}|glpat-[A-Za-z0-9_\-]{8,}|gh[pousr]_[A-Za-z0-9]{16,}|sk-[A-Za-z0-9]{16,})", re.I)


def run_git(root: Path, args: list[str], allow_failure: bool = False) -> subprocess.CompletedProcess[str]:
    cp = subprocess.run(["git", "-C", str(root), *args], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if cp.returncode and not allow_failure:
        raise RuntimeError(f"Git command failed in '{root}': git {' '.join(args)}")
    return cp


def git_state(root: Path) -> dict[str, Any]:
    branch = run_git(root, ["rev-parse", "--abbrev-ref", "HEAD"]).stdout.strip()
    head = run_git(root, ["rev-parse", "HEAD"]).stdout.strip()
    dirty = bool(run_git(root, ["status", "--porcelain"]).stdout.strip())
    upstream_result = run_git(root, ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"], True)
    upstream = None
    ahead = None
    behind = None
    if upstream_result.returncode == 0 and upstream_result.stdout.strip():
        upstream = upstream_result.stdout.strip()
        counts = run_git(root, ["rev-list", "--left-right", "--count", f"HEAD...{upstream}"], True)
        match = re.match(r"^(\d+)\s+(\d+)$", counts.stdout.strip()) if counts.returncode == 0 else None
        if match:
            ahead, behind = int(match.group(1)), int(match.group(2))
    return {"branch": branch, "head": head, "dirty": dirty, "upstream": upstream, "ahead": ahead, "behind": behind}


def resolve_path(root: Path, value: str) -> Path:
    path = Path(value)
    return path.resolve() if path.is_absolute() else (root / path).resolve()


def require_context_files(context_root: Path) -> None:
    for relative in ("AI_CONTEXT.md", "project/authority.md", "state/current.md", "state/next-action.md", "repositories/repositories.yaml"):
        if not (context_root / relative).is_file():
            raise RuntimeError(f"Central context is missing required file: {relative}")


def read_optional(path: Path) -> str | None:
    return path.read_text(encoding="utf-8-sig") if path.is_file() else None


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes((json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text.replace("\r\n", "\n").replace("\r", "\n").encode("utf-8"))


def runtime_bundle(member_root: Path, context_root: Path, config: dict[str, Any], freshness: str) -> dict[str, Any]:
    member_state = git_state(member_root)
    context_state = git_state(context_root)
    generated = dt.datetime.now().astimezone().isoformat()
    runtime = {
        "schemaVersion": 1,
        "generatedAt": generated,
        "project": str(config["project"]),
        "repository": str(config["repository"]),
        "member": {
            "root": str(member_root),
            "branch": member_state["branch"],
            "head": member_state["head"],
            "dirty": member_state["dirty"],
            "upstream": member_state["upstream"],
            "ahead": member_state["ahead"],
            "behind": member_state["behind"],
        },
        "context": {
            "root": str(context_root),
            "remote": str(config["context"]["remote"]),
            "branch": context_state["branch"],
            "head": context_state["head"],
            "dirty": context_state["dirty"],
            "freshness": freshness,
        },
    }
    bridge = member_root / ".ai-bridge"
    bridge.mkdir(parents=True, exist_ok=True)
    write_json(bridge / "context-runtime.json", runtime)
    lines = [
        "# Runtime AI Context", "", f"Generated: {generated}", f"Repository: {runtime['repository']}",
        f"Repository HEAD: {member_state['head']}", f"Repository branch: {member_state['branch']}",
        f"Repository dirty: {member_state['dirty']}", f"Context HEAD: {context_state['head']}",
        f"Context freshness: {freshness}", "",
        "> This bundle is generated runtime evidence. Canonical implementation sources still outrank AI context.",
    ]
    inputs = [
        ("Central Entry Point", "AI_CONTEXT.md"), ("Authority", "project/authority.md"),
        ("Current Project State", "state/current.md"), ("Next Action", "state/next-action.md"),
        ("Open Questions", "state/open-questions.md"), ("Pending Decisions", "state/pending-decisions.md"),
        ("Repository Map", "repositories/repositories.yaml"),
    ]
    repo_id = str(config["repository"])
    inputs.extend([
        ("Latest Repository State", f"state/repositories/{repo_id}.md"),
        ("Latest Repository Handoff", f"handoffs/repositories/{repo_id}.md"),
        ("Repository Provenance", f"manifests/repositories/{repo_id}.json"),
    ])
    for title, relative in inputs:
        text = read_optional(context_root / relative)
        if text is not None:
            lines.extend(["", f"## {title}", "", f"Source: `{relative}`", "", text.rstrip()])
    write_text(bridge / "context-runtime.md", "\n".join(lines) + "\n")
    return runtime


def validate_checkpoint(checkpoint: dict[str, Any], expected_repository: str) -> None:
    for field in ("schemaVersion", "repository", "scope", "status", "objective", "nextAction"):
        if field not in checkpoint:
            raise RuntimeError(f"Checkpoint is missing required field: {field}")
        if field != "schemaVersion" and not str(checkpoint[field]).strip():
            raise RuntimeError(f"Checkpoint field must not be empty: {field}")
    if int(checkpoint["schemaVersion"]) != 1:
        raise RuntimeError("Unsupported checkpoint schemaVersion.")
    if str(checkpoint["repository"]) != expected_repository:
        raise RuntimeError("Checkpoint repository does not match the active repository config.")
    if str(checkpoint["status"]) not in ALLOWED_STATUSES:
        raise RuntimeError("Checkpoint status is not allowed.")
    for field in ("confirmedFindings", "decisions", "rejectedApproaches", "validation", "openQuestions"):
        value = checkpoint.get(field)
        if not isinstance(value, list):
            raise RuntimeError(f"Checkpoint field must be an array: {field}")


def validate_no_secrets(value: Any, path: str = "$") -> None:
    if value is None:
        return
    if isinstance(value, str):
        if FORBIDDEN_VALUE.search(value):
            raise RuntimeError(f"Checkpoint contains secret-like material at {path}.")
        return
    if isinstance(value, dict):
        for key, child in value.items():
            if FORBIDDEN_KEY.search(str(key)):
                raise RuntimeError(f"Checkpoint contains a forbidden credential-like field at {path}.")
            validate_no_secrets(child, f"{path}.{key}")
        return
    if isinstance(value, (list, tuple)):
        for index, child in enumerate(value):
            validate_no_secrets(child, f"{path}[{index}]")


def bullets(items: list[Any]) -> str:
    if not items:
        return "- None."
    return "\n".join("- " + str(item).strip() for item in items)


def slug(value: str) -> str:
    result = re.sub(r"[^a-z0-9._-]+", "-", value.strip().lower()).strip("-") or "checkpoint"
    return result[:64].rstrip("-") or "checkpoint"


def checkpoint_markdown(checkpoint: dict[str, Any], member_state: dict[str, Any], generated: str) -> str:
    return "\n".join([
        "---", f"date: {generated}", f"status: {checkpoint['status']}", f"repository: {checkpoint['repository']}",
        f"branch: {member_state['branch']}", f"commit: {member_state['head']}", f"dirty: {str(member_state['dirty']).lower()}", "---", "",
        "# Objective", "", str(checkpoint["objective"]), "", "# Confirmed Findings", "", bullets(checkpoint["confirmedFindings"]), "",
        "# Decisions", "", bullets(checkpoint["decisions"]), "", "# Rejected Approaches", "", bullets(checkpoint["rejectedApproaches"]), "",
        "# Validation", "", bullets(checkpoint["validation"]), "", "# Open Questions", "", bullets(checkpoint["openQuestions"]), "",
        "# Next Action", "", str(checkpoint["nextAction"]), "",
    ])


def do_checkpoint(member_root: Path, context_root: Path, config: dict[str, Any], expected_branch: str) -> None:
    context_state = git_state(context_root)
    if context_state["dirty"]:
        raise RuntimeError("Automated checkpoint refused because the central context cache has pre-existing uncommitted changes.")
    checkpoint_path = member_root / ".ai-bridge" / "context-checkpoint.json"
    if not checkpoint_path.is_file():
        raise RuntimeError("No context checkpoint file exists at .ai-bridge/context-checkpoint.json.")
    checkpoint = json.loads(checkpoint_path.read_text(encoding="utf-8-sig"))
    validate_checkpoint(checkpoint, str(config["repository"]))
    validate_no_secrets(checkpoint)
    member_state = git_state(member_root)
    now = dt.datetime.now().astimezone()
    generated = now.isoformat()
    repo_id = str(config["repository"])
    session_rel = f"sessions/{now:%Y}/{now:%m}/{now:%Y-%m-%d-%H%M%S}-{slug(repo_id)}-{slug(str(checkpoint['scope']))}.md"
    state_rel = f"state/repositories/{repo_id}.md"
    handoff_rel = f"handoffs/repositories/{repo_id}.md"
    manifest_rel = f"manifests/repositories/{repo_id}.json"
    write_text(context_root / session_rel, checkpoint_markdown(checkpoint, member_state, generated))
    state_text = "\n".join([
        f"# Repository State - {repo_id}", "", f"Updated: {generated}", f"Status: `{checkpoint['status']}`",
        f"Branch: `{member_state['branch']}`", f"Commit: `{member_state['head']}`", f"Dirty: `{member_state['dirty']}`", "",
        "## Objective", "", str(checkpoint["objective"]), "", "## Confirmed Findings", "", bullets(checkpoint["confirmedFindings"]), "",
        "## Open Questions", "", bullets(checkpoint["openQuestions"]), "", "## Next Action", "", str(checkpoint["nextAction"]), "",
        f"Latest session: `{session_rel}`", "",
    ])
    write_text(context_root / state_rel, state_text)
    handoff_text = "\n".join([
        f"# Repository Handoff - {repo_id}", "", f"Updated: {generated}", f"Status: `{checkpoint['status']}`", "",
        "## Validation", "", bullets(checkpoint["validation"]), "", "## Decisions", "", bullets(checkpoint["decisions"]), "",
        "## Rejected Approaches", "", bullets(checkpoint["rejectedApproaches"]), "", "## Next Action", "", str(checkpoint["nextAction"]), "",
        f"Session: `{session_rel}`", "",
    ])
    write_text(context_root / handoff_rel, handoff_text)
    manifest = {
        "schemaVersion": 1, "generatedAt": generated, "repository": repo_id, "branch": member_state["branch"],
        "commit": member_state["head"], "dirty": member_state["dirty"], "upstream": member_state["upstream"],
        "ahead": member_state["ahead"], "behind": member_state["behind"], "status": str(checkpoint["status"]),
        "scope": str(checkpoint["scope"]), "session": session_rel,
    }
    write_json(context_root / manifest_rel, manifest)
    paths = [session_rel, state_rel, handoff_rel, manifest_rel]
    run_git(context_root, ["add", "--", *paths])
    run_git(context_root, ["diff", "--cached", "--check"])
    staged = run_git(context_root, ["diff", "--cached", "--name-only"]).stdout.strip()
    if not staged:
        checkpoint_path.unlink(missing_ok=True)
        runtime_bundle(member_root, context_root, config, "CURRENT_OR_FETCHED")
        print("AI context checkpoint produced no changes.")
        return
    message = f"chore(context): checkpoint {repo_id} {slug(str(checkpoint['scope']))}"
    run_git(context_root, ["commit", "-m", message, "--", *paths])
    if bool((config.get("behavior") or {}).get("pushContext")):
        remote = str(config["context"]["remote"])
        pushed = run_git(context_root, ["push", "origin", f"HEAD:{expected_branch}"], True)
        if pushed.returncode:
            run_git(context_root, ["fetch", "origin", expected_branch])
            rebased = run_git(context_root, ["rebase", f"origin/{expected_branch}"], True)
            if rebased.returncode:
                run_git(context_root, ["rebase", "--abort"], True)
                raise RuntimeError("Context push was rejected and automatic rebase could not be completed safely.")
            run_git(context_root, ["push", "origin", f"HEAD:{expected_branch}"])
    checkpoint_path.unlink(missing_ok=True)
    runtime = runtime_bundle(member_root, context_root, config, "CURRENT_OR_FETCHED")
    print(f"AI context checkpoint committed: {runtime['context']['head']}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--action", required=True, choices=("start", "status", "checkpoint"))
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--config-path", required=True)
    args = parser.parse_args()
    member_root = Path(args.repository_root).resolve()
    config_path = Path(args.config_path).resolve()
    if not config_path.is_file():
        raise RuntimeError(f"Context config not found: {config_path}")
    config = json.loads(config_path.read_text(encoding="utf-8-sig"))
    if int(config.get("schemaVersion", 0)) != 1:
        raise RuntimeError("Unsupported context config schemaVersion.")
    cache_value = Path(str(config["context"]["cachePath"]))
    if cache_value.is_absolute():
        raise RuntimeError("AI context cachePath must be repository-relative.")
    context_root = (member_root / cache_value).resolve()
    try:
        relative_cache = context_root.relative_to(member_root)
    except ValueError as exc:
        raise RuntimeError("AI context cachePath must remain inside the member repository.") from exc
    if not relative_cache.parts:
        raise RuntimeError("AI context cachePath must remain inside the member repository.")
    if not (context_root / ".git").exists():
        raise RuntimeError("Central context cache is not a Git repository. Run the member context launcher first.")
    require_context_files(context_root)
    state = git_state(context_root)
    expected_branch = str(config["context"]["branch"])
    if state["branch"] != expected_branch:
        raise RuntimeError(f"Central context cache must be on branch '{expected_branch}'.")
    if state["dirty"]:
        freshness = "DIRTY_LOCAL_CONTEXT"
    elif state["ahead"] is not None and state["behind"] is not None and state["ahead"] > 0 and state["behind"] > 0:
        freshness = "DIVERGED_LOCAL_CONTEXT"
    elif state["behind"] is not None and state["behind"] > 0:
        freshness = "STALE_LOCAL_CONTEXT"
    else:
        freshness = "CURRENT_OR_FETCHED"
    if args.action == "status":
        print(json.dumps(runtime_bundle(member_root, context_root, config, freshness), ensure_ascii=False, indent=2))
    elif args.action == "start":
        runtime = runtime_bundle(member_root, context_root, config, freshness)
        print(f"AI context ready: {runtime['repository']} @ {runtime['context']['head']} [{freshness}]")
    else:
        do_checkpoint(member_root, context_root, config, expected_branch)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(12)
