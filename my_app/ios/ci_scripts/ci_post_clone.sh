#!/bin/sh
set -e

echo "=== Xcode Cloud Post-Clone Script ==="

# Suppress all interactive prompts and analytics in CI
# Without CI=true, Flutter may hang waiting for user input
export CI=true

# Start a background heartbeat to prevent Xcode Cloud's 15-minute
# inactivity timeout from killing long-running silent commands.
heartbeat() {
    while true; do
        sleep 300
        echo "[heartbeat] still running... $(date '+%H:%M:%S')"
    done
}
heartbeat &
HEARTBEAT_PID=$!
trap 'kill $HEARTBEAT_PID 2>/dev/null' EXIT

# Navigate to the Flutter project root
cd "$CI_PRIMARY_REPOSITORY_PATH/my_app"

# Install Flutter SDK
echo "Installing Flutter SDK..."
FLUTTER_HOME="$HOME/flutter"
if [ ! -d "$FLUTTER_HOME" ]; then
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_HOME" --progress
fi
export PATH="$FLUTTER_HOME/bin:$PATH"

# Disable analytics and first-run experience
flutter config --no-analytics
dart --disable-analytics 2>/dev/null || true

echo "Running flutter precache --ios..."
flutter precache --ios

echo "Flutter version:"
flutter --version

# Get Flutter dependencies and generate configs
echo "Running flutter pub get..."
flutter pub get

# Install CocoaPods dependencies
echo "Running pod install..."
cd ios
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
pod install --verbose

echo "=== Post-Clone Complete ==="
