#!/bin/sh
set -e

echo "=== Xcode Cloud Post-Clone Script ==="

# Navigate to the Flutter project root
cd "$CI_PRIMARY_REPOSITORY_PATH/my_app"

# Install Flutter SDK
echo "Installing Flutter SDK..."
FLUTTER_HOME="$HOME/flutter"
if [ ! -d "$FLUTTER_HOME" ]; then
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_HOME"
fi
export PATH="$FLUTTER_HOME/bin:$PATH"

# Disable analytics and first-run experience
flutter config --no-analytics
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
pod install

echo "=== Post-Clone Complete ==="
