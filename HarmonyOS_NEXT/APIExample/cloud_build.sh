#!/bin/bash
##################################
# HarmonyOS APIExample Build Script (macOS)
#
# Prerequisites:
# - DevEco Studio installed with command-line tools
# - Signing certificates in ~/Library/HarmonyOS/sign/
#
# Environment Variables:
# - APP_ID: Agora App ID
# - sdk_url: SDK URL (for version extraction)
# - BUILD_NUMBER: Jenkins build number
# - HMOS_KEY_PWD: Signing key password
# - HMOS_SIGN_DIR: (optional) Custom signing directory
##################################

set -e

# Get current script directory
PROJECT_PATH="$(cd "$(dirname "$0")" && pwd)"

# Record build start time
START_TIME=$(date +%s)
echo "=========================================="
echo "HarmonyOS APIExample Build"
echo "Started at: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# ===== Configure APP ID =====
echo "Configuring APP ID..."
sed -i '' "s#YOUR APP ID#${APP_ID}#g" entry/src/main/ets/common/KeyCenter.ets
sed -i '' "s#YOUR APP CERTIFICATE##g" entry/src/main/ets/common/KeyCenter.ets
echo "✅ APP ID configured"

# Extract version from SDK URL
SDK_VERSION=$(echo "$sdk_url" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
if [ -z "$SDK_VERSION" ]; then
    SDK_VERSION="unknown"
fi
echo "SDK Version: $SDK_VERSION"
echo ""

# ===== Configure Environment (macOS) =====
echo "=========================================="
echo "Configuring build environment..."
echo "=========================================="

# Java environment (use system Java or DevEco bundled)
if [ -z "$JAVA_HOME" ]; then
    # Try DevEco Studio bundled JDK
    DEVECO_JDK="/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home"
    if [ -d "$DEVECO_JDK" ]; then
        export JAVA_HOME="$DEVECO_JDK"
    fi
fi
export PATH=$JAVA_HOME/bin:$PATH
echo "JAVA_HOME: $JAVA_HOME"
java -version

# DevEco Studio paths (macOS)
export DEVECO_HOME="/Applications/DevEco-Studio.app/Contents"
export DEVECO_SDK_HOME="${DEVECO_HOME}/sdk"
OHPM_HOME="${DEVECO_HOME}/tools/ohpm"
HVIGOR_HOME="${DEVECO_HOME}/tools/hvigor"
TOOLCHAINS_HOME="${DEVECO_HOME}/sdk/default/openharmony/toolchains"

echo "DevEco Home: $DEVECO_HOME"
echo "DEVECO_SDK_HOME: $DEVECO_SDK_HOME"
echo "OHPM: $OHPM_HOME"
echo "Hvigor: $HVIGOR_HOME"

# Configure PATH for ohpm and hvigorw
export PATH="${OHPM_HOME}/bin:${HVIGOR_HOME}/bin:${TOOLCHAINS_HOME}:$PATH"

# Configure HDC
init_hdc() {
    export HDC_HOME="${TOOLCHAINS_HOME}"
    export PATH=$HDC_HOME:$PATH
}

# Initialize ohpm
init_ohpm() {
    echo "Initializing ohpm..."
    ohpm -v
    ohpm config set registry https://ohpm.openharmony.cn/ohpm/
    echo "✅ ohpm initialized"
}

# Install dependencies
ohpm_install() {
    echo "Installing dependencies in $1..."
    cd "$1"
    ohpm install
}

# Build HAP
buildHAP() {
    echo ""
    echo "=========================================="
    echo "Building HAP..."
    echo "=========================================="
    
    ohpm_install "${PROJECT_PATH}"
    ohpm_install "${PROJECT_PATH}/entry"
    
    cd ${PROJECT_PATH}
    hvigorw clean --no-daemon
    hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
    
    # Check if unsigned HAP was generated (signing may fail but that's OK, we sign manually)
    if [ ! -f "${PROJECT_PATH}/entry/build/default/outputs/default/entry-default-unsigned.hap" ]; then
        echo "❌ HAP build failed - unsigned HAP not found"
        exit 1
    fi
    
    echo "✅ HAP build completed"
}

# Sign HAP
signedHAP() {
    echo ""
    echo "=========================================="
    echo "Signing HAP..."
    echo "=========================================="
    
    # Signing directory (local macOS path)
    local sign_dir="${HMOS_SIGN_DIR:-$HOME/Library/HarmonyOS/sign}"
    
    # Check signing directory exists
    if [ ! -d "$sign_dir" ]; then
        echo "❌ Signing directory not found: $sign_dir"
        exit 1
    fi
    
    # Find certificate files
    local cert_file=$(find "${sign_dir}" -name "*.cer" | head -n 1)
    local p7b_file=$(find "${sign_dir}" -name "*.p7b" | head -n 1)
    local p12_file=$(find "${sign_dir}" -name "*.p12" | head -n 1)
    
    # Verify certificate files exist
    if [ ! -f "$cert_file" ] || [ ! -f "$p7b_file" ] || [ ! -f "$p12_file" ]; then
        echo "❌ Required certificate files not found in: $sign_dir"
        echo "Expected: *.cer, *.p7b, *.p12"
        exit 1
    fi
    
    echo "Certificate: $cert_file"
    echo "Profile: $p7b_file"
    echo "Keystore: $p12_file"
    
    # Get unsigned HAP file
    local unsigned_hap="${PROJECT_PATH}/entry/build/default/outputs/default/entry-default-unsigned.hap"
    if [ ! -f "$unsigned_hap" ]; then
        echo "❌ Unsigned HAP not found: $unsigned_hap"
        exit 1
    fi
    
    # Generate signed HAP filename
    local signed_hap="${PROJECT_PATH}/APIExample_${BUILD_NUMBER}_${SDK_VERSION}_$(date "+%Y%m%d%H%M%S").hap"
    
    # Sign HAP
    echo "Signing HAP..."
    java -jar "${TOOLCHAINS_HOME}/lib/hap-sign-tool.jar" sign-app \
        -keyAlias "wayangAgora" \
        -signAlg "SHA256withECDSA" \
        -mode "localSign" \
        -appCertFile "$cert_file" \
        -profileFile "$p7b_file" \
        -keystoreFile "$p12_file" \
        -inFile "$unsigned_hap" \
        -outFile "$signed_hap" \
        -keyPwd "${HMOS_KEY_PWD}" \
        -keystorePwd "${HMOS_KEY_PWD}" \
        -signCode "1"
    
    if [ $? -ne 0 ]; then
        echo "❌ HAP signing failed"
        exit 1
    fi
    
    if [ ! -f "$signed_hap" ]; then
        echo "❌ Signed HAP file not generated"
        exit 1
    fi
    
    echo "✅ HAP signed successfully: $signed_hap"
}

# Main function
main() {
    init_hdc
    init_ohpm
    buildHAP
    signedHAP
    
    # Build summary
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    
    echo ""
    echo "=========================================="
    echo "✅ BUILD COMPLETED SUCCESSFULLY"
    echo "=========================================="
    if [ $MINUTES -gt 0 ]; then
        echo "Total duration: ${MINUTES}m ${SECONDS}s"
    else
        echo "Total duration: ${SECONDS}s"
    fi
    echo "=========================================="
}

main
