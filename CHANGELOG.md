# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Debug scripts by setting `TRACE=1`.
- Add semver-cli for git tagging.
### Changed
- Warn on certain unset envvars instead of error-exit.

## [7.4.0] - 2023-03-08
### Added
- Support saving hourly snapshots. [#98](https://github.com/erikw/restic-automatic-backup-scheduler/pull/98)
- Support for pre backup script at /etc/restic/pre_backup.sh [107](https://github.com/erikw/restic-automatic-backup-scheduler/pull/107)

### Fixed
- Full path to `/bin/bash` in sytemd services. [#96](https://github.com/erikw/restic-automatic-backup-scheduler/issues/96)

## [7.3.4] - 2022-04-29
### Fixed
- Backup stats notifications: fix issue where `restic snapshots --latest 2` will show more than two snapshots due to different backup paths used.

## [7.3.3] - 2022-04-14
### Fixed
- Trying to fix broken Homebrew bottles due to GitHub API issues.

## [7.3.2] - 2022-04-11
### Fixed
- Trying to fix broken Homebrew bottles

## [7.3.1] - 2022-04-11
### Fixed
- `resticw` is now a true wrapper in that it support `--` args to restic.
- OnFailure no longer masked by the stderr redirect to systemd-cat. [#86](https://github.com/erikw/restic-automatic-backup-scheduler/pull/86)

## [7.3.0] - 2022-02-15
### Added
- optional user-controlled notification. See `RESTIC_NOTIFY_BACKUP_STATS` and in `backup.sh`.

## [7.2.0] - 2022-02-15
### Added
- restic-check LaunchAgent.

### Changed
- [README.md](README.md) is restructured with easier TL;DR for each OS and a more general detailed section for the interested.

## [7.1.0] - 2022-02-13
### Changed
- Minimize base install. The following features are now opt-in: nm-unmetered detection, cron_mail, systemd-email.

## [7.0.0] - 2022-02-13
### Changed
- Renamed project from `restic-systemd-automatic-backup` to `restic-automatic-backup-scheduler` to fit all now supported setups.

## [6.0.0] - 2022-02-12
### Added
- Windows support with native ScheduledTask! New target `$ make install-schedtask` for Windows users.

## [5.3.1] - 2022-02-12
### Fixed
- Launchagentdir make macro

## [5.3.0] - 2022-02-12
### Added
- Allow custom launchagent dir, used by Homebrew.

## [5.2.1] - 2022-02-11
### Added
- Homebrew Formula at [erikw/homebrew-tap](https://github.com/erikw/homebrew-tap). You can now install with `$ brew install erikw/tap/restic-automatic-backup-scheduler`!

### Fixed
- Use default profile in LaunchAgent.

## [5.2.0] - 2022-02-11
### Added
- Make option to override destination dir for configuration files. Needed for Homebrew.

### Changed
- Write permissions on installed scripts removed (0755 -> 0555). Homebrew was complaining.

## [5.1.0] - 2022-02-11
### Added
- macos LaunchAgent support. Install with `make install-launchagent` and activate with `make activate-launchagent`. See [README.md](README.md) for details.
- make option INSTALL_PREFIX to make PKGBUILD and such easier to write.

## [5.0.0] - 2022-02-08
### Added
- `resticw` wrapper for working with different profiles without the need to source the profiles first.
- `$ make install-systemd` will now make a timestamped backup of any existing `/etc/restic/*` files before installing a newer version.
- `$ make install-cron` for installing the cron-job.

### Changed
- **BREAKING CHANGE** moved systemd installation with makefile from `/etc/systemd/system` to `/usr/lib/systemd/system` as this is what packages should do. This is to be able to simplify the arch [PKGBUILD](https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=restic-automatic-backup-scheduler) so that it does not need to do anything else than `make install`.
   - If you upgrade form an existing install, you should disable and then re-enable the timer, so that the symlink is pointing to the new location of the timer.
   ```console
   # systemctl disable restic-backup@<profile>.timer
   # systemctl enable restic-backup@<profile>.timer
   ```
- **BREAKING CHANGE** moved script installation with makefile from `/usr/local/sbin` to `/bin` to have a simpler interface to work with `$PREFIX`.
- **BREAKING CHANGE** renamed `etc/restic/*.env` files to `etc/restic/*.env.sh` to clearly communicate that it's a shell script that will be executed (source), and also hint at code editors what file this is to set corect syntax highligting etc. This also enables the shellcheck linter to work more easily on these files as well.
- Renamed top level make install targets. The old `$ make install` is now `$ make install-systemd`

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
- **BREAKING CHANGE** [#45](https://github.com/erikw/restic-automatic-backup-scheduler/pull/45): multiple backup profiles are now supported. Please backup your configuration before upgrading. The setup of configuration files are now laied out differently. See the [README.md](README.md) TL;DR setup section.
  - `restic_backup.sh` has had variables extracted to profiles instead, to allow for configuration of different backups on the same system.
  - `b2_env.sh` is split to two files `_global.env` and `default.env` (the default profile). `_global.env` will have B2 accountID and accountKey and `default.env` has backup paths, and retention.
  - `b2_pw.sh` renamed to pw.txt

### Fixed
- `restic_backup.sh` now finds `.backup_exclude` files on each backup path as intended.
- Install executeables to `$PREFIX/sbin` instead of `$PREFIX/user/local/sbin`, so that `$ PREFIX=/usr/local make install` does what is expected.

## [1.0.1] - 2021-12-03
### Fixed
- $(make install) now works for the *.template files ([#40](https://github.com/erikw/restic-automatic-backup-scheduler/issues/40))

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
