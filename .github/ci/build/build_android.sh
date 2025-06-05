##################################
# --- Guidelines: ---
#
# Common Environment Variable Injected:
# 'Package_Publish:boolean:true',
# 'Clean_Clone:boolean:false',
# 'is_tag_fetch:boolean:false',
# 'is_offical_build:boolean:false',
# 'repo:string',
# 'base:string',
# 'arch:string'
# 'output:string'
# 'short_version:string'
# 'release_version:string'
# 'build_date:string(yyyyMMdd)',
# 'build_timestamp:string (yyyyMMdd_hhmm)',
# 'platform: string',
# 'BUILD_NUMBER: string',
# 'WORKSPACE: string'
#
# --- Test Related: ---
#   PR build, zip test related to test.zip
#   Package build, zip package related to package.zip
# --- Artifactory Related: ---
# download artifactory:
# python3 ${WORKSPACE}/artifactory_utils.py --action=download_file --file=ARTIFACTORY_URL
# upload file to artifactory:
# python3 ${WORKSPACE}/artifactory_utils.py --action=upload_file --file=FILEPATTERN --server_path=SERVERPATH --server_repo=SERVER_REPO --with_pattern
# for example: python3 ${WORKSPACE}/artifactory_utils.py --action=upload_file --file=*.zip --server_path=windows/ --server_repo=ACCS_repo --with_pattern
# upload folder to artifactory
# python3 ${WORKSPACE}/artifactory_utils.py --action=upload_file --file=FILEPATTERN --server_path=SERVERPATH --server_repo=SERVER_REPO --with_folder
# for example: python3 ${WORKSPACE}/artifactory_utils.py --action=upload_file --file=*.zip --server_path=windows/ --server_repo=ACCS_repo --with_folder
# --- Input: ----
# sourcePath: see jenkins console for details.
# WORKSPACE: ${WORKSPACE}
# --- Output: ----
# pr: output test.zip to workspace dir
# others: Rename the zip package name yourself, But need copy it to workspace dir
##################################
export PATH=$PATH:/opt/homebrew/bin

echo Package_Publish: $Package_Publish
echo is_tag_fetch: $is_tag_fetch
echo arch: $arch
echo source_root: %source_root%
echo output: /tmp/jenkins/${project}_out
echo build_date: $build_date
echo build_time: $build_time
echo release_version: $release_version
echo short_version: $short_version
echo pwd: `pwd`
echo sdk_url: $sdk_url

# Ensure Android directory exists
mkdir -p ./Android

# If sdk_url is empty or 'none', use maven repository and skip all SDK zip/unzip logic
if [ -z "$sdk_url" ] || [ "$sdk_url" = "none" ]; then
    echo "sdk_url is empty, use maven repo"
    # No need to handle unzip_name, zip_name, or any extraction
else
    zip_name=${sdk_url##*/}
    echo zip_name: $zip_name

    # Download SDK zip to Android directory
    curl -o ./Android/$zip_name $sdk_url || exit 1
    # Extract SDK zip in Android directory
    cd ./Android
    7za x ./$zip_name -y > ../log.txt
    # Get the extracted SDK directory name
    unzip_name=`ls -S -d */ | grep Agora | sed 's/\///g'`
    echo unzip_name: $unzip_name
    # Clean up unnecessary files and folders from SDK package
    rm -rf ./$unzip_name/rtc/bin
    rm -rf ./$unzip_name/rtc/demo
    rm -f ./$unzip_name/.commits
    rm -f ./$unzip_name/spec
    rm -rf ./$unzip_name/pom
    cd ..
fi

# Create API-Example directory in the extracted SDK path (if unzip_name is set)
mkdir -p ./Android/$unzip_name/rtc/samples/API-Example || exit 1

# Copy API example source files to the SDK sample directory
if [ -d "./Android/${android_direction}" ]; then
    cp -rf ./Android/${android_direction}/* ./Android/$unzip_name/rtc/samples/API-Example/ || exit 1
else
    echo "Error: Source directory ./Android/${android_direction} does not exist"
    exit 1
fi

# Zip the SDK with API example included
7za a -tzip result.zip -r ./Android/$unzip_name > log.txt
mv result.zip $WORKSPACE/withAPIExample_${BUILD_NUMBER}_$zip_name

# Optionally zip only the API example if compress_apiexample is true
if [ $compress_apiexample = true ]; then
    7za a -tzip result_onlyAPIExample.zip -r ./Android/$unzip_name/rtc/samples/API-Example >> log.txt
    mv result_onlyAPIExample.zip $WORKSPACE/onlyAPIExample_${BUILD_NUMBER}_$zip_name
fi

# Optionally compile the project if compile_project is true
if [ $compile_project = true ]; then
    cd ./Android/$unzip_name/rtc/samples/API-Example || exit 1
    if [ -z "$sdk_url" ] || [ "$sdk_url" = "none" ]; then
        ./cloud_build.sh false || exit 1
    else
        ./cloud_build.sh true || exit 1
    fi
fi

