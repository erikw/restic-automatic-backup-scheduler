#!/usr/bin/env bash
# fail on error, unassigned var, pipe error
set -euo pipefail

CONF_DIR="$1"
# Next paths are configurable, getting them as params
RESTIC_PASSWORD_PATH="$2"
BACKUP_EXCLUSIONS_PATH="$3"

declare -A config_values

COMMENTED_LINE_PATTERN="^[[:blank:]]*#"

# --vvv-- PARSE/STORE CONFIGS from backup files --vvv--

# Skip comments and take assignments only (key/value pairs).
filter_var_assignments() {
	local input_file="$1"
	echo "$(grep -v "$COMMENTED_LINE_PATTERN" "$input_file" | egrep '\w+\+?=')"
}

# Remove leading and trailing stuff from var assignment, like exports and trailing comments.
trim_kv_pair() {
	line="$1"
	# considers patterns: key="VALUE" and key+="VALUE"
	echo "$(sed -E 's|.*(\b\w+\b\+?=".*").*|\1|' <<< "$line")"
}

store_env_vars() {
	local config_file_backup="$1"

	local kv_lines="$(filter_var_assignments "$config_file_backup")"

	if [[ "$kv_lines" != '' ]]; then
		while read kv_line; do
			local kv_pair=$(trim_kv_pair "$kv_line" | tr -d '"')
			local key=$(cut -d '=' -f1 <<< "$kv_pair")
			local value=$(cut -d '=' -f2 <<< "$kv_pair")
			config_values["${config_file_backup%\~},${key}"]="$value"  # compound map key: (file,env_var_key)
		done <<< "$kv_lines"
	fi
}

parse_config_backups() {
	local backups="${CONF_DIR}/*~"
	for file in $backups; do
		store_env_vars "$file"
	done
}

# --vvv-- RESTORE CONFIGS --vvv--

restore_env_vars() {
	local config_file="$1"
	for config_key in "${!config_values[@]}"; do
		local env_key=$(cut -d ',' -f2 <<< "$config_key" | sed 's/+/\\+/')  # escape `+`
		sed -i -E "s|(.*${env_key}=\").*(\".*)|\1${config_values[$config_key]}\2|" "$config_file"
	done
}

# Merge previous with potentially new exclusions
restore_exclusions() {
	cat "$BACKUP_EXCLUSIONS_PATH" "${BACKUP_EXCLUSIONS_PATH}~" | sort -u > "$BACKUP_EXCLUSIONS_PATH"
}

restore_password() {
	mv "${RESTIC_PASSWORD_PATH}~" "${RESTIC_PASSWORD_PATH}"
}

restore_configs() {
	echo "Restoring configs..."
	configs="${CONF_DIR}/*[^~]"
	for file in $configs; do
		restore_env_vars "$file"
	done
	restore_exclusions
	restore_password
}

# --vvv-- SUMMARY --vvv--

show_summary() {
	echo -e "\nThe following variables were restored:"
	echo "$(for key in "${!config_values[@]}"; do echo "${key}: ${config_values["$key"]}"; done)" | sort
}

# --vvv-- main --vvv--

parse_config_backups
restore_configs
show_summary
