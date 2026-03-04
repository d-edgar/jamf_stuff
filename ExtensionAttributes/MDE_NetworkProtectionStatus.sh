#!/bin/bash

# Check Defender Network Protection status
NP_STATUS=$(/usr/local/bin/mdatp health --field network_protection_status 2>/dev/null)
NP_ENFORCE=$(/usr/local/bin/mdatp health --field network_protection_enforcement_level 2>/dev/null)

# Jamf EA needs <result> tags
if [[ -z "$NP_STATUS" ]]; then
    echo "<result>Not Installed</result>"
else
    echo "<result>Status: $NP_STATUS | Enforcement: $NP_ENFORCE</result>"
fi