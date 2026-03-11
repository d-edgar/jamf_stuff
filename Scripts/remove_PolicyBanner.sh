#!/bin/bash
###############################################################################
# remove_PolicyBanner.sh
# Removes the PolicyBanner.rtfd login window banner and forgets the package receipt.
#
# Package identifier: policybanner.rtfd
# Installed location:  /Library/Security/PolicyBanner.rtfd
#
# Deploy via Jamf Pro policy (scope to target machines, run as root).
###############################################################################

BANNER_PATH="/Library/Security/PolicyBanner.rtfd"
PKG_ID="policybanner.rtfd"

# Remove the banner directory
if [ -d "$BANNER_PATH" ]; then
    rm -rf "$BANNER_PATH"
    echo "Removed $BANNER_PATH"
else
    echo "$BANNER_PATH not found — may already be removed."
fi

# Forget the package receipt so macOS no longer tracks it
if pkgutil --pkg-info "$PKG_ID" &>/dev/null; then
    pkgutil --forget "$PKG_ID"
    echo "Forgot package receipt for $PKG_ID"
else
    echo "No package receipt found for $PKG_ID — may already be forgotten."
fi

exit 0
