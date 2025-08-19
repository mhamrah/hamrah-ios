#!/bin/bash

# Script to configure Google Sign-In for iOS project

PLIST_PATH="hamrahIOS/Info.plist"
GOOGLE_PLIST_PATH="hamrahIOS/GoogleService-Info.plist"

echo "🔧 Configuring Google Sign-In for iOS..."

# Check if GoogleService-Info.plist exists
if [ ! -f "$GOOGLE_PLIST_PATH" ]; then
    echo "❌ GoogleService-Info.plist not found at $GOOGLE_PLIST_PATH"
    echo "Please download it from Firebase Console and place it in the hamrahIOS/ directory"
    exit 1
fi

# Extract REVERSED_CLIENT_ID from GoogleService-Info.plist
REVERSED_CLIENT_ID=$(plutil -extract REVERSED_CLIENT_ID raw "$GOOGLE_PLIST_PATH" 2>/dev/null)

if [ -z "$REVERSED_CLIENT_ID" ]; then
    echo "❌ Could not extract REVERSED_CLIENT_ID from GoogleService-Info.plist"
    exit 1
fi

echo "✅ Found REVERSED_CLIENT_ID: $REVERSED_CLIENT_ID"

# Check if URL scheme already exists
if plutil -extract CFBundleURLTypes json "$PLIST_PATH" | grep -q "$REVERSED_CLIENT_ID"; then
    echo "✅ Google Sign-In URL scheme already configured"
else
    echo "🔧 Adding Google Sign-In URL scheme to Info.plist..."
    
    # Create a temporary plist with the URL scheme
    cat > /tmp/google_url_scheme.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleURLName</key>
    <string>GoogleSignIn</string>
    <key>CFBundleURLSchemes</key>
    <array>
        <string>$REVERSED_CLIENT_ID</string>
    </array>
</dict>
</plist>
EOF
    
    # Check if CFBundleURLTypes already exists
    if plutil -extract CFBundleURLTypes json "$PLIST_PATH" &>/dev/null; then
        echo "🔧 Adding to existing CFBundleURLTypes..."
        # Add to existing array (this is more complex, so we'll show manual instructions)
        echo "⚠️  Please manually add the URL scheme to your existing CFBundleURLTypes array in Info.plist:"
        echo "   - CFBundleURLName: GoogleSignIn"
        echo "   - CFBundleURLSchemes: [$REVERSED_CLIENT_ID]"
    else
        echo "🔧 Creating new CFBundleURLTypes..."
        # Create new CFBundleURLTypes array
        plutil -insert CFBundleURLTypes -xml '<array><dict><key>CFBundleURLName</key><string>GoogleSignIn</string><key>CFBundleURLSchemes</key><array><string>'$REVERSED_CLIENT_ID'</string></array></dict></array>' "$PLIST_PATH"
        echo "✅ URL scheme added successfully"
    fi
    
    rm -f /tmp/google_url_scheme.plist
fi

echo ""
echo "📋 Next steps:"
echo "1. Open hamrahIOS.xcodeproj in Xcode"
echo "2. Add Google Sign-In package dependency:"
echo "   - File → Add Package Dependencies"
echo "   - URL: https://github.com/google/GoogleSignIn-iOS"
echo "   - Version: Up to Next Major 8.0.0"
echo "3. Ensure GoogleService-Info.plist is added to your Xcode project"
echo "4. Build and test on a physical device"
echo ""
echo "✅ Configuration complete!"