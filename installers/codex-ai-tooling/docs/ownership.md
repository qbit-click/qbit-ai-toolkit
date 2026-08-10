# Ownership and conflicts

Full-file ownership is established only by a successful manifest publication.
An absent path may be created. An unchanged owned path may be updated or
removed. A user-modified owned path conflicts by default; the explicit
`owned-modified=replace` policy backs it up before replacement. An unowned
conflicting path is never overwritten, including under replace policy. An
unowned byte-identical path is left unowned.

AGENTS.md, `.gitignore`, and `.gitattributes` use exact marker-owned blocks.
Content outside a block is preserved. Duplicate, nested, reversed, missing, or
user-modified markers are conflicts. TOML, YAML, JSON, and executable files use
full-file ownership rather than textual merge.

Uninstall requires valid ownership state. It removes unchanged owned files and
owned blocks, retains modified content by default, and backs up then removes
modified owned content only under `owned-modified=replace`. It always retains
unowned content and removes only empty known directories.
