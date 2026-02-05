#!/bin/bash

echo "=========================================="
echo "PhotoSwipeCleaner Build Test"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Step 1: Check XcodeGen
echo ""
echo "Step 1: Checking XcodeGen..."
if command -v xcodegen &> /dev/null; then
    XCODEGEN_VERSION=$(xcodegen --version)
    print_status "XcodeGen found: $XCODEGEN_VERSION"
else
    print_warning "XcodeGen not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install xcodegen
        print_status "XcodeGen installed successfully"
    else
        print_error "Homebrew not found. Please install XcodeGen manually: brew install xcodegen"
        exit 1
    fi
fi

# Step 2: Generate Xcode project
echo ""
echo "Step 2: Generating Xcode project..."
if [ -f "project.yml" ]; then
    xcodegen generate
    if [ -d "PhotoSwipeCleaner.xcodeproj" ]; then
        print_status "Xcode project generated successfully"
    else
        print_error "Failed to generate Xcode project"
        exit 1
    fi
else
    print_error "project.yml not found"
    exit 1
fi

# Step 3: List available simulators
echo ""
echo "Step 3: Available iOS Simulators:"
SIMULATORS=$(xcrun simctl list devices available | grep -E "iPhone|iPad" | head -5)
echo "$SIMULATORS"

# Step 4: Get a simulator ID
echo ""
echo "Step 4: Selecting simulator..."
SIMULATOR_ID=$(xcrun simctl list devices available | grep "iPhone 15" | head -1 | grep -oE '[A-F0-9-]{36}' | head -1)
if [ -z "$SIMULATOR_ID" ]; then
    print_warning "No iPhone 15 simulator found, using generic iOS destination"
    DESTINATION="generic/platform=iOS"
else
    print_status "Using simulator ID: $SIMULATOR_ID"
    DESTINATION="platform=iOS Simulator,id=$SIMULATOR_ID"
fi

# Step 5: Build the project
echo ""
echo "Step 5: Building project..."
echo "Destination: $DESTINATION"
echo ""

BUILD_START=$(date +%s)

xcodebuild -project PhotoSwipeCleaner.xcodeproj \
    -scheme PhotoSwipeCleaner \
    -destination "$DESTINATION" \
    -configuration Debug \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build 2>&1 | tee build.log | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)" | tail -20

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

# Step 6: Check build result
echo ""
echo "=========================================="
echo "Build Result"
echo "=========================================="

if grep -q "BUILD SUCCEEDED" build.log; then
    print_status "Build succeeded!"
    echo "Build time: ${BUILD_TIME}s"
    
    # Show build info
    echo ""
    echo "Build artifacts:"
    ls -la build/Build/Products/Debug-iphoneos/ 2>/dev/null || echo "No artifacts found"
    
    # Cleanup
    rm -f build.log
    
    exit 0
else
    print_error "Build failed!"
    echo ""
    echo "Full build log saved to: build.log"
    echo ""
    echo "Common issues:"
    echo "- Missing dependencies"
    echo "- Code compilation errors"
    echo "- Invalid project configuration"
    echo ""
    echo "Check the build.log for details"
    exit 1
fi
