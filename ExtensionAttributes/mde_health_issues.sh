#!/bin/zsh
# MDE: Health Issues (Jamf EA)
# Returns an array of current health issues (empty [] if none)

MDATP_BIN="$(command -v mdatp || true)"
[[ -z "$MDATP_BIN" ]] && { echo "<result>Not Installed</result>"; exit 0; }

val="$($MDATP_BIN health --field health_issues 2>/dev/null)"

# Normalize output
if [[ -z "$val" ]]; then
    val="Unknown"
elif [[ "$val" == "[]" ]]; then
    val="None"
fi

echo "<result>$val</result>"