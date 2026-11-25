# KOReader Reading Goal Patch (`2-reader-goal.lua`)

A lightweight user patch for KOReader that allows you to set and track a reading goal for your current book. Perfect for books with long afterwords, citations etc. chapters at the end.

It provides a quick way to set a target for your reading session (e.g. read until page 250), displays remaining pages and estimated time at the bottom of the screen, and integrates natively with KOReader's menus, gestures, and status bar.

---

## Features

### 1. Dialog with Progress & Quick Actions
Tapping an active goal opens a minimalist dialog with quick action buttons

### 2. Bottom of Page Progress Display (Bottom Bar)
When a goal is active, progress is displayed horizontally centered at the bottom of the screen:

### 3. Consolidated Settings Menu
All options are grouped under a single entry in Settings

### 4. Gesture Manager / Keybindings / Profiles
All actions are registered under the Reader section
You can assign these actions to swipe gestures, multi-finger taps, corner taps, or physical page turn buttons.

### 5. Book-Specific Persistence
Reading goals are saved in each book's sidecar metadata, so each book has its own goal that persists across restarts and firmware updates.

### 7. Developer API for Other Patches & Plugins
The patch exposes its state and methods to other user patches (such as custom header bars or status bar plugins):

```lua
-- Global access:
if _G.GoalPatch then
    local stats = _G.GoalPatch.getStats(self.ui)
    if stats then
        print(stats.goal_page)      -- Target page number (e.g. 150)
        print(stats.current_page)   -- Current page number (e.g. 125)
        print(stats.pages_left)     -- Remaining pages (e.g. 25)
        print(stats.time_left)      -- Remaining time string (e.g. "0:35" or "35 min.")
        print(stats.reached)        -- Boolean: true if current_page >= goal_page
        print(stats.exceeded)       -- Boolean: true if current_page > goal_page
        print(stats.formatted_text) -- Formatted string (e.g. "25 p. / 0:35")
    end

    -- Direct bottom bar string generator:
    local text = _G.GoalPatch.getBottomBarText(self.ui)
end
```