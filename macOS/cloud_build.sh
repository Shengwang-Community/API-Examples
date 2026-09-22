#!/usr/bin/env bash
set -eu

export LANG=en_US.UTF-8
export PATH=$PATH:/opt/homebrew/bin

PROJECT_PATH=$PWD
WORKSPACE=${WORKSPACE:-$PWD}
SIGNING_TEAM="YS397FG5PA"

: "${BUILD_NUMBER:?BUILD_NUMBER is required}"
: "${APP_ID:?APP_ID is required}"
: "${JFROG_API_KEY:?JFROG_API_KEY is required}"

cd "${PROJECT_PATH}"

# Version validation logic
echo "Starting branch version validation..."

# Get current branch name (try multiple methods for CI environments)
BRANCH_NAME="${BRANCH_NAME:-}"

# Method 1: Try the explicit Jenkins branch parameter first.
# Jenkins checks out a detached HEAD, so inferring from branches containing
# HEAD can pick an unrelated release branch before main.
if [ ! -z "${api_examples_shengwang_branch:-}" ]; then
    BRANCH_NAME="${api_examples_shengwang_branch:-}"
    echo "Branch from api_examples_shengwang_branch: $BRANCH_NAME"
elif [ ! -z "${GIT_BRANCH:-}" ]; then
    BRANCH_NAME="${GIT_BRANCH:-}"
    echo "Branch from GIT_BRANCH: $BRANCH_NAME"
elif [ ! -z "$BRANCH_NAME" ]; then
    echo "Branch from BRANCH_NAME: $BRANCH_NAME"
elif [ ! -z "${CI_COMMIT_REF_NAME:-}" ]; then
    BRANCH_NAME="${CI_COMMIT_REF_NAME:-}"
    echo "Branch from CI_COMMIT_REF_NAME: $BRANCH_NAME"
# Method 2: Try git command
elif [ -z "$BRANCH_NAME" ]; then
    BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    if [ "$BRANCH_NAME" = "HEAD" ]; then
        echo "Detached HEAD without explicit branch; skipping branch inference"
        BRANCH_NAME=""
    else
        echo "Branch from git rev-parse: $BRANCH_NAME"
    fi
fi

# Remove common git ref prefixes if present (but keep the rest of the path)
BRANCH_NAME=$(echo "$BRANCH_NAME" | sed \
	-e 's|^refs/remotes/origin/||' \
	-e 's|^refs/heads/||' \
	-e 's|^remotes/origin/||' \
	-e 's|^origin/||')

if [ -z "$BRANCH_NAME" ] || [ "$BRANCH_NAME" = "HEAD" ] || [ "$BRANCH_NAME" = "main" ]; then
	if [ "$BRANCH_NAME" = "main" ]; then
		echo "Branch is main, skipping version validation (main branch is trusted)"
	else
		echo "Warning: Unable to get Git branch name, skipping version validation"
	fi
else
	echo "Current branch: $BRANCH_NAME"
	
	# Extract version from branch name (for example: dev/x.x.x or release/x.x.x)
	if [[ $BRANCH_NAME =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
		BRANCH_VERSION="${BASH_REMATCH[1]}"
		echo "Branch version: $BRANCH_VERSION"
		
		# Read MARKETING_VERSION from project.pbxproj
		PBXPROJ_FILE="${PROJECT_PATH}/APIExample.xcodeproj/project.pbxproj"
		if [ ! -f "$PBXPROJ_FILE" ]; then
			echo "Error: project.pbxproj file not found: $PBXPROJ_FILE"
			exit 1
		fi
		
		# Extract MARKETING_VERSION for main target (skip Extension targets)
		# Look for the version that appears with @executable_path/Frameworks (main app)
		PLIST_VERSION=$(grep -A 2 "@executable_path/../Frameworks" "$PBXPROJ_FILE" | grep "MARKETING_VERSION" | head -1 | sed 's/.*MARKETING_VERSION = \([^;]*\);/\1/' | tr -d ' ')
		
		if [ -z "$PLIST_VERSION" ]; then
			echo "Error: Unable to read MARKETING_VERSION from project.pbxproj"
			exit 1
		fi
		
		echo "Info.plist version: $PLIST_VERSION"
		
		# Compare versions
		if [ "$BRANCH_VERSION" != "$PLIST_VERSION" ]; then
			echo "Error: Version mismatch!"
			echo "  Branch version: $BRANCH_VERSION"
			echo "  Info.plist version: $PLIST_VERSION"
			echo "Please ensure the version in branch name matches MARKETING_VERSION in Info.plist"
			exit 1
		fi
		
		echo "✓ Version validation passed: $BRANCH_VERSION"
	else
		echo "Error: Branch name does not contain version number!"
		echo "Current branch: $BRANCH_NAME"
		echo "Branch name must contain x.x.x (e.g., dev/4.7.0, release/4.7.0)"
		exit 1
	fi
fi

echo "Version validation completed"
echo "-----------------------------------"

curl --fail --location -H "X-JFrog-Art-Api:${JFROG_API_KEY}" -o AgoraBeautyMaterial.bundle.zip "https://artifactory-api.bj2.agoralab.co/artifactory/qa_test_data/beauty/AgoraBeautyMaterial.bundle.zip"
rm -rf APIExample/Resources/AgoraBeautyMaterial.bundle
unzip -q AgoraBeautyMaterial.bundle.zip -d APIExample/Resources
rm -f AgoraBeautyMaterial.bundle.zip
test -f APIExample/Resources/AgoraBeautyMaterial.bundle/beauty_material_functional/config.json

pod install

# Build environment
CONFIGURATION="Debug"

# Project file path
APP_PATH=$(find . -maxdepth 1 -type d -name '*.xcworkspace' -print -quit)
if [ -z "${APP_PATH}" ]; then
	echo "Error: No Xcode workspace found in ${PROJECT_PATH}"
	exit 1
fi
APP_PATH=${APP_PATH#./}

# Project target name
TARGET_NAME=${APP_PATH%%.*}

KEYCENTER_PATH=$TARGET_NAME/Common/KeyCenter.swift

# Read APPID environment variable
echo "AGORA_APP_ID is configured"

echo PROJECT_PATH: "$PROJECT_PATH"
echo TARGET_NAME: "$TARGET_NAME"
echo KEYCENTER_PATH: "$KEYCENTER_PATH"
echo APP_PATH: "$APP_PATH"

# Modify Keycenter file
sed -i -e "s#<\#YOUR AppId\#>#\"$APP_ID\"#g" "${KEYCENTER_PATH}"
rm -f "${KEYCENTER_PATH}-e"

# Archive path
ARCHIVE_PATH="${WORKSPACE}/${TARGET_NAME}_${BUILD_NUMBER}.xcarchive"

# Build environment

# Plist path
PLIST_PATH="${PROJECT_PATH}/ExportOptions.plist"
EXPORT_PATH="${WORKSPACE}/${TARGET_NAME}_${BUILD_NUMBER}_export"

echo PLIST_PATH: "$PLIST_PATH"

# Archive with Xcode-managed development signing for the configured team.
rm -rf "${ARCHIVE_PATH}" "${EXPORT_PATH}"
xcodebuild \
	-workspace "${APP_PATH}" \
	-scheme "${TARGET_NAME}" \
	-configuration "${CONFIGURATION}" \
	-destination 'generic/platform=macOS' \
	-archivePath "${ARCHIVE_PATH}" \
	-allowProvisioningUpdates \
	CODE_SIGN_STYLE=Automatic \
	CODE_SIGN_IDENTITY="Apple Development" \
	DEVELOPMENT_TEAM="${SIGNING_TEAM}" \
	PROVISIONING_PROFILE_SPECIFIER= \
	CURRENT_PROJECT_VERSION="${BUILD_NUMBER}" \
	clean archive

if [ ! -d "${ARCHIVE_PATH}/Products/Applications/${TARGET_NAME}.app" ]; then
	echo "Error: Archive does not contain ${TARGET_NAME}.app"
	exit 1
fi

mkdir -p "${EXPORT_PATH}"
xcodebuild -exportArchive \
	-archivePath "${ARCHIVE_PATH}" \
	-exportPath "${EXPORT_PATH}" \
	-exportOptionsPlist "${PLIST_PATH}" \
	-allowProvisioningUpdates

EXPORTED_APP="${EXPORT_PATH}/${TARGET_NAME}.app"
if [ ! -d "${EXPORTED_APP}" ]; then
	echo "Error: Xcode export did not produce ${TARGET_NAME}.app"
	exit 1
fi
codesign --verify --deep --strict --verbose=2 "${EXPORTED_APP}"

SDK_VERSION=$(echo "${sdk_url:-unknown}" | cut -d "/" -f 5)
OUTPUT_FILE=${WORKSPACE}/${TARGET_NAME}_${BUILD_NUMBER}_${SDK_VERSION}_$(date "+%Y%m%d%H%M%S").app.zip
rm -f "${OUTPUT_FILE}"
ditto -c -k --sequesterRsrc --keepParent "${EXPORTED_APP}" "${OUTPUT_FILE}"
if [ ! -s "${OUTPUT_FILE}" ]; then
	echo "Error: App package was not created"
	exit 1
fi

rm -rf "${ARCHIVE_PATH}" "${EXPORT_PATH}"
echo OUTPUT_FILE: "$OUTPUT_FILE"
