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


