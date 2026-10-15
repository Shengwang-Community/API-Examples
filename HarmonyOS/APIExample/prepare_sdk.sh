#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
. "${project_dir}/sdk-release.env"
har_file="${project_dir}/entry/libs/AgoraRtcSdk.har"

verify_har() {
    tar -xOzf "$1" package/oh-package.json5 | python3 -c '
import json
import sys

metadata = json.load(sys.stdin)
name = metadata.get("name")
version = metadata.get("version")
if name != "@shengwang/rtc-full" or version != sys.argv[1]:
    sys.exit(f"Expected @shengwang/rtc-full {sys.argv[1]}, got {name} {version}")
' "${HARMONY_SDK_VERSION}"
}

if [[ -f "${har_file}" && "${HARMONY_SDK_FORCE:-0}" != "1" ]]; then
    if verify_har "${har_file}"; then
        echo "[INFO] Shengwang RTC ${HARMONY_SDK_VERSION} is already installed"
        exit 0
    fi
    echo "[ERROR] Existing HAR was not changed. Move it aside or set HARMONY_SDK_FORCE=1." >&2
    exit 1
fi

stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/harmony-sdk.XXXXXX")"
trap 'rm -rf -- "${stage_dir}"' EXIT
archive="${stage_dir}/sdk.zip"
curl -fL --retry 3 --output "${archive}" "${HARMONY_SDK_URL}"
printf '%s  %s\n' "${HARMONY_SDK_SHA256}" "${archive}" | shasum -a 256 -c -
unzip -q "${archive}" -d "${stage_dir}/sdk"

sdk_hars=()
while IFS= read -r sdk_har; do
    sdk_hars+=("${sdk_har}")
done < <(find "${stage_dir}/sdk" -type f -path '*/rtc/sdk/AgoraRtcSdk.har')
if [[ "${#sdk_hars[@]}" -ne 1 ]]; then
    echo "[ERROR] Expected one rtc/sdk/AgoraRtcSdk.har, found ${#sdk_hars[@]}" >&2
    exit 1
fi
verify_har "${sdk_hars[0]}"
mkdir -p "$(dirname "${har_file}")"
cp -f "${sdk_hars[0]}" "${har_file}"
echo "[INFO] Installed Shengwang RTC ${HARMONY_SDK_VERSION} at ${har_file}"
