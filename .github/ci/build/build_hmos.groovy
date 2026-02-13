// -*- mode: groovy -*-
// vim: set filetype=groovy :
@Library('agora-build-pipeline-library') _
import groovy.transform.Field

buildUtils = new agora.build.BuildUtils()

// macOS local deployment, DevEco Studio installed
compileConfig = [
    "sourceDir": "api-examples",
    // Local macOS machine, no Docker required
    // "docker": "hub.agoralab.co/server/ep/linux/ohos:0.0.1-5.0.5.200",
    "non-publish": [
        "command": "./.github/ci/build/build_hmos.sh",
        "extraArgs": "",
    ],
    "publish": [
        "command": "./.github/ci/build/build_hmos.sh",
        "extraArgs": "",
    ]
]

def doBuild(buildVariables) {
    type = params.Package_Publish ? "publish" : "non-publish"
    command = compileConfig.get(type).command
    preCommand = compileConfig.get(type).get("preCommand", "")
    postCommand = compileConfig.get(type).get("postCommand", "")
    extraArgs = compileConfig.get(type).extraArgs
    extraArgs += " " + params.getOrDefault("extra_args", "")
    
    // Download and extract signing files
    if (params.Package_Publish) {
        // extraArgs = handleSignFiles(extraArgs)
    }
    
    // Local build without Docker
    def commandConfig = [
        "command": command,
        "sourceRoot": "${compileConfig.sourceDir}",
        "extraArgs": extraArgs
    ]
    
    echo "[INFO] Build config: ${commandConfig}"
    
    loadResources(["config.json", "artifactory_utils.py"])
    buildUtils.customBuild(commandConfig, preCommand, postCommand)
}

def doPublish(buildVariables) {
    if (!params.Package_Publish) {
        return
    }
    (shortVersion, releaseVersion) = buildUtils.getBranchVersion()
    def archiveInfos = [
        [
          "type": "ARTIFACTORY",
          "archivePattern": "*.zip",
          "serverPath": "ApiExample/${shortVersion}/${buildVariables.buildDate}/${env.platform}",
          "serverRepo": "SDK_repo"
        ],
        [
          "type": "ARTIFACTORY",
          "archivePattern": "*.hap",
          "serverPath": "ApiExample/${shortVersion}/${buildVariables.buildDate}/${env.platform}",
          "serverRepo": "SDK_repo"
        ]
    ]
    archiveUrls = archive.archiveFiles(archiveInfos) ?: []
    archiveUrls = archiveUrls as Set
    if (archiveUrls) {
        def content = archiveUrls.join("\n")
        writeFile(file: 'package_urls', text: content, encoding: "utf-8")
    }
    archiveArtifacts(artifacts: "package_urls", allowEmptyArchive:true)
    sh "rm -rf *.zip *.hap || true"
}

pipelineLoad(this, "ApiExample", "build", "harmonyos", "RTC-Sample")