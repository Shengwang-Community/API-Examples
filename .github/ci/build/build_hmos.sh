#!/bin/bash
##################################
# HarmonyOS CI Build Script (macOS)
# 
# Environment Variables:
# - Package_Publish: boolean
# - sdk_url: SDK download URL
# - compile_project: boolean - whether to compile the project
# - BUILD_NUMBER: Jenkins build number
# - WORKSPACE: Jenkins workspace path
# - build_date, build_time, release_version, short_version
##################################
export PATH=$PATH:/opt/homebrew/bin

# Record build start time
START_TIME=$(date +%s)
echo "=========================================="
echo "HarmonyOS Build started at: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# Get script and project paths
ci_dir="$(cd "$(dirname "$0")" && pwd)"
base_dir=$(echo "$ci_dir" | awk -F "/.github" '{print $1}')
echo "ci_dir: $ci_dir"
echo "base_dir: $base_dir"

echo ""
echo "=========================================="
echo "Environment Variables"
echo "=========================================="
echo "WORKSPACE: $WORKSPACE"
echo "Package_Publish: $Package_Publish"
echo "is_tag_fetch: $is_tag_fetch"
echo "build_date: $build_date"
echo "build_time: $build_time"
echo "release_version: $release_version"
echo "short_version: $short_version"
echo "BUILD_NUMBER: $BUILD_NUMBER"
echo "sdk_url: $sdk_url"
echo "compile_project: $compile_project"
echo "pwd: $(pwd)"
echo "=========================================="
echo ""

hmos_source_root="$base_dir/HarmonyOS_NEXT/APIExample"
hmos_lib_dir="$hmos_source_root/entry/libs"

# ===== SDK Download =====
echo "=========================================="
echo "Downloading SDK..."
echo "=========================================="

# Check if sdk_url is provided
if [ -z "$sdk_url" ] || [ "$sdk_url" = "none" ]; then
    echo ""
    echo "=========================================="
    echo "❌ CI BUILD FAILED: SDK URL NOT PROVIDED"
    echo "=========================================="
    echo "sdk_url is required for HarmonyOS build"
    echo "Please provide a valid SDK download URL"
    echo "=========================================="
    exit 1
fi

# Get file name from URL
file_name=${sdk_url##*/}
name_without_extension=${file_name%.har}
echo "File name: $file_name"
echo "Name without extension: $name_without_extension"

# Download SDK
echo "Downloading SDK from: $sdk_url"
curl -o "$base_dir/$file_name" "$sdk_url" || { echo "❌ SDK download failed!"; exit 1; }
echo "✅ SDK downloaded successfully"

# Move and rename SDK file
mkdir -p "$hmos_lib_dir"
mv "$base_dir/$file_name" "$hmos_lib_dir/AgoraRtcSdk.har" || { echo "❌ Failed to move SDK file!"; exit 1; }

# Verify file was moved successfully
if [ ! -f "$hmos_lib_dir/AgoraRtcSdk.har" ]; then
    echo "❌ SDK file not found after move!"
    exit 1
fi
echo "✅ SDK installed to: $hmos_lib_dir/AgoraRtcSdk.har"

# Extract version number from file name
SDK_VERSION=$(echo "$name_without_extension" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
if [ -z "$SDK_VERSION" ]; then
    SDK_VERSION="unknown"
fi
echo "SDK Version: $SDK_VERSION"
echo ""

# ===== Create SDK Sample Package =====
echo "=========================================="
echo "Creating SDK sample package..."
echo "=========================================="

hmos_direction=APIExample

# Create SDK sample directory structure
sdk_sample_dir="$base_dir/${name_without_extension:-HarmonyOS_SDK}"
mkdir -p "$sdk_sample_dir/rtc/samples" || { echo "❌ Failed to create directory"; exit 1; }

# Copy API Example code
echo "Copying API Example code..."
cp -rf "$base_dir/HarmonyOS_NEXT/${hmos_direction}" "$sdk_sample_dir/rtc/samples/API-Example" || { echo "❌ Failed to copy API Example"; exit 1; }
echo "✅ API Example code copied successfully"

# Compress package
cd "$base_dir" || { echo "❌ Failed to change directory"; exit 1; }
zip_file="APIExample_HarmonyOS_v${SDK_VERSION}_${BUILD_NUMBER}_$(date "+%Y%m%d%H%M%S").zip"
echo "Creating zip: $zip_file"

# Use 7za if available, otherwise fall back to zip command
if command -v 7za >/dev/null 2>&1; then
    7za a "${zip_file}" "$(basename "$sdk_sample_dir")" > /dev/null || { echo "❌ Compression failed!"; exit 1; }
else
    zip -r "${zip_file}" "$(basename "$sdk_sample_dir")" > /dev/null || { echo "❌ Compression failed!"; exit 1; }
fi
echo "✅ Package created: $zip_file"

# Clean up temporary directory
rm -rf "$sdk_sample_dir"
echo "Temporary directory cleaned up"

# Copy ZIP to WORKSPACE
cp -f "$base_dir/$zip_file" "$WORKSPACE/" || true
echo ""

# ===== Compile Project =====
if [ "$compile_project" = true ]; then
    echo "=========================================="
    echo "Compiling HarmonyOS project..."
    echo "=========================================="
    
    cd "$hmos_source_root" || { echo "❌ Failed to change to source directory"; exit 1; }
    
    if [ -f "./cloud_build.sh" ]; then
        chmod +x ./cloud_build.sh
        ./cloud_build.sh || { echo "❌ Build failed!"; exit 1; }
        echo "✅ Project compiled successfully"
        
        # Copy build artifacts
        echo "Copying build artifacts..."
        cp -f "${hmos_source_root}/"*.hap "${WORKSPACE}/" 2>/dev/null || true
    else
        echo "⚠️ cloud_build.sh not found, skipping compilation"
    fi
    echo ""
fi

# ===== Build Summary =====
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "=========================================="
echo "✅ BUILD COMPLETED SUCCESSFULLY"
echo "=========================================="
echo "Completed at: $(date '+%Y-%m-%d %H:%M:%S')"
if [ $MINUTES -gt 0 ]; then
    echo "Total duration: ${MINUTES}m ${SECONDS}s"
else
    echo "Total duration: ${SECONDS}s"
fi
echo "Output package: $zip_file"
echo "=========================================="
