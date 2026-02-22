#!/bin/bash

# Variables
URL="https://drive.google.com/drive/home"
LINK_NAME="GoogleDrive"
CURRENT_USER=$(scutil --get ConsoleUser | awk '{print $1}')
DESKTOP_PATH="/Users/$CURRENT_USER/Desktop"

# Create the .webloc file
cat <<EOF > "$DESKTOP_PATH/$LINK_NAME.webloc"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>URL</key>
    <string>$URL</string>
</dict>
</plist>
EOF

# Set permissions
chmod 644 "$DESKTOP_PATH/$LINK_NAME.webloc"

echo "Weblink created on the desktop: $DESKTOP_PATH/$LINK_NAME.webloc"
