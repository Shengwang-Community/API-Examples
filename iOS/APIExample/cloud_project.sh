#!/usr/bin/env sh

PROJECT_PATH=$PWD

if [ "$WORKSPACE" = "" ]; then
	WORKSPACE=$PWD
fi
if [ "$BUILD_NUMBER" = "" ]; then
	BUILD_NUMBER=888
fi

# Version validation logic
echo "Starting branch version validation..."

# Get current branch name
BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ $? -ne 0 ]; then
	echo "Warning: Unable to get Git branch name, skipping version validation"
else
	echo "Current branch: $BRANCH_NAME"
	
	# Extract version from branch name (format: dev/x.x.x)
	if [[ $BRANCH_NAME =~ ^dev/([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
		BRANCH_VERSION="${BASH_REMATCH[1]}"
		echo "Branch version: $BRANCH_VERSION"
		
		# Read MARKETING_VERSION from project.pbxproj
		PBXPROJ_FILE="${PROJECT_PATH}/APIExample.xcodeproj/project.pbxproj"
		if [ ! -f "$PBXPROJ_FILE" ]; then
			echo "Error: project.pbxproj file not found: $PBXPROJ_FILE"
			exit 1
		fi
		
		# Extract MARKETING_VERSION (get first match)
		PLIST_VERSION=$(grep -m 1 "MARKETING_VERSION = " "$PBXPROJ_FILE" | sed 's/.*MARKETING_VERSION = \([^;]*\);/\1/' | tr -d ' ')
		
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
		echo "Warning: Branch name does not match dev/x.x.x format, skipping version validation"
	fi
fi

echo "Version validation completed"
echo "-----------------------------------"

#下载美颜资源
echo "start download bytedance resource : $bytedance_lib"
curl -L -O "$bytedance_lib"
unzip -o vender_bytedance_iOS.zip
rm -f vender_bytedance_iOS.zip

echo "start download sense resource : $sense_lib"
curl -L -O "$sense_lib"
unzip -o vender_sense_iOS.zip
rm -f vender_sense_iOS.zip

echo "start download fu resource : $fu_lib"
curl -L -O "$fu_lib"
unzip -o vender_fu_iOS.zip
rm -f vender_fu_iOS.zip

#打开第三方播放器配置
perl -i -pe "s#\#  pod 'ijkplayer'#  pod 'ijkplayer'#g" Podfile

#打开第三方美颜
perl -i -pe "s#\#pod 'SenseLib'#pod 'SenseLib'#g" Podfile
perl -i -pe "s#\#pod 'bytedEffect'#pod 'bytedEffect'#g" Podfile
perl -i -pe "s#\#pod 'fuLib'#pod 'fuLib'#g" Podfile

pod install --repo-update || exit 1

