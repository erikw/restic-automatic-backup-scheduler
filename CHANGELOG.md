# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Allow extra arguments to restic-backup with `$RESTIC_BACKUP_EXTRA_ARGS`.

### Changed
- Align terminology used in README with the one used by B2 for credentials (keyId + applicationKey pair).

## [2.0.0] - 2022-02-01
### Changed
- **BREAKING CHANGE** [#45](https://github.com/erikw/restic-systemd-automatic-backup/pull/45): multiple backup profiles are now supported. Please backup your configuration before upgrading. The setup of configuration files are now laied out differently. See the [README.md](README.md) TL;DR setup section.
  - `restic_backup.sh` has had variables extracted to profiles instead, to allow for configuration of different backups on the same system.
  - `b2_env.sh` is split to two files `_global.env` and `default.env` (the default profile). `_global.env` will have B2 accountID and accountKey and `default.env` has backup paths, and retention.
  - `b2_pw.sh` renamed to pw.txt

### Fixed
- `restic_backup.sh` now finds `.backup_exclude` files on each backup path as intended.

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
- First tagged version to allow Arch's AUR to download a tarball archive to install.
