---
name: review-case
description: Review a HarmonyOS RTC ArkUI example for SDK correctness, lifecycle, asynchronous callbacks, permissions, registration, resources, and secret handling.
---

# Review HarmonyOS Case

Inspect the selected page and the current SDK declarations. Verify initialization,
argument values, permissions, error paths, leave-channel and engine destruction, including
late callbacks after page exit. Check `Data.ets`, `main_pages.json`, and all locale strings
for registered cases. Look for real App IDs, certificates, or tokens in source and assets.
Report actionable findings with file and line references before any summary. Separate
static checks and unsigned compilation from signed packaging or device validation.
