# KOReader Reading Goal Patch (`2-reader-goal.lua`)

A lightweight user patch for KOReader that allows you to set and track a reading goal for your current book. Perfect for books with long afterwords, citations etc. chapters at the end.

It provides a quick way to set a target for your reading session (e.g. read until page 250), displays remaining pages and estimated time at the bottom of the screen, and integrates natively with KOReader's menus, gestures, and status bar.

---

## 🎯 Features

### 1. Tools Menu: `Goal`
In the **Tools** menu (wrench icon 🔧), there is a single entry named **`Goal`**:
- **When no goal is set:** Tapping **`Goal`** sets the current page as your reading goal.
- **When a goal is active:** Tapping **`Goal`** opens the progress dialog.

### 2. Dialog with Progress & Quick Actions
Tapping an active goal opens a minimalist 2-line dialog with 3 quick action buttons:

```text
Goal: page 150
To goal: 222 p. / 11:44
```
*(In Polish: `Cel: strona 150` / `Do celu: 222 str. / 11:44`)*

- **Remaining time:** Dynamically calculated from your reading speed in KOReader statistics.
- **When goal is reached:** Displays `To goal: reached!` (PL: `Do celu: osiągnięty!`).
- **When goal is exceeded:** Displays `To goal: reached (+15 p.)` (PL: `Do celu: osiągnięty (+15 str.)`).

**Action buttons:**
- **Clear goal** (*Usuń cel*) – clears the reading goal.
- **Set here** (*Ustaw tu*) – updates the goal to your current page.
- **Go to goal** (*Idź do celu*) – jumps directly to the target page.

### 3. Bottom of Page Progress Display (Bottom Bar)
When a goal is active, progress is displayed horizontally centered at the bottom of the screen:
- **Format:** `222 p. / 11:44` (or in minutes: `222 p. / 156 min.`, or with selected icon: `↣ 222 p. / 11:44`).
- **Pixel-perfect baseline alignment:** Aligns to the exact typographic baseline of KOReader's native status bar.
- **Inherited styling:** Matches status bar font face, font size, bold weight, and bottom margin.
- **Live refresh:** Updates automatically on every page turn.

### 4. Consolidated Settings Menu
All options are grouped under a single entry in **Settings** (gear icon ⚙️) → **`Reading goal`** (PL: **`Cel czytania`**):

1. **Show reading goal on bottom of page** (*Pokaż cel na dole strony*) `[✓]` – toggles the bottom progress display.
2. **Time format** (*Format czasu*):
   - `Hours and minutes (e.g. 11:44)` (*Godziny i minuty*)
   - `Minutes only (e.g. 156 min.)` (*Tylko minuty*)
3. **Goal icon** (*Ikonka celu*):
   - `None` (*Brak*)
   - `Arrow (↣)` (*Strzałka (↣)*)
   - `Flag (⚑)` (*Chorągiewka (⚑)*)
   - `Bullet (•)` (*Kropka (•)*)
   - `NerdFont Bullseye ()` (*Tarcza NerdFont ()*)
   - `Bullseye (◎)` (*Tarcza (◎)*)
   - `Crosshair (⌖)` (*Celownik (⌖)*)
4. **Vertical adjustment** (*Korekta wysokości*):
   - `-2 px (higher / wyżej)`
   - `-1 px (slightly higher / lekko wyżej)`
   - `0 px (exact baseline / dokładna linia bazowa)`
   - `+1 px (slightly lower / lekko niżej)`
   - `+2 px (lower / niżej)`

### 5. Gesture Manager / Keybindings / Profiles
All actions are registered under the **Reader** section with the prefix **`Goal:`**:

| Action Name (English) | Action Name (Polish) | Dispatcher Key | Description |
| :--- | :--- | :--- | :--- |
| **Goal: Reading goal** | **Goal: Cel czytania** | `reading_goal` | Sets goal or opens dialog |
| **Goal: About goal** | **Goal: O celu** | `about_reading_goal` | Directly opens the dialog |
| **Goal: Clear goal** | **Goal: Usuń cel** | `clear_reading_goal` | Immediately clears the goal |
| **Goal: Set to current page** | **Goal: Ustaw na bieżącą stronę** | `set_reading_goal` | Sets target to current page |
| **Goal: Toggle on bottom of page** | **Goal: Przełącz cel na dole strony** | `toggle_goal_bottom_bar` | Toggles bottom progress display |
| **Goal: Toggle time format** | **Goal: Przełącz format czasu** | `cycle_goal_time_format` | Cycles between clock and minutes format |
| **Goal: Cycle icon** | **Goal: Przełącz ikonkę** | `cycle_goal_icon` | Cycles through icon styles |

You can assign these actions to swipe gestures, multi-finger taps, corner taps, or physical page turn buttons.

### 6. Book-Specific Persistence
Reading goals are saved in each book's `.sdr` sidecar metadata (`reading_goal`), so each book has its own goal that persists across restarts and firmware updates.

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

---

### 📥 Installation

1. Download [`2-reader-goal.lua`](https://github.com/oh1apps/koreader_goal/blob/main/2-reader-goal.lua).
2. Copy `2-reader-goal.lua` into the `patches/` directory of KOReader on your device:
   - **Kindle:** `/mnt/us/koreader/patches/`
   - **Kobo:** `/mnt/onboard/.adds/koreader/patches/`
   - **Android:** `/sdcard/koreader/patches/`
   - **PocketBook:** `/mnt/ext1/system/koreader/patches/`
3. Restart KOReader.
