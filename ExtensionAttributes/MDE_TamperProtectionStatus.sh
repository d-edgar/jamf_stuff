#!/bin/zsh
# MDE: Tamper Protection (Jamf EA)
# Returns block | audit | disabled

MDATP_BIN="$(command -v mdatp || true)"
[[ -z "$MDATP_BIN" ]] && { echo "<result>Not Installed</result>"; exit 0; }

val="$($MDATP_BIN health --field tamper_protection 2>/dev/null | tr -d '\"')"
[[ -z "$val" ]] && val="Unknown"
echo "<result>$val</result>"