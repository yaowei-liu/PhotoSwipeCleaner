#!/bin/bash
set -e

echo "🚀 PhotoSwipeCleaner - Project Generator"
echo "========================================"

# Check for XcodeGen
if ! command -v xcodegen &> /dev/null; then
    echo "❌ XcodeGen not found. Install with: brew install xcodegen"
    exit 1
fi

# Generate Xcode project
echo "📦 Generating Xcode project..."
xcodegen generate

echo ""
echo "✅ Project generated successfully!"
echo ""
echo "Next steps:"
echo "1. Open PhotoSwipeCleaner.xcodeproj in Xcode"
echo "2. Select your development team in Signing & Capabilities"
echo "3. Build and run (Cmd+R)"
echo ""