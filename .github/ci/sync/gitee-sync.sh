#!/usr/bin/env bash

set -euo pipefail

status_file="$(git rev-parse --git-dir)/gitee-sync-status"
record_status() {
    status=$?
    printf '%s\n' "$status" > "$status_file"
}
trap record_status EXIT

git config user.email "sync2gitee@example.com"
git config user.name "sync2gitee"

sed_in_place() {
    if sed --version >/dev/null 2>&1; then
        sed -i "$@"
    else
        sed -i '' "$@"
    fi
}

pwd
git remote -v

echo "Configure Android projects to use China-hosted mirrors"
android_files=(
    Android/APIExample/settings.gradle
    Android/APIExample/gradle/wrapper/gradle-wrapper.properties
    Android/APIExample-Audio/settings.gradle
    Android/APIExample-Audio/gradle/wrapper/gradle-wrapper.properties
)
sed_in_place "s#google()#maven { url \"https\://maven.aliyun.com/repository/public\" }\n        google()#g" Android/APIExample/settings.gradle
sed_in_place "s#https://services.gradle.org/distributions#https://mirrors.cloud.tencent.com/gradle#g" Android/APIExample/gradle/wrapper/gradle-wrapper.properties
sed_in_place "s#google()#maven { url \"https\://maven.aliyun.com/repository/public\" }\n        google()#g" Android/APIExample-Audio/settings.gradle
sed_in_place "s#https://services.gradle.org/distributions#https://mirrors.cloud.tencent.com/gradle#g" Android/APIExample-Audio/gradle/wrapper/gradle-wrapper.properties

echo "Configure Apple projects to use Gitee-hosted dependencies"
podfiles=(
    iOS/APIExample/Podfile
    iOS/APIExample-Audio/Podfile
    iOS/APIExample-SwiftUI/Podfile
    iOS/APIExample-OC/Podfile
    macOS/Podfile
)
python3 .github/ci/sync/rewrite_gitee_podfile.py iOS/APIExample/Podfile
python3 .github/ci/sync/rewrite_gitee_podfile.py iOS/APIExample-Audio/Podfile
python3 .github/ci/sync/rewrite_gitee_podfile.py iOS/APIExample-SwiftUI/Podfile
python3 .github/ci/sync/rewrite_gitee_podfile.py iOS/APIExample-OC/Podfile
python3 .github/ci/sync/rewrite_gitee_podfile.py macOS/Podfile

git add "${android_files[@]}" "${podfiles[@]}"
if ! git diff --cached --quiet; then
    git commit -m 'chore(ci): use China-hosted dependencies for Gitee'
fi

branch="${GITHUB_REF#refs/heads/}"
if [[ -z "$branch" || "$branch" == "$GITHUB_REF" ]]; then
    echo "GITHUB_REF must identify a branch: $GITHUB_REF" >&2
    exit 1
fi

git status
git push gitee "HEAD:refs/heads/$branch"
