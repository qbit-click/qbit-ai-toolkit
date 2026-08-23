{
  "schemaVersion": 1,
  "project": "{{PROJECT_ID_JSON}}",
  "repository": "{{REPOSITORY_ID_JSON}}",
  "context": {
    "remote": "{{CONTEXT_REMOTE_JSON}}",
    "branch": "{{CONTEXT_BRANCH_JSON}}",
    "cachePath": ".ai/context/cache/project-context"
  },
  "behavior": {
    "ensureOnStart": true,
    "refreshOnStart": true,
    "loadOnStart": true,
    "checkpointAfterValidation": true,
    "checkpointBeforeHandoff": true,
    "commitContext": true,
    "pushContext": true
  }
}
