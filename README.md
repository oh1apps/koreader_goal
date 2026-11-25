# KOReader Reading Goal Patch (2-reader-goal.lua)

A lightweight patch for KOReader that adds a **Reading Goal** tracking feature for the current book.

---

## 🎯 Features and Behavior

### 1. Tools Menu
The item is named **Goal** and is located in the **Tools** menu (alongside *Read timer* and *Reading statistics*):
- **When no goal is set:**
  Tapping **Goal** marks the current page as your reading goal and displays a toast notification (e.g., *"Reading goal set to page 150"*).
- **When a goal is active:**
  Tapping **Goal** opens a dialog with information and actions.

---

### 2. Dialog with Statistics
Tapping an active goal opens a minimalist dialog with two lines and three buttons:

```text
Reading goal: page 150
To goal: 222 p. / 11:44
```
*(or in minutes format: `To goal: 222 p. / 156 min.`)*

**Buttons (in a single row):**
- **Clear goal** – removes the reading goal,
- **Set here** – immediately updates the goal to your current page,
- **Go to goal** – jumps directly to the goal page.

---

### 3. Bottom of Page Progress Display
Progress is shown horizontally centered at the bottom of the screen, at the exact vertical position as KOReader's native status bar:
- **Concise format:**
  ```text
  222 p. / 11:44
  ```
  *(or with arrow `↣ 222 p. / 11:44`, flag `⚑`, bullet `•`, small NerdFont bullseye, or in minutes)*
- **Pixel-perfect baseline alignment:**
  The baseline of the text is aligned directly to the baseline of KOReader's native status bar. An optional vertical micro-adjustment (-2, -1, 0, +1, +2 px) is also available in settings.
- **Styling:**
  Inherits font and size settings from KOReader's status bar:
  - Font face (`text_font_face`),
  - Font size (`text_font_size`),
  - Bold weight (`text_font_bold`),
  - Bottom padding (`container_bottom_padding`).

---

### 4. Consolidated Settings Menu
In the main **Settings** menu (gear icon), there is **exactly ONE entry: `Reading goal`**, opening a submenu:

1. **Show reading goal on bottom of page** – toggle checkbox (✓)
2. **Time format**:
   * `Hours and minutes (e.g. 11:44)`
   * `Minutes only (e.g. 156 min.)`
3. **Goal icon**:
   * `No icon` (clean text: `222 p. / 11:44` only)
   * `Arrow (↣)` – native KOReader style
   * `Flag (⚑)` – compact flag
   * `Bullet (•)` – subtle dot
   * `NerdFont Bullseye` – small nerd font icon
   * `Bullseye (◎)` – classic bullseye
   * `Crosshair (⌖)` – classic crosshair
4. **Vertical adjustment** – micro-tune vertical offset (-2 px, -1 px, 0 px, +1 px, +2 px).

---

### 5. Dispatcher / Gesture Manager / Profiles / Physical Keys
All actions in the shortcuts/gestures/profiles lists are prefixed with **`Goal:`** under the **Reader** section:

1. **Goal: Reading goal** (`reading_goal`) – default action (sets goal or opens dialog),
2. **Goal: About goal** (`about_reading_goal`) – directly opens the dialog,
3. **Goal: Clear goal** (`clear_reading_goal`) – immediately clears the goal,
4. **Goal: Set to current page** (`set_reading_goal`) – sets goal to the current page,
5. **Goal: Toggle on bottom of page** (`toggle_goal_bottom_bar`) – toggles the bottom bar,
6. **Goal: Toggle time format** (`cycle_goal_time_format`) – cycles between clock and minutes,
7. **Goal: Cycle icon** (`cycle_goal_icon`) – cycles through icon styles.

---

### 6. API for Other Patches and Plugins (e.g., koreader_top_bar)
Exported to the global environment `_G`:

```lua
if _G.GoalPatch then
    local stats = _G.GoalPatch.getStats(self.ui)
    if stats then
        print(stats.goal_page)      -- e.g. 150
        print(stats.pages_left)     -- e.g. 222
        print(stats.time_left)      -- e.g. "11:44" or "156 min."
        print(stats.reached)        -- true / false
        print(stats.formatted_text) -- e.g. "222 p. / 11:44"
    end
    
    local str = _G.GoalPatch.getBottomBarText(self.ui)
end
```

---

### 📥 Installation

1. Copy [`2-reader-goal.lua`](file:///D:/Coding/inne_projekty/koreader/Goal/2-reader-goal.lua) to `koreader/patches/` on your device:
   - **Kindle**: `/mnt/us/koreader/patches/`
   - **Kobo**: `/mnt/onboard/.adds/koreader/patches/`
   - **Android**: `/sdcard/koreader/patches/`
   - **PocketBook**: `/mnt/ext1/system/koreader/patches/`
2. Restart KOReader.
