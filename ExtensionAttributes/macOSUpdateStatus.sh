#!/bin/bash

# Extension Attribute: macOS Update Eligibility
# Data Type: String
# Input Type: Script
#
# Reports the current macOS version, available macOS updates, and
# whether a major upgrade is available. Useful for Smart Groups
# that target machines needing updates.
#
# Example output:
#   "Current: 14.3.1 | Available: macOS Sequoia 15.2, Security Update 2024-001"
#   "Current: 15.2 | Up to Date"
#   "Current: 13.6.4 | Error checking updates"

currentOS=$(/usr/bin/sw_vers -productVersion)

# Collect available software updates (timeout after 120 seconds to avoid hanging)
updateOutput=$(/usr/bin/timeout 120 /usr/sbin/softwareupdate -l 2>&1)
exitCode=$?

# Handle timeout or failure
if [[ $exitCode -ne 0 ]]; then
    echo "<result>Current: ${currentOS} | Error checking updates</result>"
    exit 0
fi

# Check if there are no updates available
if echo "${updateOutput}" | /usr/bin/grep -q "No new software available"; then
    echo "<result>Current: ${currentOS} | Up to Date</result>"
    exit 0
fi

# Parse available update labels (lines starting with *)
availableUpdates=$(echo "${updateOutput}" | /usr/bin/grep "^\*" | /usr/bin/sed 's/^\* Label: //' | /usr/bin/sed 's/^ *//')

if [[ -z "${availableUpdates}" ]]; then
    # Fallback: try alternate format (some macOS versions use "Title:" instead)
    availableUpdates=$(echo "${updateOutput}" | /usr/bin/grep -i "Title:" | /usr/bin/sed 's/.*Title: //' | /usr/bin/sed 's/,.*//')
fi

if [[ -z "${availableUpdates}" ]]; then
    echo "<result>Current: ${currentOS} | Up to Date</result>"
    exit 0
fi

# Join multiple updates into a comma-separated string
updateList=$(echo "${availableUpdates}" | /usr/bin/paste -sd "," - | /usr/bin/sed 's/,/, /g')

echo "<result>Current: ${currentOS} | Available: ${updateList}</result>"
exit 0
