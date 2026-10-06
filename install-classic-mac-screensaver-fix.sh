#!/bin/zsh
# install-classic-mac-screensaver-fix.sh
# Installs a LaunchAgent that periodically restarts WallpaperMacintoshExtension
# to work around the Classic Mac screensaver bug in macOS Sequoia/Tahoe/27,
# where the screensaver only draws a colored rectangle with no animation.

PLIST_LABEL="com.local.fix-wallpaper-extension"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="${LAUNCH_AGENTS_DIR}/${PLIST_LABEL}.plist"
INTERVAL=900  # seconds
DOMAIN="gui/$(id -u)"

# Skip the restart while the screensaver is on screen so it isn't interrupted,
# and always exit 0 so launchd doesn't log a failure when the extension isn't running.
FIX_COMMAND='idle=$(/usr/sbin/ioreg -c IOHIDSystem | /usr/bin/awk "/HIDIdleTime/ {print int(\$NF/1000000000); exit}"); if [ "${idle:-999}" -lt 30 ]; then /usr/bin/killall WallpaperMacintoshExtension 2>/dev/null; fi; exit 0'

# --- Make sure the LaunchAgents folder exists (it may not on a fresh account) ---
if ! mkdir -p "$LAUNCH_AGENTS_DIR"; then
	echo "❌ Could not create $LAUNCH_AGENTS_DIR"
	exit 1
fi

# --- Write the plist ---
cat > "$PLIST_PATH" << EOF || { echo "❌ Failed to write plist to: $PLIST_PATH"; exit 1; }
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>${PLIST_LABEL}</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/sh</string>
		<string>-c</string>
		<string>${FIX_COMMAND}</string>
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

if ! plutil -lint -s "$PLIST_PATH"; then
	echo "❌ Plist at $PLIST_PATH is not valid."
	exit 1
fi

echo "✅ Plist written to: $PLIST_PATH"

# --- Remove the agent if it's already loaded (safe to run more than once) ---
if launchctl print "${DOMAIN}/${PLIST_LABEL}" &>/dev/null; then
	launchctl bootout "${DOMAIN}/${PLIST_LABEL}" 2>/dev/null
	# bootout finishes asynchronously; wait up to 5 seconds before bootstrapping again
	for _ in {1..10}; do
		launchctl print "${DOMAIN}/${PLIST_LABEL}" &>/dev/null || break
		sleep 0.5
	done
fi

# --- Load the agent ---
if (( INTERVAL % 3600 == 0 )); then
	INTERVAL_TEXT="$((INTERVAL / 3600)) hour(s)"
elif (( INTERVAL % 60 == 0 )); then
	INTERVAL_TEXT="$((INTERVAL / 60)) minute(s)"
else
	INTERVAL_TEXT="${INTERVAL} second(s)"
fi

if launchctl bootstrap "$DOMAIN" "$PLIST_PATH"; then
	echo "✅ LaunchAgent loaded successfully."
	echo "   WallpaperMacintoshExtension will be restarted every ${INTERVAL_TEXT} (skipped while the screensaver is running)."
else
	echo "❌ Failed to load LaunchAgent. Check the plist at: $PLIST_PATH"
	exit 1
fi

echo ""
echo "To remove this fix later, run:"
echo "  launchctl bootout ${DOMAIN}/${PLIST_LABEL}; rm \"$PLIST_PATH\""
