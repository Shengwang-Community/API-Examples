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

# Method 1: Try environment variable (Jenkins/GitLab CI)
if [ ! -z "$GIT_BRANCH" ]; then
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
        # In detached HEAD state, try to get branch from remote
        BRANCH_NAME=$(git branch -r --contains HEAD | grep -v HEAD | head -1 | sed 's/^[[:space:]]*origin\///')
        echo "Branch from git branch -r: $BRANCH_NAME"
    else
        echo "Branch from git rev-parse: $BRANCH_NAME"
    fi
fi

# Remove origin/ prefix if present (but keep the rest of the path)
BRANCH_NAME=$(echo "$BRANCH_NAME" | sed 's/^origin\///')

if [ -z "$BRANCH_NAME" ] || [ "$BRANCH_NAME" = "HEAD" ]; then
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
		
		# Extract MARKETING_VERSION for main target (skip Extension targets)
		# Look for the version that appears with @executable_path/Frameworks (main app)
		PLIST_VERSION=$(grep -A 2 "@executable_path/Frameworks" "$PBXPROJ_FILE" | grep "MARKETING_VERSION" | head -1 | sed 's/.*MARKETING_VERSION = \([^;]*\);/\1/' | tr -d ' ')
		
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
		echo "Error: Branch name does not match dev/x.x.x format!"
		echo "Current branch: $BRANCH_NAME"
		echo "Required format: dev/x.x.x (e.g., dev/4.6.2)"
		exit 1
	fi
fi

echo "Version validation completed"
echo "-----------------------------------"


cd ${PROJECT_PATH}

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
sed -i -e "s#\#  pod 'ijkplayer'#  pod 'ijkplayer'#g" Podfile

#打开第三方美颜
sed -i -e "s#\#  pod 'SenseLib'#  pod 'SenseLib'#g" Podfile
sed -i -e "s#\#  pod 'bytedEffect'#  pod 'bytedEffect'#g" Podfile
sed -i -e "s#\#  pod 'fuLib'#  pod 'fuLib'#g" Podfile

echo "work space: $WORKSPACE"
echo "project path: $PROJECT_PATH"


pod install --repo-update || exit 1

# 打包环境
CONFIGURATION="Debug"

#工程文件路径
APP_PATH="$(ls | grep xcworkspace)"

# 项目target名
TARGET_NAME=${APP_PATH%%.*} 

KEYCENTER_PATH=$TARGET_NAME/Common/KeyCenter.swift

#工程配置路径
PBXPROJ_PATH=${TARGET_NAME}.xcodeproj/project.pbxproj

# Debug
/usr/libexec/PlistBuddy -c "Set :objects:03D13BF72448758C00B599B3:buildSettings:CODE_SIGN_STYLE 'Manual'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:03D13BF72448758C00B599B3:buildSettings:CODE_SIGN_IDENTITY 'iPhone Distribution'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:03D13BF72448758C00B599B3:buildSettings:DEVELOPMENT_TEAM 'YS397FG5PA'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:03D13BF72448758C00B599B3:buildSettings:PROVISIONING_PROFILE_SPECIFIER 'apiexample_wildcard_adhoc'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:03D13BF72448758C00B599B3:buildSettings:PRODUCT_BUNDLE_IDENTIFIER io.agora.entfull" $PBXPROJ_PATH

# Release
/usr/libexec/PlistBuddy -c "Set :objects:03D13BF82448758C00B599B3:buildSettings:CODE_SIGN_STYLE 'Manual'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:03D13BF82448758C00B599B3:buildSettings:CODE_SIGN_IDENTITY 'iPhone Distribution'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:03D13BF82448758C00B599B3:buildSettings:DEVELOPMENT_TEAM 'YS397FG5PA'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:03D13BF82448758C00B599B3:buildSettings:PROVISIONING_PROFILE_SPECIFIER 'apiexample_wildcard_adhoc'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:03D13BF82448758C00B599B3:buildSettings:PRODUCT_BUNDLE_IDENTIFIER io.agora.entfull" $PBXPROJ_PATH

# 屏幕共享Extension
# Debug
/usr/libexec/PlistBuddy -c "Set :objects:0339BEB825205B80007D4FDD:buildSettings:CODE_SIGN_STYLE 'Manual'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:0339BEB825205B80007D4FDD:buildSettings:CODE_SIGN_IDENTITY 'iPhone Distribution'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:0339BEB825205B80007D4FDD:buildSettings:DEVELOPMENT_TEAM 'YS397FG5PA'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:0339BEB825205B80007D4FDD:buildSettings:PROVISIONING_PROFILE_SPECIFIER 'apiexample_wildcard_adhoc'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:0339BEB825205B80007D4FDD:buildSettings:PRODUCT_BUNDLE_IDENTIFIER io.agora.entfull.Agora-ScreenShare-Extension" $PBXPROJ_PATH

# Release
/usr/libexec/PlistBuddy -c "Set :objects:0339BEB925205B80007D4FDD:buildSettings:CODE_SIGN_STYLE 'Manual'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:0339BEB925205B80007D4FDD:buildSettings:CODE_SIGN_IDENTITY 'iPhone Distribution'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:0339BEB925205B80007D4FDD:buildSettings:DEVELOPMENT_TEAM 'YS397FG5PA'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:0339BEB925205B80007D4FDD:buildSettings:PROVISIONING_PROFILE_SPECIFIER 'apiexample_wildcard_adhoc'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:0339BEB925205B80007D4FDD:buildSettings:PRODUCT_BUNDLE_IDENTIFIER io.agora.entfull.Agora-ScreenShare-Extension" $PBXPROJ_PATH

# SimpleFilter
# Debug
/usr/libexec/PlistBuddy -c "Set :objects:8B10BE1726AFFFA6002E1373:buildSettings:CODE_SIGN_STYLE 'Manual'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:8B10BE1726AFFFA6002E1373:buildSettings:DEVELOPMENT_TEAM ''" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:8B10BE1726AFFFA6002E1373:buildSettings:PROVISIONING_PROFILE_SPECIFIER ''" $PBXPROJ_PATH
# Release
/usr/libexec/PlistBuddy -c "Set :objects:8B10BE1826AFFFA6002E1373:buildSettings:CODE_SIGN_STYLE 'Manual'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:8B10BE1826AFFFA6002E1373:buildSettings:DEVELOPMENT_TEAM ''" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:8B10BE1826AFFFA6002E1373:buildSettings:PROVISIONING_PROFILE_SPECIFIER ''" $PBXPROJ_PATH

#修改build number
# Debug
/usr/libexec/PlistBuddy -c "Set :objects:03D13BF72448758C00B599B3:buildSettings:CURRENT_PROJECT_VERSION ${BUILD_NUMBER}" $PBXPROJ_PATH

# Release
/usr/libexec/PlistBuddy -c "Set :objects:03D13BF82448758C00B599B3:buildSettings:CURRENT_PROJECT_VERSION ${BUILD_NUMBER}" $PBXPROJ_PATH

MODIFIED_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :objects:03D13BF72448758C00B599B3:buildSettings:PRODUCT_BUNDLE_IDENTIFIER" "$PBXPROJ_PATH")
echo "Modified Bundle Identifier: $MODIFIED_BUNDLE_ID"

# 读取APPID环境变量
echo AGORA_APP_ID: $APP_ID

echo PROJECT_PATH: $PROJECT_PATH
echo TARGET_NAME: $TARGET_NAME
echo KEYCENTER_PATH: $KEYCENTER_PATH
echo APP_PATH: $APP_PATH

#修改Keycenter文件
sed -i -e "s#<\#YOUR AppId\#>#\"$APP_ID\"#g" $KEYCENTER_PATH
rm -f ${KEYCENTER_PATH}-e

# 归档路径
ARCHIVE_PATH="${WORKSPACE}/${TARGET_NAME}_${BUILD_NUMBER}.xcarchive"

# plist路径
PLIST_PATH="${PROJECT_PATH}/ExportOptions.plist"

# 修改ExportOptions.plist
# 修改 io.agora.api.examples 的值
echo "start modify ExportOption.plist"
# 先获取原始值
value1=$(/usr/libexec/PlistBuddy -c "Print :provisioningProfiles:io.agora.api.examples" "$PLIST_PATH")
value2=$(/usr/libexec/PlistBuddy -c "Print :provisioningProfiles:io.agora.api.examples.Agora-ScreenShare-Extension" "$PLIST_PATH")

# 删除原始键
/usr/libexec/PlistBuddy -c "Delete :provisioningProfiles:io.agora.api.examples" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Delete :provisioningProfiles:io.agora.api.examples.Agora-ScreenShare-Extension" "$PLIST_PATH"

# 添加新键和值
/usr/libexec/PlistBuddy -c "Add :provisioningProfiles:io.agora.entfull string $value1" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Add :provisioningProfiles:io.agora.entfull.Agora-ScreenShare-Extension string $value2" "$PLIST_PATH"

# 打印修改后的 provisioningProfiles 值
echo "修改后的 provisioningProfiles 值："
/usr/libexec/PlistBuddy -c "Print :provisioningProfiles" "$PLIST_PATH"

echo "start xcode build, appPath: $APP_PATH, target: $TARGET_NAME, config: $CONFIGURATION, archivePath: $ARCHIVE_PATH"

# archive 这边使用的工作区间 也可以使用project
# 在 archive 阶段禁用签名，避免 Pods Framework 签名问题
# 代码签名将在导出（export）阶段根据 ExportOptions.plist 进行
xcodebuild CODE_SIGN_STYLE="Manual" \
  -workspace "${APP_PATH}" \
  -scheme "${TARGET_NAME}" \
  clean \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -configuration "${CONFIGURATION}" \
  archive \
  -archivePath "${ARCHIVE_PATH}" \
  -destination 'generic/platform=iOS' \
  -quiet || exit 1

echo "xcode build finished"

cd ${WORKSPACE}

# 打印当前设备安装的证书（用于调试）
echo "=========================================="
echo "当前设备安装的代码签名证书列表："
echo "=========================================="
security find-identity -v -p codesigning | grep -E "(iPhone Distribution|Apple Distribution|iOS Distribution)" || security find-identity -v -p codesigning
echo "=========================================="
echo ""

# 打印 ExportOptions.plist 内容（用于调试）
echo "=========================================="
echo "ExportOptions.plist 配置内容："
echo "=========================================="
cat "${PLIST_PATH}"
echo "=========================================="
echo ""

# 导出 IPA（直接使用 xcodebuild，与 Xcode 手动导出一致）
EXPORT_PATH="${WORKSPACE}/export"
rm -rf "${EXPORT_PATH}"
mkdir -p "${EXPORT_PATH}"

security unlock-keychain -p "123456" ~/Library/Keychains/login.keychain

echo "开始导出 IPA..."
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist "${PLIST_PATH}" \
  -allowProvisioningUpdates || exit 1

# 重命名并移动 IPA 文件
SDK_VERSION=$(echo $sdk_url | cut -d "/" -f 5)
OUTPUT_FILE=${WORKSPACE}/${TARGET_NAME}_${BUILD_NUMBER}_${SDK_VERSION}_$(date "+%Y%m%d%H%M%S").ipa
mv ${EXPORT_PATH}/${TARGET_NAME}.ipa $OUTPUT_FILE

# 清理临时文件
rm -rf "${EXPORT_PATH}"
rm -rf "${ARCHIVE_PATH}"
echo OUTPUT_FILE: $OUTPUT_FILE

echo ""
echo "=========================================="
echo "=== Certificate Expiration Information ==="
echo "=========================================="

# 获取用于签名的证书信息
SIGNING_CERT=$(security find-identity -v -p codesigning | grep "iPhone Distribution\|Apple Distribution\|iOS Distribution" | head -1 | awk -F'"' '{print $2}')

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


