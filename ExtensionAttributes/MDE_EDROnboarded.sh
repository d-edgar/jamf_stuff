#!/bin/zsh
# MDE: EDR Onboarded (Jamf EA)
# Returns true | false | Unknown

MDATP_BIN="$(command -v mdatp || true)"
[[ -z "$MDATP_BIN" ]] && { echo "<result>Not Installed</result>"; exit 0; }

# Try a direct field first (available in newer builds)
is_onboarded="$($MDATP_BIN health --field is_onboarded 2>/dev/null | tr -d '\"')"

case "$is_onboarded" in
  1) echo "<result>true</result>"; exit 0 ;;
  0) echo "<result>false</result>"; exit 0 ;;
  true|false) echo "<result>$is_onboarded</result>"; exit 0 ;;
esac

# Fallback #1: non-empty org_id generally indicates EDR onboarding
org_id="$($MDATP_BIN health --field org_id 2>/dev/null | tr -d '\"')"
if [[ -n "$org_id" ]]; then
  echo "<result>true</result>"
  exit 0
fi

# Fallback #2: details blob may include edr info in recent builds
details="$($MDATP_BIN health --details edr 2>/dev/null | tr -d '\"' || true)"
if echo "$details" | grep -qi "onboard"; then
  echo "<result>true</result>"
  exit 0
fi

echo "<result>Unknown</result>"