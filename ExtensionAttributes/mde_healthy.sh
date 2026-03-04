#!/bin/zsh
# MDE: Healthy (Jamf Extension Attribute)
# Returns true/false if overall MDE health is good.

MDATP_BIN="$(command -v mdatp || true)"
[[ -z "$MDATP_BIN" ]] && { echo "<result>Not Installed</result>"; exit 0; }

val="$($MDATP_BIN health --field healthy 2>/dev/null | tr -d '\"')"

case "$val" in
  1)  val="true" ;;
  0)  val="false" ;;
esac

[[ -z "$val" ]] && val="Unknown"
echo "<result>$val</result>"