#!/usr/bin/env sh
export LANG=en_US.UTF-8
export PATH=$PATH:/opt/homebrew/bin

PROJECT_PATH=$PWD

if [ "$WORKSPACE" = "" ]; then
	WORKSPACE=$PWD
fi
if [ "$BUILD_NUMBER" = "" ]; then
	BUILD_NUMBER=888
fi

# Version validation logic
echo "Starting branch version validation..."

# Get current branch name (try multiple methods for CI environments)
BRANCH_NAME=""

# Method 1: Try the explicit Jenkins branch parameter first.
# Jenkins checks out a detached HEAD, so inferring from branches containing
# HEAD can pick an unrelated release branch before main.
if [ ! -z "$api_examples_shengwang_branch" ]; then
    BRANCH_NAME="$api_examples_shengwang_branch"
    echo "Branch from api_examples_shengwang_branch: $BRANCH_NAME"
elif [ ! -z "$GIT_BRANCH" ]; then
    BRANCH_NAME="$GIT_BRANCH"
    echo "Branch from GIT_BRANCH: $BRANCH_NAME"
elif [ ! -z "$BRANCH_NAME" ]; then
    echo "Branch from BRANCH_NAME: $BRANCH_NAME"
elif [ ! -z "$CI_COMMIT_REF_NAME" ]; then
    BRANCH_NAME="$CI_COMMIT_REF_NAME"
    echo "Branch from CI_COMMIT_REF_NAME: $BRANCH_NAME"
# Method 2: Try git command
elif [ -z "$BRANCH_NAME" ]; then
    BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
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
		echo "Branch name must contain x.x.x (e.g., dev/4.6.2, release/4.6.2)"
		exit 1
	fi
fi

echo "Version validation completed"
echo "-----------------------------------"


cd ${PROJECT_PATH} && pod install || exit 1

# 打包环境
CONFIGURATION="Debug"

#工程文件路径
APP_PATH="$(ls | grep xcworkspace)"

# 项目target名
TARGET_NAME=${APP_PATH%%.*} 

KEYCENTER_PATH=$TARGET_NAME/Common/KeyCenter.swift

#工程配置路径
PBXPROJ_PATH=${TARGET_NAME}.xcodeproj/project.pbxproj

# 主项目工程配置
# Debug
/usr/libexec/PlistBuddy -c "Set :objects:03896D5324F8A011008593CD:buildSettings:CODE_SIGN_STYLE 'Manual'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:03896D5324F8A011008593CD:buildSettings:CODE_SIGN_IDENTITY 'Developer ID Application'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:03896D5324F8A011008593CD:buildSettings:DEVELOPMENT_TEAM 'GM72UGLGZW'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:03896D5324F8A011008593CD:buildSettings:PROVISIONING_PROFILE_SPECIFIER 'App'" $PBXPROJ_PATH
# Release
/usr/libexec/PlistBuddy -c "Set :objects:03896D5424F8A011008593CD:buildSettings:CODE_SIGN_STYLE 'Manual'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:03896D5424F8A011008593CD:buildSettings:CODE_SIGN_IDENTITY 'Developer ID Application'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:03896D5424F8A011008593CD:buildSettings:DEVELOPMENT_TEAM 'GM72UGLGZW'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:03896D5424F8A011008593CD:buildSettings:PROVISIONING_PROFILE_SPECIFIER 'App'" $PBXPROJ_PATH

# SimpleFilter
# Debug
/usr/libexec/PlistBuddy -c "Set :objects:8BD4AE7E272518D600E95B87:buildSettings:CODE_SIGN_STYLE 'Manual'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:8BD4AE7E272518D600E95B87:buildSettings:DEVELOPMENT_TEAM ''" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:8BD4AE7E272518D600E95B87:buildSettings:PROVISIONING_PROFILE_SPECIFIER ''" $PBXPROJ_PATH
# Release
/usr/libexec/PlistBuddy -c "Set :objects:8BD4AE7F272518D600E95B87:buildSettings:CODE_SIGN_STYLE 'Manual'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:8BD4AE7F272518D600E95B87:buildSettings:DEVELOPMENT_TEAM ''" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:8BD4AE7F272518D600E95B87:buildSettings:PROVISIONING_PROFILE_SPECIFIER ''" $PBXPROJ_PATH

#修改build number
# Debug
/usr/libexec/PlistBuddy -c "Set :objects:03896D5324F8A011008593CD:buildSettings:CURRENT_PROJECT_VERSION ${BUILD_NUMBER}" $PBXPROJ_PATH
# Release
/usr/libexec/PlistBuddy -c "Set :objects:03896D5424F8A011008593CD:buildSettings:CURRENT_PROJECT_VERSION ${BUILD_NUMBER}" $PBXPROJ_PATH


# 读取APPID环境变量
echo AGORA_APP_ID: $APP_ID

echo PROJECT_PATH: $PROJECT_PATH
echo TARGET_NAME: $TARGET_NAME
echo KEYCENTER_PATH: $KEYCENTER_PATH
echo APP_PATH: $APP_PATH

#修改Keycenter文件
sed -i -e "s#<\#YOUR AppId\#>#\"$APP_ID\"#g" $KEYCENTER_PATH
rm -f ${KEYCENTER_PATH}-e

# Xcode clean
xcodebuild clean -workspace "${APP_PATH}" -configuration "${CONFIGURATION}" -scheme "${TARGET_NAME}"

# 时间戳
CURRENT_TIME=$(date "+%Y-%m-%d %H-%M-%S")

# 归档路径
ARCHIVE_PATH="${WORKSPACE}/${TARGET_NAME}_${BUILD_NUMBER}.xcarchive"

# 编译环境

# plist路径
PLIST_PATH="${PROJECT_PATH}/ExportOptions.plist"

echo PLIST_PATH: $PLIST_PATH

# archive 这边使用的工作区间 也可以使用project
xcodebuild archive -workspace "${APP_PATH}" -scheme "${TARGET_NAME}" -configuration "${CONFIGURATION}" -archivePath "${ARCHIVE_PATH}"

cd ${WORKSPACE}

# 压缩archive
7za a -tzip "${TARGET_NAME}_${BUILD_NUMBER}.xcarchive.zip" "${ARCHIVE_PATH}"

echo "start sign..."

# 签名
sh sign "${WORKSPACE}/${TARGET_NAME}_${BUILD_NUMBER}.xcarchive.zip" --type xcarchive --plist "${PLIST_PATH}" --application macApp


SDK_VERSION=$(echo $sdk_url | cut -d "/" -f 5)
OUTPUT_FILE=${WORKSPACE}/${TARGET_NAME}_${BUILD_NUMBER}_${SDK_VERSION}_$(date "+%Y%m%d%H%M%S").app.zip
mv ${TARGET_NAME}_${BUILD_NUMBER}.app.zip $OUTPUT_FILE

rm -rf *.xcarchive
rm -rf *.xcarchive.zip
echo OUTPUT_FILE: $OUTPUT_FILE

echo ""
echo "=========================================="
echo "=== Certificate Expiration Information ==="
echo "=========================================="

# 获取用于签名的证书信息 (macOS)
SIGNING_CERT=$(security find-identity -v -p codesigning | grep "Developer ID Application\|Mac Developer\|Apple Development" | head -1 | awk -F'"' '{print $2}')

if [ ! -z "$SIGNING_CERT" ]; then
    echo "Signing Certificate: $SIGNING_CERT"
    
    # 获取证书的详细信息
    CERT_INFO=$(security find-certificate -c "$SIGNING_CERT" -p | openssl x509 -noout -dates 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "$CERT_INFO"
        
        # 提取过期日期
        EXPIRY_DATE=$(echo "$CERT_INFO" | grep "notAfter" | cut -d= -f2)
        echo ""
        echo "⚠️  Certificate will expire on: $EXPIRY_DATE"
        
        # 计算剩余天数
        if command -v gdate >/dev/null 2>&1; then
            # macOS with GNU coreutils installed
            EXPIRY_EPOCH=$(gdate -d "$EXPIRY_DATE" +%s 2>/dev/null)
            CURRENT_EPOCH=$(gdate +%s)
        else
            # macOS default date command
            EXPIRY_EPOCH=$(date -j -f "%b %d %T %Y %Z" "$EXPIRY_DATE" +%s 2>/dev/null)
            CURRENT_EPOCH=$(date +%s)
        fi
        
        if [ ! -z "$EXPIRY_EPOCH" ] && [ ! -z "$CURRENT_EPOCH" ]; then
            DAYS_LEFT=$(( ($EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))
            echo "📅 Days remaining: $DAYS_LEFT days"
            
            if [ $DAYS_LEFT -lt 30 ]; then
                echo "🚨 WARNING: Certificate will expire in less than 30 days!"
            elif [ $DAYS_LEFT -lt 90 ]; then
                echo "⚠️  NOTICE: Certificate will expire in less than 90 days"
            fi
        fi
    else
        echo "Unable to retrieve certificate expiration information"
    fi
else
    echo "No distribution certificate found"
fi

echo "=========================================="
echo ""
