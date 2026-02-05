#!/bin/bash

# Generate Xcode project using XcodeGen
echo "Generating Xcode project..."
xcodegen generate

# Open the project in Xcode
echo "Opening project in Xcode..."
open PhotoSwipeCleaner.xcodeproj

echo "Setup complete!"