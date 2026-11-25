# KOReader Reading Goal Patch (`2-reader-goal.lua`)

A lightweight user patch for [KOReader](https://github.com/koreader/koreader) that allows you to set and track a **Reading Goal** (target page milestone) for your current book.

It provides a quick way to set a target for your reading session (e.g. read until page 250), displays remaining pages and estimated time at the bottom of the screen, and integrates natively with KOReader's menus, gestures, and status bar.

---

## 🎯 Features and Behavior

### 1. Tools Menu: `Goal`
In the **Tools** menu (wrench icon 🔧, next to *Read timer* and *Reading statistics*), there is a clean entry named **`Goal`**:
- **When no goal is set:**  
  Tapping **`Goal`** marks the current page as your reading goal and displays a toast notification (e.g. *"Reading goal set to page 150"* / *"Cel czytania ustawiony na stronę 150"*).
- **When a goal is active:**  
  Tapping **`Goal`** opens the dialog with remaining progress and quick actions.

---

### 2. Dialog with Progress & Quick Actions
Tapping an active goal opens a minimalist dialog with two lines of statistics and three action buttons:

```text
Goal: page 150
To goal: 222 p. / 11:44
```
*(In Polish: `Cel: strona 150` / `Do celu: 222 str. / 11:44`)*

- **Remaining time:** Dynamically calculated from your average reading speed tracked by KOReader's statistics module.
- **When goal is reached:** Displays `To goal: reached!` (PL: `Do celu: osiągnięty!`).
- **When goal is passed:** Displays `To goal: reached (+15 p.)` (PL: `Do celu: osiągnięty (+15 str.)`).

**Buttons in a single row:**
- **Clear goal** (*Usuń cel*) – clears the active reading goal.
- **Set here** (*Ustaw tu*) – immediately updates the goal to your current page.
- **Go to goal** (*Idź do celu*) – jumps directly to the goal page.

---

### 3. Bottom of Page Progress Display (Bottom Bar)
When a goal is active, progress is displayed horizontally centered at the bottom of the screen:

- **Concise format:**
  ```text
  222 p. / 11:44
  ```
  *(or in minutes: `222 p. / 156 min.`, or with selected icon: `↣ 222 p. / 11:44`)*
- **Pixel-perfect baseline alignment:**
  The text aligns to the exact typographic baseline of KOReader's native status bar.
- **Inherited styling:**
  Inherits font settings directly from KOReader's status bar:
  - Font face (`text_font_face`)
  - Font size (`text_font_size`)
  - Bold weight (`text_font_bold`)
  - Bottom padding (`container_bottom_padding`)
- **Per-page live refresh:**
  Re-renders automatically on every page turn without extra battery drain.

---

### 4. Consolidated Settings Menu
All configuration is gathered under **a single entry** in the main **Settings** menu (gear icon ⚙️) → **`Reading goal`** (PL: **`Cel czytania`**):

1. **Show reading goal on bottom of page** (*Pokaż cel na dole strony*) `[✓]` – toggles the bottom progress display.
2. **Time format** (*Format czasu*):
   - `Hours and minutes (e.g. 11:44)` (*Godziny i minuty*) – default clock style
   - `Minutes only (e.g. 156 min.)` (*Tylko minuty*)
3. **Goal icon** (*Ikonka celu*):
   - `No icon (222 p. / 11:44 only)` (*Brak ikonki*) – pure text matching the status bar
   - `Arrow (↣) - KOReader style` (*Strzałka (↣)*) – matches KOReader's native status bar arrow
   - `Flag (⚑)` (*Chorągiewka (⚑)*) – compact milestone flag
   - `Bullet (•)` (*Kropka (•)*) – subtle dot
   - `NerdFont Bullseye (small)` (*Tarcza NerdFont*) – compact target icon
   - `Bullseye (◎)` (*Tarcza (◎)*) – classic Unicode bullseye
   - `Crosshair (⌖)` (*Celownik (⌖)*) – classic crosshair
4. **Vertical adjustment** (*Korekta wysokości*):
   - `-2 px (higher / wyżej)`
   - `-1 px (slightly higher / lekko wyżej)`
   - `0 px (exact baseline / dokładna linia bazowa)` – default
   - `+1 px (slightly lower / lekko niżej)`
   - `+2 px (lower / niżej)`

---

### 5. Gesture Manager / Profiles / Keybindings (Dispatcher)
All actions are registered in KOReader's `Dispatcher` under the **Reader** section with the prefix **`Goal:`**:

| Action Name (English) | Action Name (Polish) | Dispatcher Key | Description |
| :--- | :--- | :--- | :--- |
| **Goal: Reading goal** | **Goal: Cel czytania** | `reading_goal` | Default action: sets goal or opens dialog |
| **Goal: About goal** | **Goal: O celu** | `about_reading_goal` | Directly opens the goal dialog |
| **Goal: Clear goal** | **Goal: Usuń cel** | `clear_reading_goal` | Immediately clears the goal |
| **Goal: Set to current page** | **Goal: Ustaw na bieżącą stronę** | `set_reading_goal` | Sets target to the current page |
| **Goal: Toggle on bottom of page** | **Goal: Przełącz cel na dole strony** | `toggle_goal_bottom_bar` | Toggles bottom progress display |
| **Goal: Toggle time format** | **Goal: Przełącz format czasu** | `cycle_goal_time_format` | Cycles between clock and minutes format |
| **Goal: Cycle icon** | **Goal: Przełącz ikonkę** | `cycle_goal_icon` | Cycles through icon styles |

You can assign these actions to swipe gestures, multi-finger taps, corner taps, or physical page turn buttons.

---

### 6. Bilingual Support & Persistence
- **Automatic Language Detection:**  
  Automatically switches between English and Polish based on KOReader's interface language setting.
- **Book-Specific Persistence:**  
  Reading goals are saved in each book's `.sdr` sidecar metadata (`reading_goal`), so each book has its own goal that persists across restarts and firmware updates.

---

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
