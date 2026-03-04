#!/bin/zsh
# MDE: RTP Subsystem (Jamf Extension Attribute)
# Returns the subsystem string (e.g., endpoint_security_extension).

MDATP_BIN="$(command -v mdatp || true)"
[[ -z "$MDATP_BIN" ]] && { echo "<result>Not Installed</result>"; exit 0; }

val="$($MDATP_BIN health --field real_time_protection_subsystem 2>/dev/null | tr -d '\"')"
[[ -z "$val" ]] && val="Unknown"
echo "<result>$val</result>"