#!/bin/bash

APP_PATH="$1"

if [ -z "$APP_PATH" ]; then
  echo "Usage: $0 /path/to/VoiceInk.app"
  exit 1
fi

# Find the first available code signing identity
IDENTITY=$(security find-identity -v -p codesigning | grep -Eo '[A-F0-9]{40}' | head -n 1)

if [ -z "$IDENTITY" ]; then
  echo "No valid code signing identity found in your keychain."
  exit 2
fi

# Show the full identity line for user info
IDENTITY_LINE=$(security find-identity -v -p codesigning | grep "$IDENTITY")

echo "Using identity: $IDENTITY_LINE"

# Remove existing accessibility permissions for the app's bundle identifier
BUNDLE_ID="com.darknessest.VoiceInk"
echo "Resetting Accessibility permissions for $BUNDLE_ID ..."
tccutil reset Accessibility "$BUNDLE_ID"

echo "Signing $APP_PATH ..."
# print a command
echo "codesign --deep --force --sign \"$IDENTITY\" \"$APP_PATH\""
codesign --deep --force --sign "$IDENTITY" "$APP_PATH"

if [ $? -eq 0 ]; then
  echo "Successfully signed $APP_PATH"
else
  echo "Failed to sign $APP_PATH"
  exit 3
fi