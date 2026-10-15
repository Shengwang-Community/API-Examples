---
name: query-cases
description: Find HarmonyOS ArkUI RTC examples by feature or SDK call and verify menu, route, and localized resource registration without editing code.
---

# Query HarmonyOS Cases

Search `entry/src/main/ets/pages/basic/` and `pages/advance/` for the requested API.
Check the live menu in `entry/src/main/ets/pages/Data.ets`, the route in
`entry/src/main/resources/base/profile/main_pages.json`, and the referenced string in
each existing locale. Report the source path, SDK calls, and whether the page is reachable.
Do not treat a source file alone as a registered case. This workflow is read-only.
