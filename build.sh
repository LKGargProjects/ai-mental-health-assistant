#!/bin/bash
set -e

echo "=== Starting build process for single codebase deployment ==="
echo "Environment: ${ENVIRONMENT:-local}"
echo "Platform: ${PLATFORM:-unknown}"
echo "Python version: $(/Users/lokeshgarg/ai-mvp-backend/venv/bin/python3 --version)"

# Set build timestamp
export BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "Build time: $BUILD_TIME"

# Install Python dependencies
echo "Installing Python dependencies..."
/Users/lokeshgarg/ai-mvp-backend/venv/bin/pip3 install -r requirements.txt

# Install Flutter with version management
echo "Installing Flutter..."
FLUTTER_VERSION="3.32.8"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

# Check if Flutter is already installed
if [ ! -d "flutter" ]; then
    echo "Downloading Flutter ${FLUTTER_VERSION}..."
    curl -L -o flutter.tar.xz "${FLUTTER_URL}"
    tar xf "flutter.tar.xz"
    rm "flutter.tar.xz"
    echo "✅ Flutter downloaded successfully"
else
    echo "✅ Flutter already installed"
fi

export PATH="$PATH:`pwd`/flutter/bin"

# Verify Flutter installation
echo "Verifying Flutter installation..."
if flutter --version; then
    echo "✅ Flutter verification successful"
else
    echo "❌ Flutter verification failed"
    exit 1
fi

# Build Flutter web app
echo "Building Flutter web app..."
cd ai_buddy_web

# Configure Flutter for web
echo "Configuring Flutter for web..."
flutter config --enable-web

# Clean previous builds
echo "Cleaning previous builds..."
flutter clean

# Get dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Build with error handling and validation
echo "Building Flutter web app with release configuration..."
if flutter build web --release; then
    echo "✅ Flutter build completed successfully!"
    
    # Verify build output
    if [ -d "build/web" ] && [ -f "build/web/index.html" ]; then
        echo "✅ Build artifacts verified"
        
        # Check for critical files
        critical_files=("index.html" "main.dart.js" "flutter.js")
        for file in "${critical_files[@]}"; do
            if [ -f "build/web/$file" ]; then
                echo "✅ Found $file"
            else
                echo "⚠️ Missing $file"
            fi
        done
        
        # Display build info
        echo "=== Build Information ==="
        echo "Build directory: $(pwd)/build/web"
        echo "Build size: $(du -sh build/web | cut -f1)"
        # Copy Flutter build to Flask static folder
        echo "Copying Flutter build to Flask static folder..."

        # Create static directory if it doesn't exist
        mkdir -p ../static

        # Copy built Flutter files to static folder
        echo "Copying Flutter build files..."
        cp -r build/web/* ../static/
        echo "✅ Flutter files copied to static folder"

        # Verify the copy
        if [ -f "../static/index.html" ]; then
            echo "✅ index.html found in static folder"
            echo "Static folder contents:"
            ls -la ../static/
        else
            echo "❌ index.html not found in static folder"
            exit 1
        fi
        echo "Files count: $(find build/web -type f | wc -l)"
        
    else
        echo "❌ Build artifacts missing"
        echo "Expected: build/web/index.html"
        echo "Found: $(ls -la build/web/ 2>/dev/null || echo 'No build/web directory')"
        exit 1
    fi
else
    echo "❌ Flutter build failed"
    echo "Build error details:"
    flutter build web --release --web-renderer canvaskit 2>&1 || true
    exit 1
fi

# Return to root directory
cd ..

# Make start script executable
echo "Making start script executable..."
chmod +x start.sh

# Create build info file
echo "Creating build info..."
cat > build_info.json << EOF
{
  "build_time": "$BUILD_TIME",
  "environment": "${ENVIRONMENT:-local}",
  "platform": "${PLATFORM:-unknown}",
  "flutter_version": "$FLUTTER_VERSION",
  "python_version": "$(python --version 2>&1)",
  "build_status": "success"
}
EOF

echo "=== Build process completed successfully! ==="
echo "Build info saved to: build_info.json"
echo "Ready for deployment to: ${ENVIRONMENT:-local} environment" 
