# Project-local versus installer ownership

The files under `.ai/tooling` and `.ai/scripts` activate AI tooling for
qbit-ai-toolkit itself. Together with root `.codex` and `.serena` configuration,
they build and run the project-local Serena, Graphify, and Doctor services.

The separate `installers/codex-ai-tooling` tree is a reusable distribution
product for installing equivalent tooling into other repositories. It is not a
build input, runtime dependency, or activation mechanism for qbit-ai-toolkit.
Project-local bootstrap, Doctor, validation, and runtime code must not read,
hash, copy, install, repair, or uninstall installer-owned assets, and must not
invoke qbit-cli.

Project-local activation must become operational independently. Work on the
reusable installer resumes only after the project-local runtime has passed its
build, Serena semantic, Graphify CLI, and Doctor validation.

Balloot was consulted only as a read-only behavioral reference for project-local
activation. No Balloot file or runtime asset is copied or installed here.
