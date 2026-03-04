#!/bin/zsh
# MDE: Full Disk Access Enabled (Jamf EA)
# Returns true/false if MDE has Full Disk Access granted in Privacy settings.

MDATP_BIN="$(command -v mdatp || true)"
[[ -z "$MDATP_BIN" ]] && { echo "<result>Not Installed</result>"; exit 0; }

val="$($MDATP_BIN health --field full_disk_access_enabled 2>/dev/null | tr -d '\"')"

case "$val" in
  1) val="true" ;;
  0) val="false" ;;
esac

[[ -z "$val" ]] && val="Unknown"
echo "<result>$val</result>"