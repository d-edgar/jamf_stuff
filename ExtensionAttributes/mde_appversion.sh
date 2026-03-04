#!/bin/zsh
# MDE: App Version (Jamf Extension Attribute)
# Returns the MDE app version string.

MDATP_BIN="$(command -v mdatp || true)"
[[ -z "$MDATP_BIN" ]] && { echo "<result>Not Installed</result>"; exit 0; }

val="$($MDATP_BIN health --field app_version 2>/dev/null | tr -d '\"')"
[[ -z "$val" ]] && val="Unknown"
echo "<result>$val</result>"