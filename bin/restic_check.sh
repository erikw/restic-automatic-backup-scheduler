#!/usr/bin/env bash
# Check the backups made with restic to Backblaze B2 for errors.
# See restic_backup.sh on how this script is run (as it's analogous for this script).

set -o errexit
set -o pipefail
[[ "${TRACE-0}" =~ ^1|t|y|true|yes$ ]] && set -o xtrace

# Clean up lock if we are killed.
# If killed by systemd, like $(systemctl stop restic), then it kills the whole cgroup and all it's subprocesses.
# However if we kill this script ourselves, we need this trap that kills all subprocesses manually.
exit_hook() {
	echo "In exit_hook(), being killed" >&2
	jobs -p | xargs kill
	restic unlock
}
trap exit_hook INT TERM

# Assert that all needed environment variables are set.
assert_envvars() {
	local varnames=("$@")
	for varname in "${varnames[@]}"; do
		if [ -z ${!varname+x} ]; then
			printf "%s must be set for this script to work.\n\nDid you forget to source a {{ INSTALL_PREFIX }}/etc/restic/*.env.sh profile in the current shell before executing this script?\n" "$varname" >&2
			exit 1
		fi
	done
}

warn_on_missing_envvars() {
	local unset_envs=()
	local varnames=("$@")
	for varname in "${varnames[@]}"; do
		if [ -z "${!varname}" ]; then
			unset_envs=("${unset_envs[@]}" "$varname")
		fi
	done

	if [ ${#unset_envs[@]} -gt 0 ]; then
		printf "The following env variables are recommended, but have not been set. This script may not work as expected: %s\n" "${unset_envs[*]}" >&2
	fi
}

assert_envvars\
	RESTIC_PASSWORD_FILE RESTIC_REPOSITORY RESTIC_VERBOSITY_LEVEL

warn_on_missing_envvars \
	B2_ACCOUNT_ID B2_ACCOUNT_KEY B2_CONNECTIONS

B2_ARG=
[ -z "${B2_CONNECTIONS+x}" ] || B2_ARG=(--option b2.connections="$B2_CONNECTIONS")

# Remove locks from other stale processes to keep the automated backup running.
# NOTE nope, don't unlock like restic_backup.sh. restic_backup.sh should take precedence over this script.
#restic unlock &
#wait $!

# Check repository for errors.
restic check \
	"${B2_ARG[@]}" \
	--verbose="$RESTIC_VERBOSITY_LEVEL" &
wait $!
