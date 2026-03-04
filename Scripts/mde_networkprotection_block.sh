#!/bin/bash
# Script to enforce Microsoft Defender ATP network protection to block
# and run Jamf recon afterwards

echo "Setting Microsoft Defender ATP network protection enforcement level to BLOCK..."

mdatp config network-protection enforcement-level --value block

if [ $? -eq 0 ]; then
    echo "Network protection enforcement successfully set to BLOCK."

    echo "Running Jamf recon to update inventory..."
    sudo jamf recon

    if [ $? -eq 0 ]; then
        echo "Jamf recon completed successfully."
    else
        echo "Jamf recon failed."
        exit 1
    fi
else
    echo "Failed to set network protection enforcement."
    exit 1
fi