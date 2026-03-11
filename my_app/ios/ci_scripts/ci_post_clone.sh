#!/bin/sh
set -e

echo "=== Xcode Cloud Post-Clone Script ==="

# Navigate to the Flutter project root
cd "$CI_PRIMARY_REPOSITORY_PATH/my_app"

# Install Flutter SDK if not present
if ! command -v flutter &> /dev/null; then
    echo "Installing Flutter SDK..."
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
    export PATH="$HOME/flutter/bin:$PATH"
fi

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
