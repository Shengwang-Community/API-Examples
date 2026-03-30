#!/bin/bash
set -euo pipefail

git config --global user.email "sync2gitee@example.com"
git config --global user.name "sync2gitee"

pwd
git remote -v

ensure_android_repo() {
  local settings_file="$1"
  local wrapper_file="$2"

  if ! grep -Fq 'maven.aliyun.com/repository/public' "$settings_file"; then
    python3 - "$settings_file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
needle = "        google()"
replacement = '        maven { url "https://maven.aliyun.com/repository/public" }\n        google()'
contents = path.read_text(encoding="utf-8")
path.write_text(contents.replace(needle, replacement), encoding="utf-8")
PY
  fi

  python3 - "$wrapper_file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
contents = path.read_text(encoding="utf-8")
contents = contents.replace(
    "https://services.gradle.org/distributions",
    "https://mirrors.cloud.tencent.com/gradle",
)
path.write_text(contents, encoding="utf-8")
PY
}

commit_if_needed() {
  local commit_message="$1"
  shift

  git add "$@"
  if ! git diff --cached --quiet; then
    git commit -m "$commit_message"
  fi
}

# Change Android Maven and Gradle distribution URLs to domestic mirrors.
ensure_android_repo Android/APIExample/settings.gradle Android/APIExample/gradle/wrapper/gradle-wrapper.properties
ensure_android_repo Android/APIExample-Audio/settings.gradle Android/APIExample-Audio/gradle/wrapper/gradle-wrapper.properties
commit_if_needed '[Android] gitee sync >> use china repos.' \
  Android/APIExample/settings.gradle \
  Android/APIExample/gradle/wrapper/gradle-wrapper.properties \
  Android/APIExample-Audio/settings.gradle \
  Android/APIExample-Audio/gradle/wrapper/gradle-wrapper.properties

# change iOS Podfile to china repos
python3 .github/workflows/modify_podfile.py iOS/APIExample/Podfile
python3 .github/workflows/modify_podfile.py iOS/APIExample-Audio/Podfile
python3 .github/workflows/modify_podfile.py iOS/APIExample-OC/Podfile
python3 .github/workflows/modify_podfile.py macOS/Podfile

# sed -ie '1s#^#source "https://mirrors.tuna.tsinghua.edu.cn/git/CocoaPods/Specs.git"\n#' iOS/APIExample/Podfile
# sed -ie '1s#^#source "https://mirrors.tuna.tsinghua.edu.cn/git/CocoaPods/Specs.git"\n#' iOS/APIExample-Audio/Podfile
# sed -ie '1s#^#source "https://mirrors.tuna.tsinghua.edu.cn/git/CocoaPods/Specs.git"\n#' iOS/APIExample-OC/Podfile
# sed -ie '1s#^#source "https://mirrors.tuna.tsinghua.edu.cn/git/CocoaPods/Specs.git"\n#' macOS/Podfile
commit_if_needed '[iOS] gitee sync >> use china repos.' \
  iOS/APIExample/Podfile \
  iOS/APIExample-Audio/Podfile \
  iOS/APIExample-OC/Podfile \
  macOS/Podfile

git branch
git status
git push gitee
git push gitee --tags
