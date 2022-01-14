# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2021-12-03
### Fixed
- $(make install) now works for the *.template files ([#40](https://github.com/erikw/restic-systemd-automatic-backup/issues/40))

## [1.0.0] - 2021-12-02
It's time to call this a proper major version!

### Added
- `uninstall` target for `Makefile`
- Add `--prune` to `restic-forget`
- README badges and updates.

### Fixed
- `backup_exclude` destination
- Conflicts for restic-check service

## [0.1.0] - 2019-07-23
- First tagged version.
