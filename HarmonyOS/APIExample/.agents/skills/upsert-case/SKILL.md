---
name: upsert-case
description: Add or update a HarmonyOS RTC API example, including ArkUI lifecycle, menu and page registration, permissions, resources, and verification.
---

# Upsert HarmonyOS Case

Read the project's `AGENTS.md` and `ARCHITECTURE.md`, then locate a nearby ArkUI example
for the same media path. Keep one page per feature under `entry/src/main/ets/pages/basic/`
or `pages/advance/`. Use the pinned `@shengwang/rtc-full` SDK declarations rather than
guessing API shapes. Manage the page-owned engine, leave the channel and destroy it on
exit; guard delayed callbacks. Update the `Data.ets` menu, `main_pages.json` route and
all locale strings. For media or native inputs, update the module resources and CMake/NAPI
wiring. Compile an unsigned HAP, then record any device-only checks separately.
