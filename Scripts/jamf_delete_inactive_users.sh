#!/bin/bash

###############################################################################
# jamf_delete_inactive_users.sh
#
# Purpose:  Delete local user accounts that have been inactive for a
#           specified number of days. Designed to run as a Jamf Pro script
#           with configurable parameters.
#
# Jamf Parameters:
#   $4  - DAYS_THRESHOLD    (Required) Number of inactive days before deletion.
#                            Example: 90
#   $5  - DETECTION_METHOD  (Optional) How to determine last activity.
#                            "folder"  = home folder modification date (default)
#                            "login"   = last console login from system records
#   $6  - EXTRA_EXCLUSIONS  (Optional) Comma-separated list of usernames to
#                            protect from deletion (in addition to built-in
#                            exclusions). Example: "labuser,sharedaccount"
#   $7  - DRY_RUN           (Optional) Set to "true" to log actions without
#                            actually deleting anything. Default: "false"
#
# Built-in exclusions (never deleted):
#   root, admin, Guest, Shared, _mbsetupuser, daemon, nobody,
#   and the currently logged-in user.
#
# Author:   Generated for Jamf Pro deployment
# Date:     2026-03-10
###############################################################################

# ============================ Parameter Mapping ==============================

DAYS_THRESHOLD="${4}"
DETECTION_METHOD="${5:-folder}"
EXTRA_EXCLUSIONS="${6}"
DRY_RUN="${7:-false}"

# ============================== Configuration ================================

LOG_FILE="/var/log/jamf_user_cleanup.log"
SCRIPT_NAME="$(basename "$0")"

# Built-in accounts and system accounts that must never be deleted
BUILTIN_EXCLUSIONS=(
    "root"
    "administrator"
    "Guest"
    "Shared"
    "_mbsetupuser"
    "daemon"
    "nobody"
)

# ============================== Functions ====================================

log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "${timestamp} [${level}] ${SCRIPT_NAME}: ${message}" | tee -a "$LOG_FILE"
}

log_info()    { log_message "INFO"    "$1"; }
log_warn()    { log_message "WARNING" "$1"; }
log_error()   { log_message "ERROR"   "$1"; }

# Get the currently logged-in console user (returns "" if at login window)
get_current_user() {
    /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" \
        | /usr/bin/awk '/Name :/ && !/loginwindow/ { print $3 }'
}

# Build the full exclusion list (built-in + current user + custom)
build_exclusion_list() {
    local -a exclusions=("${BUILTIN_EXCLUSIONS[@]}")

    # Add the currently logged-in user
    local current_user
    current_user="$(get_current_user)"
    if [[ -n "$current_user" ]]; then
        exclusions+=("$current_user")
        log_info "Current console user '${current_user}' added to exclusions."
    fi

    # Add any extra exclusions from parameter $6
    if [[ -n "$EXTRA_EXCLUSIONS" ]]; then
        IFS=',' read -ra custom_list <<< "$EXTRA_EXCLUSIONS"
        for user in "${custom_list[@]}"; do
            # Trim whitespace
            user="$(echo "$user" | xargs)"
            if [[ -n "$user" ]]; then
                exclusions+=("$user")
            fi
        done
        log_info "Custom exclusions added: ${EXTRA_EXCLUSIONS}"
    fi

    # Return newline-separated list for easy grep matching
    printf '%s\n' "${exclusions[@]}"
}

# Determine how many days since the user was last active.
# Method: "folder" — uses the home folder's last modification date.
# Method: "login"  — parses the 'last' command for the most recent login.
get_inactive_days() {
    local username="$1"
    local method="$2"
    local home_dir="/Users/${username}"
    local last_active_epoch
    local now_epoch
    now_epoch="$(date +%s)"

    if [[ "$method" == "login" ]]; then
        # Parse the last console login for this user
        local last_login_str
        last_login_str="$(/usr/bin/last -1 "$username" 2>/dev/null \
            | /usr/bin/head -1 \
            | /usr/bin/awk '{
                # The date fields in `last` output vary; grab columns 4-7
                # which typically look like: Mon Mar  9 14:22
                print $4, $5, $6, $7
            }')"

        if [[ -z "$last_login_str" || "$last_login_str" == *"wtmp"* ]]; then
            # No login record found; fall back to folder method
            log_warn "No login record for '${username}', falling back to folder method."
            last_active_epoch="$(/usr/bin/stat -f '%m' "$home_dir" 2>/dev/null)"
        else
            last_active_epoch="$(/bin/date -j -f '%b %d %H:%M' "$last_login_str" '+%s' 2>/dev/null)"
            if [[ -z "$last_active_epoch" ]]; then
                log_warn "Could not parse login date for '${username}', falling back to folder method."
                last_active_epoch="$(/usr/bin/stat -f '%m' "$home_dir" 2>/dev/null)"
            fi
        fi
    else
        # Default: folder modification date
        last_active_epoch="$(/usr/bin/stat -f '%m' "$home_dir" 2>/dev/null)"
    fi

    if [[ -z "$last_active_epoch" ]]; then
        echo "-1"  # Signal that we couldn't determine the date
        return
    fi

    local diff_seconds=$(( now_epoch - last_active_epoch ))
    local diff_days=$(( diff_seconds / 86400 ))
    echo "$diff_days"
}

# Gather detailed info about a user account for reporting
get_user_report_details() {
    local username="$1"
    local home_dir="/Users/${username}"
    local inactive_days="$2"

    # Home directory size (du -sh)
    local dir_size="unknown"
    if [[ -d "$home_dir" ]]; then
        dir_size="$(/usr/bin/du -sh "$home_dir" 2>/dev/null | /usr/bin/awk '{print $1}')"
        [[ -z "$dir_size" ]] && dir_size="unknown"
    fi

    # Last activity date (human-readable)
    local last_active_date="unknown"
    local home_epoch
    home_epoch="$(/usr/bin/stat -f '%m' "$home_dir" 2>/dev/null)"
    if [[ -n "$home_epoch" ]]; then
        last_active_date="$(/bin/date -r "$home_epoch" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
        [[ -z "$last_active_date" ]] && last_active_date="unknown"
    fi

    # User's real name from Directory Services
    local real_name
    real_name="$(/usr/bin/dscl . -read "/Users/${username}" RealName 2>/dev/null \
        | /usr/bin/sed -n '2p' | /usr/bin/xargs)"
    [[ -z "$real_name" ]] && real_name="(none)"

    # User UID
    local uid
    uid="$(/usr/bin/dscl . -read "/Users/${username}" UniqueID 2>/dev/null \
        | /usr/bin/awk '{print $2}')"
    [[ -z "$uid" ]] && uid="unknown"

    echo "username=${username}|real_name=${real_name}|uid=${uid}|home_dir=${home_dir}|dir_size=${dir_size}|inactive_days=${inactive_days}|last_active=${last_active_date}"
}

# Delete a user account and home directory using sysadminctl
# In dry-run mode, this function ONLY logs — all destructive commands are skipped.
delete_user() {
    local username="$1"
    local inactive_days="$2"
    local home_dir="/Users/${username}"

    # ---- DRY RUN: report only, no destructive actions ----
    if [[ "$DRY_RUN" == "true" ]]; then
        local details
        details="$(get_user_report_details "$username" "$inactive_days")"

        local dir_size real_name uid last_active
        dir_size="$(echo "$details"  | /usr/bin/sed 's/.*dir_size=\([^|]*\).*/\1/')"
        real_name="$(echo "$details" | /usr/bin/sed 's/.*real_name=\([^|]*\).*/\1/')"
        uid="$(echo "$details"       | /usr/bin/sed 's/.*uid=\([^|]*\).*/\1/')"
        last_active="$(echo "$details" | /usr/bin/sed 's/.*last_active=\([^|]*\).*/\1/')"

        log_info "[DRY RUN] ---- Would delete user '${username}' ----"
        log_info "[DRY RUN]   Real name:        ${real_name}"
        log_info "[DRY RUN]   UID:              ${uid}"
        log_info "[DRY RUN]   Home directory:    ${home_dir}"
        log_info "[DRY RUN]   Home dir size:     ${dir_size}"
        log_info "[DRY RUN]   Inactive days:     ${inactive_days}"
        log_info "[DRY RUN]   Last active:       ${last_active}"
        log_info "[DRY RUN]   Action:            sysadminctl -deleteUser ${username}"
        log_info "[DRY RUN]   Action:            Remove home directory ${home_dir}"

        # Accumulate into the dry-run report array for the summary
        DRY_RUN_REPORT+=("${username}|${real_name}|${uid}|${dir_size}|${inactive_days}|${last_active}")

        return 0
    fi

    # ---- LIVE MODE: actually delete ----
    log_info "Deleting user account '${username}'..."

    # Use sysadminctl to delete the user (removes account + home dir)
    /usr/sbin/sysadminctl -deleteUser "$username" 2>&1 | while read -r line; do
        log_info "  sysadminctl: ${line}"
    done

    # Verify deletion
    if /usr/bin/dscl . -read "/Users/${username}" &>/dev/null; then
        log_error "Failed to delete user record for '${username}'. Attempting dscl fallback..."
        /usr/bin/dscl . -delete "/Users/${username}" 2>&1 | while read -r line; do
            log_info "  dscl: ${line}"
        done
    fi

    # Clean up home directory if it still exists
    if [[ -d "$home_dir" ]]; then
        log_warn "Home directory still exists after account deletion. Removing '${home_dir}'..."
        /bin/rm -rf "$home_dir" 2>&1 | while read -r line; do
            log_info "  rm: ${line}"
        done
    fi

    # Verify final state
    if /usr/bin/dscl . -read "/Users/${username}" &>/dev/null || [[ -d "$home_dir" ]]; then
        log_error "Cleanup incomplete for '${username}'. Manual intervention may be required."
        return 1
    else
        log_info "Successfully deleted user '${username}'."
        return 0
    fi
}

# ================================= Main ======================================

main() {
    # Array to collect dry-run report entries
    DRY_RUN_REPORT=()

    log_info "========== User Cleanup Script Started =========="
    log_info "Parameters: DAYS_THRESHOLD=${DAYS_THRESHOLD}, METHOD=${DETECTION_METHOD}, DRY_RUN=${DRY_RUN}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "*** DRY RUN MODE — No accounts will be modified or deleted ***"
    fi

    # ---- Validate parameters ----
    if [[ -z "$DAYS_THRESHOLD" ]]; then
        log_error "DAYS_THRESHOLD (parameter \$4) is required but was not provided. Exiting."
        exit 1
    fi

    if ! [[ "$DAYS_THRESHOLD" =~ ^[0-9]+$ ]]; then
        log_error "DAYS_THRESHOLD must be a positive integer. Got: '${DAYS_THRESHOLD}'. Exiting."
        exit 1
    fi

    if [[ "$DETECTION_METHOD" != "folder" && "$DETECTION_METHOD" != "login" ]]; then
        log_warn "Unknown DETECTION_METHOD '${DETECTION_METHOD}'. Defaulting to 'folder'."
        DETECTION_METHOD="folder"
    fi

    # ---- Build exclusion list ----
    local exclusion_list
    exclusion_list="$(build_exclusion_list)"
    log_info "Full exclusion list: $(echo "$exclusion_list" | tr '\n' ', ')"

    # ---- Enumerate local user home directories ----
    local deleted_count=0
    local skipped_count=0
    local error_count=0

    for home_dir in /Users/*/; do
        # Strip trailing slash and extract username
        home_dir="${home_dir%/}"
        local username
        username="$(basename "$home_dir")"

        # Skip if this user is in the exclusion list
        if echo "$exclusion_list" | /usr/bin/grep -qx "$username"; then
            log_info "Skipping excluded user '${username}'."
            skipped_count=$((skipped_count + 1))
            continue
        fi

        # Skip if there's no corresponding user record in Directory Services
        if ! /usr/bin/dscl . -read "/Users/${username}" &>/dev/null; then
            log_warn "No DS record for '${username}' (orphaned home dir). Skipping."
            skipped_count=$((skipped_count + 1))
            continue
        fi

        # Determine inactivity
        local inactive_days
        inactive_days="$(get_inactive_days "$username" "$DETECTION_METHOD")"

        if [[ "$inactive_days" -eq -1 ]]; then
            log_warn "Could not determine last activity for '${username}'. Skipping."
            skipped_count=$((skipped_count + 1))
            continue
        fi

        log_info "User '${username}' has been inactive for ${inactive_days} day(s) (threshold: ${DAYS_THRESHOLD})."

        if [[ "$inactive_days" -ge "$DAYS_THRESHOLD" ]]; then
            if delete_user "$username" "$inactive_days"; then
                deleted_count=$((deleted_count + 1))
            else
                error_count=$((error_count + 1))
            fi
        else
            skipped_count=$((skipped_count + 1))
        fi
    done

    # ---- Summary ----
    log_info "========== Cleanup Summary =========="
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Mode: DRY RUN (no changes were made)"
        log_info "Users that WOULD be deleted: ${deleted_count}"
        log_info "Users skipped (excluded or under threshold): ${skipped_count}"

        if [[ ${#DRY_RUN_REPORT[@]} -gt 0 ]]; then
            log_info ""
            log_info "=============== Dry-Run Deletion Report ==============="
            printf "%-16s %-20s %-8s %-10s %-14s %s\n" \
                "USERNAME" "REAL NAME" "UID" "HOME SIZE" "INACTIVE DAYS" "LAST ACTIVE" \
                | tee -a "$LOG_FILE"
            printf "%-16s %-20s %-8s %-10s %-14s %s\n" \
                "--------" "---------" "---" "---------" "-------------" "-----------" \
                | tee -a "$LOG_FILE"
            for entry in "${DRY_RUN_REPORT[@]}"; do
                IFS='|' read -r r_user r_name r_uid r_size r_days r_active <<< "$entry"
                printf "%-16s %-20s %-8s %-10s %-14s %s\n" \
                    "$r_user" "$r_name" "$r_uid" "$r_size" "$r_days" "$r_active" \
                    | tee -a "$LOG_FILE"
            done
            log_info "======================================================="
            log_info ""
            log_info "To perform actual deletion, re-run with DRY_RUN set to 'false'."
        else
            log_info "No users met the deletion criteria."
        fi
    else
        log_info "Users deleted:  ${deleted_count}"
        log_info "Users skipped:  ${skipped_count}"
        log_info "Errors:         ${error_count}"
    fi
    log_info "========== User Cleanup Script Finished =========="

    if [[ "$error_count" -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main