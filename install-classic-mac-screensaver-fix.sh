#!/bin/zsh
# install-classic-mac-screensaver-fix.sh
# Installs a LaunchAgent that periodically restarts WallpaperMacintoshExtension
# to work around the Classic Mac screensaver bug in macOS Sequoia/Tahoe

PLIST_LABEL="com.local.fix-wallpaper-extension"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"
INTERVAL=3600  # 1 hour in seconds

# --- Write the plist ---
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>${PLIST_LABEL}</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/bin/killall</string>
		<string>WallpaperMacintoshExtension</string>
	</array>
	<key>StartInterval</key>
	<integer>${INTERVAL}</integer>
	<key>RunAtLoad</key>
	<true/>
	<key>StandardErrorPath</key>
	<string>/dev/null</string>
	<key>StandardOutPath</key>
	<string>/dev/null</string>
</dict>
</plist>
EOF

echo "✅ Plist written to: $PLIST_PATH"

# --- Unload if already loaded (safe to run more than once) ---
launchctl unload "$PLIST_PATH" 2>/dev/null

# --- Load the agent ---
if launchctl load "$PLIST_PATH"; then
	echo "✅ LaunchAgent loaded successfully."
	echo "   WallpaperMacintoshExtension will be restarted every $((INTERVAL / 3600)) hours."
else
	echo "❌ Failed to load LaunchAgent. Check the plist at: $PLIST_PATH"
	exit 1
fi

echo ""
echo "To remove this fix later, run:"
echo "  launchctl unload \"$PLIST_PATH\" && rm \"$PLIST_PATH\""