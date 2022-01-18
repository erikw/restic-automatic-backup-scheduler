# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- `resticw` wrapper for working with different profiles without the need to source the profiles first.
- `$make install` will now make a timestamped backup of any existing `/etc/restic/*` files before installing a newer version.

### Changed
- **BREAKING CHANGE** moved systemd installation with makefile from `/etc/systemd/system` to `/usr/lib/systemd/system` as this is what packages should do. This is to be able to simplify the arch [PKGBUILD](https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=restic-systemd-automatic-backup) so that it does not need to do anything else than `make install`.
   - If you upgrade form an existing install, you should disable and then re-enable the timer, so that the symlink is pointing to the new location of the timer.
   ```console
   # systemctl disable restic-backup@<profile>.timer
   # systemctl enable restic-backup@<profile>.timer
   ```
- **BREAKING CHANGE** moved script installation with makefile from `/usr/local/sbin` to `/sbin` to have a simpler interface to work with `$PREFIX`.

### Fixed
- Installation with custom `PREFIX` now works properly with Make: `$ PREFIX=/usr/local make install` whill now install everything at the expected location. With this, it's easy to use this script as non-root user on e.g. an macOS system.

## [4.0.0] - 2022-02-01
### Fixed
- Use arrays to build up command lines. When fixing `shellcheck(1)` errors, quotes would disable expansion on e.g. $RESTIC_BACKUP_PATHS
   - **BREAKING CHANGE** `RESTIC_BACKUP_PATHS` is now a string with `:` separated values

## [3.0.1] - 2022-02-01
### Fixed
- Environment variable assertion should allow empty values e.g. `RESTIC_BACKUP_EXTRA_ARGS`

## [3.0.0] - 2022-02-01
### Added
- Allow extra arguments to restic-backup with `$RESTIC_BACKUP_EXTRA_ARGS`.
- Add `$RESTIC_VERBOSITY_LEVEL` for debugging.
- Assertion on all needed environment variables in the backup and check scripts.
- Added linter (`shellcheck(1)`) that is run on push and PRs.

### Changed
- **BREAKING CHANGE** renamed
   - `/etc/restic/backup_exclude` to `/etc/restic/backup_exclude.txt`
   - `<backup-dest>/.backup_exclude` to `<backup-dest>/.backup_exclude.txt`.
- **BREAKING CHANGE** renamed envvars for consistency
   - `BACKUP_PATHS` -> `RESTIC_BACKUP_PATHS`
   - `BACKUP_TAG` -> `RESTIC_BACKUP_TAG`
   - `RETENTION_DAYS` -> `RESTIC_RETENTION_DAYS`
   - `RETENTION_WEEKS` -> `RESTIC_RETENTION_WEEKS`
   - `RETENTION_MONTHS` -> `RESTIC_RETENTION_MONTHS`
   - `RETENTION_YEARS` -> `RESTIC_RETENTION_YEARS`
- Align terminology used in README with the one used by B2 for credentials (keyId + applicationKey pair).

## [2.0.0] - 2022-02-01
### Changed
- **BREAKING CHANGE** [#45](https://github.com/erikw/restic-systemd-automatic-backup/pull/45): multiple backup profiles are now supported. Please backup your configuration before upgrading. The setup of configuration files are now laied out differently. See the [README.md](README.md) TL;DR setup section.
  - `restic_backup.sh` has had variables extracted to profiles instead, to allow for configuration of different backups on the same system.
  - `b2_env.sh` is split to two files `_global.env` and `default.env` (the default profile). `_global.env` will have B2 accountID and accountKey and `default.env` has backup paths, and retention.
  - `b2_pw.sh` renamed to pw.txt

### Fixed
- `restic_backup.sh` now finds `.backup_exclude` files on each backup path as intended.
- Install executeables to `$PREFIX/sbin` instead of `$PREFIX/user/local/sbin`, so that `$ PREFIX=/usr/local make install` does what is expected.

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
