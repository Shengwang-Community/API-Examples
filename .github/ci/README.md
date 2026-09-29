# CI Implementation

GitHub Actions entry points live in `.github/workflows/`. This directory contains their
policy helpers and the release packaging scripts loaded by Jenkins.

| Path | Caller and responsibility | Validation |
| --- | --- | --- |
| `Jenkinsfile_bitbucket.groovy` | External Jenkins shared library loads the release pipeline. | Verify job configuration and release evidence in the release ticket. |
| `build/` | Jenkins platform Groovy entry points call packaging scripts, which use each project's `cloud_build.*` adapters. IPA entry points also depend on external Jenkins configuration. | Run the packaging helper tests below; actual signing, private SDK injection and artifact verification belong to Jenkins. |
| `policy/` | `repository-policy.yml` runs AI asset validation and native template lifecycle regressions; `.git-hooks/` supplies the local credential and commit-message checks. | Follow [AI validation](../../docs/ai/README.md) for venv setup and policy checks. |
| `sync/` | `gitee-sync.yml` invokes the shell customization through hub-mirror-action; the shell calls the Podfile transformer. | Check shell syntax and Podfile transformation on temporary copies. Run actual synchronization only through an authorized mirror job. |

After creating the venv described above, run the packaging helper tests from the repository root:

```bash
.venv/bin/python -m unittest discover --start-directory .github/ci/build/tests --pattern 'test_*.py'
```

Keep the Jenkins entry point and `build/` paths stable: external jobs and existing scripts
refer to them directly. A lack of repository-local callers does not establish that an
external entry point is unused. GitHub compilation runs for pull requests targeting `main`,
uses public SDK dependencies, and produces compile evidence; Jenkins owns release artifacts
and signing evidence.

## macOS test packages

`build/build_mac.groovy` calls `build/build_mac.sh`. With `compile_project=true`, it runs
`macOS/cloud_build.sh` from the prepared SDK samples tree. The adapter preserves branch
version validation, archives with Xcode automatic `Apple Development` signing for Team
`YS397FG5PA`, and exports using `macOS/ExportOptions.plist` (`debugging`, automatic signing,
the same Team). The Jenkins macOS worker must have the corresponding signing identity and
Xcode provisioning access. This path uses Xcode export directly, without the external `sign`
helper or its Python dependencies.

The adapter requires `BUILD_NUMBER`, `APP_ID`, and `JFROG_API_KEY`; `WORKSPACE` defaults to the
current directory. It verifies the archived/exported app, checks its signature with
`codesign --verify --deep --strict`, and creates a nonempty `.app.zip` in `WORKSPACE` before
printing `OUTPUT_FILE`. Any failed build, export, verification, or packaging command exits
nonzero so Jenkins cannot report successful app packaging. These are development test
packages; this flow does not perform Developer ID distribution or notarization.

`build/tests/test_mac_packaging.py` exercises the adapter in a temporary workspace with
controlled command substitutes, including archive/export/signature failures and missing
artifacts. It checks control flow and packaging output, not real signing credentials or SDK
compilation. Confirm `ARCHIVE SUCCEEDED`, `EXPORT SUCCEEDED`, signature verification, and the
uploaded `.app.zip` in the next Jenkins run. The separate legacy `build_mac_ipa.sh` entry
point still depends on external job configuration and is not this Groovy pipeline's adapter.

## HarmonyOS

`HarmonyOS/APIExample/sdk-release.env` pins the public SDK ZIP and SHA-256 digest.
`prepare_sdk.sh` installs its verified HAR for developers. The HarmonyOS job in
`compile.yml` uses a GitHub-hosted Ubuntu runner for shell syntax and offline SDK
preparation/packaging tests. It does not download the full SDK, install DevEco Studio,
compile ArkTS/C++, or verify that the public CDN is currently reachable.

`HARMONY_UNSIGNED_ONLY=true` makes `cloud_build.sh` compile and verify an unsigned HAP
when a developer runs it locally with DevEco Studio and the HarmonyOS 5.0 SDK installed.
`build/tests/test_hmos_sdk.py` checks local HAR reuse, version mismatch protection and
the verified public-ZIP extraction flow with controlled fixtures (no network required).
Jenkins instead uses `build/build_hmos.groovy` and `build/build_hmos.sh` to package the
selected `sdk_url` and sign a HAP with credentials held outside Git. Source packaging
sets App ID to `<#YOUR AppId#>` and clears App Certificate in its copy of
`KeyCenter.ets`; the public token server URL in `TokenUtils.ets` stays in the
source package.
`cloud_build.sh` injects Jenkins `APP_ID` before compilation and restores the
workspace copy afterward. Set `HMOS_KEY_ALIAS`
when the signing key alias differs from `HMOS_KEY_PWD`. The Jenkins worker
must have DevEco and signing files configured; its external HarmonyOS job mapping and
agent label must be verified separately. Validate HarmonyOS compilation with DevEco
before release and review the source ZIP and signed HAP in a real Jenkins release job;
the GitHub PR check does not validate compilation, signing, or publishing.

## Template checks

`policy/check_templates.py` extracts the canonical creation templates rather than maintaining
copies of their implementation. Its controlled SDK, UI and Token dependencies live in
`policy/tests/template_fixtures/`. These regressions exercise pending permission/Token exit,
repeated cleanup/setup, reopen, reordered responses and failure paths; they do not run RTC
sessions or prove SDK binary compatibility. The Apple check also compiles the OC template
against a Swift-generated header using the actual project's NetworkManager declaration.

From the repository root:

```bash
# macOS with Xcode command-line tools (Swift, Clang, Foundation)
python3 .github/ci/policy/check_templates.py apple
# JDK 17 and Kotlin CLI on PATH; KOTLINC can select a local compiler wrapper
python3 .github/ci/policy/check_templates.py kotlin
# Real Android/RTC interfaces, using the SDK selected for this checkout
python3 .github/ci/policy/check_templates.py android-sdk \
  --sdk-jar /path/to/agora-rtc-sdk.jar --android-jar /path/to/android.jar
```

Repository Policy runs Apple/Kotlin lifecycle checks on macOS/Ubuntu hosted runners; Ubuntu
supplies the Kotlin CLI. Missing compilers, missing template sections or missing inputs fail
the check rather than silently skipping it. No SDK download or credentials are needed for
these controlled regressions.

`compile.yml` builds the checked-in application targets without staging generated template
sources, keeping the pull request gate focused on application compilation and public dependency
resolution. To check a complete template against a real project interface, run
`policy/stage_compile_templates.py` only in a disposable CI/scratch checkout before that
project's normal build. The helper mutates source and Xcode project files; never run it in a
developer working tree with pending changes. Template/fixture checks do not replace permission
UI integration, case registration or device validation.
