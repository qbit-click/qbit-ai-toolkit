# Installer maintenance

Update source and tests together. Synchronize validated runtime changes through
`payload-sync.json`, regenerate `payload.sha256`, run payload drift tests, then
run syntax, unit, contract, lifecycle, disposable Doctor/E2E, and project-local
regression gates in that order.

Preserve installer ID and version unless a release explicitly changes them.
Never weaken image, artifact, downloader, path, ownership, transaction, or
isolation checks to make a validator pass.
