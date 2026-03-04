#!/bin/zsh
# MDE: Data Loss Prevention Status (Jamf EA)
# Returns current DLP status (enabled | disabled | unknown)

MDATP_BIN="$(command -v mdatp || true)"
[[ -z "$MDATP_BIN" ]] && { echo "<result>Not Installed</result>"; exit 0; }

val="$($MDATP_BIN health --field data_loss_prevention_status 2>/dev/null | tr -d '\"')"
[[ -z "$val" ]] && val="Unknown"

echo "<result>$val</result>"