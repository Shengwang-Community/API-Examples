"""Rewrite Apple dependencies for the Shengwang Gitee mirror."""

import pathlib
import re
import sys


SDK_PODS = {
    "ShengwangRtcEngine_iOS",
    "ShengwangAudio_iOS",
    "ShengwangRtcEngine_macOS",
}

GITEE_PODS = {
    "Floaty": "pod 'Floaty', :git => 'https://gitee.com/shengwang-dependencies/Floaty.git'",
    "AGEVideoLayout": "pod 'AGEVideoLayout', :git => 'https://gitee.com/shengwang-dependencies/AGEVideoLayout.git'",
    "CocoaAsyncSocket": "pod 'CocoaAsyncSocket', :git => 'https://gitee.com/shengwang-dependencies/CocoaAsyncSocket.git'",
    "SwiftLint": "pod 'SwiftLint', :git => 'https://gitee.com/shengwang-dependencies/SwiftLint', :commit => '1067113303c134ef472a71b30d21e5350de7889d'",
    "ijkplayer": "pod 'ijkplayer', :path => 'ijkplayer.podspec'",
}

POD_PATTERN = re.compile(r"^(?P<indent>\s*)pod\s+'(?P<name>[^']+)'")
COMMENTED_LOCAL_SDK_PATTERN = re.compile(r"^\s*#\s*pod\s+'sdk'")
DOWNLOAD_PATTERN = re.compile(r"^(?P<indent>\s*)#\s*(?P<call>system\(.*sh \.download_script.*\))")


def modify(path: pathlib.Path) -> None:
    contents = []
    for line in path.read_text(encoding="utf-8").splitlines(keepends=True):
        pod_match = POD_PATTERN.match(line)
        if pod_match:
            indent = pod_match.group("indent")
            pod_name = pod_match.group("name")
            if pod_name in SDK_PODS:
                line = f"{indent}pod 'sdk', :path => 'sdk.podspec'\n"
            elif pod_name in GITEE_PODS:
                line = f"{indent}{GITEE_PODS[pod_name]}\n"
        elif COMMENTED_LOCAL_SDK_PATTERN.match(line):
            line = ""
        else:
            download_match = DOWNLOAD_PATTERN.match(line)
            if download_match:
                call = download_match.group("call").replace("false", "true")
                line = f"{download_match.group('indent')}{call}\n"
        contents.append(line)

    path.write_text("".join(contents), encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(f"Usage: {sys.argv[0]} PODFILE")
    modify(pathlib.Path(sys.argv[1]))
