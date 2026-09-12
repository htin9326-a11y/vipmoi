# AUJUNPEAK VN — UI Layout Fixes

This revision keeps the existing app logic, data flow, license/session handling, function execution, patch/project handling, and remote admin behavior unchanged.

## UI fixes applied

- Removed the permanent 52pt leading inset on compact/iPhone layouts that shifted every screen to the right and caused visible clipping.
- Kept the compact side navigation as a floating overlay so the main content uses the full device width.
- Added a consistent 860pt maximum content width for Home / Function / Info so larger screens do not stretch cards excessively.
- Improved Home game cards for narrow screens by reducing icon size, tightening typography, truncating long bundle IDs in the middle, and removing unnecessary trailing spacing.
- Kept cards flexible and width-driven instead of using hard-coded screen widths.
- Kept existing NavigationStack/NavigationSplitView behavior and all feature logic intact.
- Verified every Swift source file with Swift's parser after the UI-only changes.

Build the Xcode project on macOS with the original signing/provisioning settings.
