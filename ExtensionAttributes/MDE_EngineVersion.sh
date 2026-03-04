#!/bin/zsh
# MDE: Engine Version (Jamf EA)
# Returns the engine version string (e.g., 1.1.25060.3000)

MDATP_BIN="$(command -v mdatp || true)"
[[ -z "$MDATP_BIN" ]] && { echo "<result>Not Installed</result>"; exit 0; }

val="$($MDATP_BIN health --field engine_version 2>/dev/null | tr -d '\"')"
[[ -z "$val" ]] && val="Unknown"
echo "<result>$val</result>"