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

pod install || exit 1

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
/usr/libexec/PlistBuddy -c "Set :objects:4C9306982CB9607F0085EFF9:buildSettings:CODE_SIGN_STYLE 'Manual'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:4C9306982CB9607F0085EFF9:buildSettings:CODE_SIGN_IDENTITY 'iPhone Distribution'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:4C9306982CB9607F0085EFF9:buildSettings:DEVELOPMENT_TEAM 'YS397FG5PA'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:4C9306982CB9607F0085EFF9:buildSettings:PROVISIONING_PROFILE_SPECIFIER 'apiexample_wildcard_adhoc'" $PBXPROJ_PATH
# Release
/usr/libexec/PlistBuddy -c "Set :objects:4C9306992CB9607F0085EFF9:buildSettings:CODE_SIGN_STYLE 'Manual'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:4C9306992CB9607F0085EFF9:buildSettings:CODE_SIGN_IDENTITY 'iPhone Distribution'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:4C9306992CB9607F0085EFF9:buildSettings:DEVELOPMENT_TEAM 'YS397FG5PA'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:4C9306992CB9607F0085EFF9:buildSettings:PROVISIONING_PROFILE_SPECIFIER 'apiexample_wildcard_adhoc'" $PBXPROJ_PATH

# 屏幕共享Extension
# Debug
/usr/libexec/PlistBuddy -c "Set :objects:4C9307F02CB9633A0085EFF9:buildSettings:CODE_SIGN_STYLE 'Manual'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:4C9307F02CB9633A0085EFF9:buildSettings:CODE_SIGN_IDENTITY 'iPhone Distribution'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:4C9307F02CB9633A0085EFF9:buildSettings:DEVELOPMENT_TEAM 'YS397FG5PA'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:4C9307F02CB9633A0085EFF9:buildSettings:PROVISIONING_PROFILE_SPECIFIER 'apiexample_wildcard_adhoc'" $PBXPROJ_PATH
# Release
/usr/libexec/PlistBuddy -c "Set :objects:4C9307F12CB9633A0085EFF9:buildSettings:CODE_SIGN_STYLE 'Manual'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:4C9307F12CB9633A0085EFF9:buildSettings:CODE_SIGN_IDENTITY 'iPhone Distribution'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:4C9307F12CB9633A0085EFF9:buildSettings:DEVELOPMENT_TEAM 'YS397FG5PA'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:4C9307F12CB9633A0085EFF9:buildSettings:PROVISIONING_PROFILE_SPECIFIER 'apiexample_wildcard_adhoc'" $PBXPROJ_PATH

#修改build number
# Debug
/usr/libexec/PlistBuddy -c "Set :objects:4C9306982CB9607F0085EFF9:buildSettings:CURRENT_PROJECT_VERSION ${BUILD_NUMBER}" $PBXPROJ_PATH
# Release
/usr/libexec/PlistBuddy -c "Set :objects:4C9306992CB9607F0085EFF9:buildSettings:CURRENT_PROJECT_VERSION ${BUILD_NUMBER}" $PBXPROJ_PATH

# 读取APPID环境变量
echo AGORA_APP_ID: $APP_ID

echo PROJECT_PATH: $PROJECT_PATH
echo TARGET_NAME: $TARGET_NAME
echo KEYCENTER_PATH: $KEYCENTER_PATH
echo APP_PATH: $APP_PATH

#修改Keycenter文件
sed -i -e "s#<\#APPID\#>#\"$APP_ID\"#g" $KEYCENTER_PATH
rm -f ${KEYCENTER_PATH}-e

# 归档路径
ARCHIVE_PATH="${WORKSPACE}/${TARGET_NAME}_${BUILD_NUMBER}.xcarchive"

# plist路径
PLIST_PATH="${PROJECT_PATH}/ExportOptions.plist"

echo PLIST_PATH: $PLIST_PATH

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


