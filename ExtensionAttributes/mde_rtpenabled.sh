#!/bin/zsh
# MDE: RTP Enabled (Jamf Extension Attribute)
# Returns true/false if real-time protection is enabled.

MDATP_BIN="$(command -v mdatp || true)"
[[ -z "$MDATP_BIN" ]] && { echo "<result>Not Installed</result>"; exit 0; }

val="$($MDATP_BIN health --field real_time_protection_enabled 2>/dev/null | tr -d '\"')"

# Normalize possible 1/0 to true/false
case "$val" in
  1)  val="true" ;;
  0)  val="false" ;;
esac

[[ -z "$val" ]] && val="Unknown"
echo "<result>$val</result>"