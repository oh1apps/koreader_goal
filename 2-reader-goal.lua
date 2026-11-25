--[[--
    Patch "Reading Goal" (Cel czytania) dla KOReader
    Dodaje funkcjonalność wyznaczania i śledzenia celu czytania.
    
    Główne elementy:
    1. Menu Tools (Narzędzia):
       - Dokładnie jedna krótka pozycja "Goal".
       - Kliknięcie: jeśli brak celu -> wyznacza cel na obecną stronę; jeśli cel istnieje -> otwiera okno dialogowe celu.
    2. Okno dialogowe (ButtonDialog):
       - Linijka 1: Cel czytania: strona xx (lub Reading goal: page xx)
       - Linijka 2: Do celu: 222 str. / 11:44 (lub minutowo: 222 str. / 156 min.)
       - Przyciski: [ Usuń cel ] [ Ustaw tu ] [ Idź do celu ]
    3. Wyświetlanie postępu na środku na dole strony:
       - Format: [Ikonka] 222 str. / 11:44 (lub minutowo / lub bez ikonki)
       - Wyrównanie: idealnie dopasowane do linii bazowej i wysokości fabrycznego paska stanu (co do pojedynczego piksela).
    4. Menu Ustawienia (Settings):
       - DOKŁADNIE JEDNA wspólna pozycja "Cel czytania" (Reading goal), która grupuje w podmenu wszystkie opcje:
         * Pokaż cel na dole strony (włącznik/wyłącznik z haczykiem)
         * Format czasu (godziny i minuty 11:44 / tylko minuty 156 min.)
         * Ikonka celu (Brak ikonki, Strzałka ↣, Chorągiewka ⚑, Kropka •, Tarcza NerdFont, Tarcza ◎, Celownik ⌖)
         * Korekta wysokości w pionie (-2, -1, 0, +1, +2 px)
    5. Dispatcher / Gesture Manager / Profile / Przyciski fizyczne:
       - Wszystkie akcje oznaczone czytelnym prefiksem "Goal: ":
         * Goal: Cel czytania / Reading goal
         * Goal: O celu / About goal
         * Goal: Usuń cel / Clear goal
         * Goal: Ustaw na bieżącą stronę / Set to current page
         * Goal: Przełącz cel na dole strony / Toggle on bottom of page
         * Goal: Przełącz format czasu / Toggle time format
         * Goal: Przełącz ikonkę celu / Cycle goal icon
    6. API dla innych patchy i wtyczek (np. koreader_top_bar):
       - _G.GoalPatch
       - _G.ReadingGoal
       - package.loaded["reading_goal"]
       - self.ui.reading_goal
       - self.ui:getReadingGoalStats()
--]]--

local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local ButtonDialog = require("ui/widget/buttondialog")
local Device = require("device")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local Font = require("ui/font")
local Notification = require("ui/widget/notification")
local ReaderMenu = require("apps/reader/modules/readermenu")
local ReaderUI = require("apps/reader/readerui")
local ReaderView = require("apps/reader/modules/readerview")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local logger = require("logger")
local Screen = Device.screen

local GoalPatch = {}

-- Wykrywanie języka interfejsu (język polski vs angielski/inny)
function GoalPatch.isPolish()
    local lang = G_reader_settings and G_reader_settings:readSetting("language")
    if not lang or lang == "" then
        lang = os.getenv("LANG") or ""
    end
    return lang:sub(1, 2) == "pl"
end

-- Skrócony format liczby stron (np. "222 str." lub "222 p.")
function GoalPatch.formatPagesShort(n, polish)
    if polish then
        return string.format("%d str.", n)
    else
        return string.format("%d p.", n)
    end
end

-- Bezpieczne pobieranie bieżącej strony dokumentu
function GoalPatch.getCurrentPage(ui)
    if not ui then return 1 end
    if ui.getCurrentPage then
        return ui:getCurrentPage()
    elseif ui.paging and ui.paging.current_page then
        return ui.paging.current_page
    elseif ui.document and ui.document.getCurrentPage then
        return ui.document:getCurrentPage()
    elseif ui.view and ui.view.state and ui.view.state.page then
        return ui.view.state.page
    end
    return 1
end

-- Bezpieczne pobieranie całkowitej liczby stron
function GoalPatch.getTotalPages(ui)
    if ui and ui.document and ui.document.getPageCount then
        local ok, count = pcall(ui.document.getPageCount, ui.document)
        if ok and count and count > 0 then
            return count
        end
    end
    return nil
end

-- Odczyt zapisanego celu z metadanych książki (sidecar .sdr)
function GoalPatch.getGoal(ui)
    if ui and ui.doc_settings then
        return ui.doc_settings:readSetting("reading_goal")
    end
    return nil
end

-- Zapisanie celu czytania w metadanych książki
function GoalPatch.setGoal(ui, page)
    if ui and ui.doc_settings then
        ui.doc_settings:saveSetting("reading_goal", page)
        ui.doc_settings:flush()
    end
end

-- Usunięcie celu czytania
function GoalPatch.clearGoal(ui)
    if not ui or not ui.doc_settings then return end
    if ui.doc_settings:readSetting("reading_goal") then
        ui.doc_settings:delSetting("reading_goal")
        ui.doc_settings:flush()
        UIManager:show(Notification:new{
            text = GoalPatch.isPolish() and "Cel czytania został usunięty" or "Reading goal removed",
        })
    else
        UIManager:show(Notification:new{
            text = GoalPatch.isPolish() and "Brak aktywnego celu czytania" or "No active reading goal",
        })
    end
    if ui.dialog then
        UIManager:setDirty(ui.dialog, "ui")
    else
        UIManager:setDirty(nil, "ui")
    end
end

-- =========================================================================
-- Formatowanie czasu do celu: "11:44" (godziny:minuty) lub "156 min."
-- =========================================================================

-- Pobranie wybranego formatu czasu ("clock" lub "minutes", domyślnie "clock")
function GoalPatch.getTimeFormat()
    return G_reader_settings:readSetting("goal_time_format", "clock")
end

-- Zmiana formatu czasu
function GoalPatch.setTimeFormat(format)
    G_reader_settings:saveSetting("goal_time_format", format)
end

-- Przełączenie formatu czasu między "clock" a "minutes"
function GoalPatch.cycleTimeFormat()
    local current = GoalPatch.getTimeFormat()
    local new_fmt = (current == "clock") and "minutes" or "clock"
    GoalPatch.setTimeFormat(new_fmt)
    return new_fmt
end

-- Formatowanie czasu do celu
function GoalPatch.formatTimeToGoal(ui, pages, polish)
    local fmt = GoalPatch.getTimeFormat()
    if not pages or pages <= 0 then
        return (fmt == "minutes") and "0 min." or "0:00"
    end

    local total_sec = nil
    if ui and ui.statistics and ui.statistics.avg_time and ui.statistics.avg_time == ui.statistics.avg_time and ui.statistics.avg_time > 0 then
        total_sec = math.floor(pages * ui.statistics.avg_time + 0.5)
    end

    if total_sec then
        local total_min = math.max(1, math.floor(total_sec / 60 + 0.5))
        if fmt == "minutes" then
            return string.format("%d min.", total_min)
        else
            local h = math.floor(total_min / 60)
            local m = total_min % 60
            return string.format("%d:%02d", h, m)
        end
    end

    -- Fallback jeśli statystyki średniego czasu czytania nie są jeszcze zebrane
    if fmt == "minutes" then
        return "-- min."
    else
        return "--:--"
    end
end

-- =========================================================================
-- Wybór ikonki celu (Brak, Strzałka ↣, Chorągiewka ⚑, Kropka •, NerdFont, ◎, ⌖)
-- =========================================================================
function GoalPatch.getIconStyle()
    return G_reader_settings:readSetting("goal_icon_style", "arrow")
end

function GoalPatch.setIconStyle(style)
    G_reader_settings:saveSetting("goal_icon_style", style)
end

function GoalPatch.getIconPrefix()
    local style = GoalPatch.getIconStyle()
    if style == "none" then
        return ""
    elseif style == "arrow" then
        local is_rtl = BD and BD.mirroredUILayout and BD.mirroredUILayout()
        return is_rtl and "↢ " or "↣ "
    elseif style == "flag" then
        return "⚑ "
    elseif style == "bullet" then
        return "• "
    elseif style == "nerd_bullseye" then
        return "\u{F140} "
    elseif style == "bullseye" then
        return "◎ "
    elseif style == "crosshair" then
        return "⌖ "
    end
    return ""
end

function GoalPatch.cycleIconStyle()
    local styles = { "none", "arrow", "flag", "bullet", "nerd_bullseye", "bullseye", "crosshair" }
    local current = GoalPatch.getIconStyle()
    local next_style = "arrow"
    for i, s in ipairs(styles) do
        if s == current then
            next_style = styles[(i % #styles) + 1]
            break
        end
    end
    GoalPatch.setIconStyle(next_style)
    return next_style
end

-- Korekta wysokości w pionie (piksele, domyślnie 0)
function GoalPatch.getVOffset()
    return G_reader_settings:readSetting("goal_v_offset", 0)
end

function GoalPatch.setVOffset(val)
    G_reader_settings:saveSetting("goal_v_offset", tonumber(val) or 0)
end

-- =========================================================================
-- Wyświetlanie na dole strony (Bottom Bar)
-- =========================================================================

-- Czy wyświetlanie na dole strony jest włączone w ustawieniach (domyślnie włączone)
function GoalPatch.isBottomBarEnabled()
    return G_reader_settings:nilOrTrue("goal_bottom_bar_enabled")
end

-- Przełączenie wyświetlania na dole strony
function GoalPatch.toggleBottomBar()
    local current = GoalPatch.isBottomBarEnabled()
    G_reader_settings:saveSetting("goal_bottom_bar_enabled", not current)
    return not current
end

-- Formatowanie tekstu paska dolnego: np. "↣ 222 str. / 11:44" lub "222 str. / 11:44"
function GoalPatch.getBottomBarText(ui, current_page, goal_page)
    current_page = current_page or GoalPatch.getCurrentPage(ui)
    goal_page = goal_page or GoalPatch.getGoal(ui)
    if not goal_page then return nil end

    local polish = GoalPatch.isPolish()
    local prefix = GoalPatch.getIconPrefix()
    local text
    if current_page < goal_page then
        local diff = goal_page - current_page
        local pages_disp = GoalPatch.formatPagesShort(diff, polish)
        local time_disp = GoalPatch.formatTimeToGoal(ui, diff, polish)
        text = string.format("%s%s / %s", prefix, pages_disp, time_disp)
    elseif current_page == goal_page then
        text = polish and (prefix .. "Osiągnięty!") or (prefix .. "Reached!")
    else
        local passed = current_page - goal_page
        local passed_disp = GoalPatch.formatPagesShort(passed, polish)
        text = polish and string.format("%sOsiągnięty (+%s)", prefix, passed_disp)
            or string.format("%sReached (+%s)", prefix, passed_disp)
    end
    return text
end

-- Bezpieczne rysowanie informacji o celu na dole strony
function GoalPatch._paintBottomBarUnsafe(view, bb, x, y)
    if not GoalPatch.isBottomBarEnabled() then return end
    if not view or not view.ui or not view.ui.document then return end

    local ui = view.ui
    local goal_page = GoalPatch.getGoal(ui)
    if not goal_page then return end

    local current_page = GoalPatch.getCurrentPage(ui)
    local text = GoalPatch.getBottomBarText(ui, current_page, goal_page)
    if not text or text == "" then return end

    -- Pobranie parametrów z fabrycznego paska stanu (font, rozmiar, pogrubienie, margines)
    local footer_settings = G_reader_settings:readSetting("footer") or {}
    local font_face_file = footer_settings.text_font_face or "./fonts/noto/NotoSans-Regular.ttf"
    local font_face_index = footer_settings.text_font_face_index or 0
    local font_size = footer_settings.text_font_size or 14
    local font_bold = footer_settings.text_font_bold or false

    local FontChooser = package.loaded["ui/widget/fontchooser"]
    if FontChooser and not FontChooser.isFontRegistered(font_face_file) then
        font_face_file = "./fonts/noto/NotoSans-Regular.ttf"
        font_face_index = 0
    end

    local face
    if view.footer and view.footer.footer_text_face then
        face = view.footer.footer_text_face
    else
        local ok_face, res_face = pcall(Font.getFace, Font, font_face_file, font_size, font_face_index)
        if ok_face and res_face then
            face = res_face
        else
            face = Font:getFace("ffont", font_size)
        end
    end

    local is_night = G_reader_settings:isTrue("night_mode")
    local fg_color = is_night and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK

    -- Używamy dokładnie takiego samego paddingu jak w footer_text, aby metryki linii i bazowa wysokość były identyczne
    local padding = (view.footer and view.footer.footer_text and view.footer.footer_text.padding)
        or Size.padding.small

    local text_widget = TextWidget:new{
        text = BD.auto(text),
        face = face,
        bold = font_bold,
        fgcolor = fg_color,
        padding = padding,
    }

    local widget_size = text_widget:getSize()
    local screen_width = Screen:getWidth()
    local screen_height = Screen:getHeight()

    local v_offset = GoalPatch.getVOffset()

    local draw_x = math.floor((screen_width - widget_size.w) / 2)
    local draw_y

    -- Pobieramy dokładną pozycję kontenera tekstu paska stanu (jeśli jest widoczny)
    local footer_text_y = nil
    if view.footer and view.footer_visible then
        if view.footer.text_container and view.footer.text_container.dimen and view.footer.text_container.dimen.y and view.footer.text_container.dimen.y > 0 then
            footer_text_y = view.footer.text_container.dimen.y
        elseif view.footer.footer_text and view.footer.footer_text.dimen and view.footer.footer_text.dimen.y and view.footer.footer_text.dimen.y > 0 then
            footer_text_y = view.footer.footer_text.dimen.y
        end
    end

    if footer_text_y then
        -- Idealne zrównanie linii bazowej tekstu z fabrycznym paskiem stanu
        draw_y = footer_text_y + v_offset
    else
        local container_height = (view.footer and view.footer.height)
            or Screen:scaleBySize(footer_settings.container_height or G_defaults:readSetting("DMINIBAR_CONTAINER_HEIGHT") or 24)
        local bottom_padding = (view.footer and view.footer.bottom_padding)
            or Screen:scaleBySize(footer_settings.container_bottom_padding or 1)
        draw_y = screen_height - bottom_padding - container_height + math.floor((container_height - widget_size.h) / 2) + v_offset
    end

    -- Oczyszczenie tła pod napisem dla zapewnienia pełnej czytelności
    local bg_color = view.outer_page_color or (is_night and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_WHITE)
    local pad_x = Screen:scaleBySize(4)
    local pad_y = Screen:scaleBySize(1)
    bb:paintRect(draw_x - pad_x, draw_y - pad_y, widget_size.w + 2 * pad_x, widget_size.h + 2 * pad_y, bg_color)

    text_widget:paintTo(bb, draw_x, draw_y)
    text_widget:free()
end

-- Główna metoda paintBottomBar z zabezpieczeniem pcall
function GoalPatch.paintBottomBar(view, bb, x, y)
    local ok, err = pcall(GoalPatch._paintBottomBarUnsafe, view, bb, x, y)
    if not ok then
        logger.warn("GoalPatch paintBottomBar error:", err)
    end
end

-- Przechwycenie ReaderView.paintTo
local orig_ReaderView_paintTo = ReaderView.paintTo
ReaderView.paintTo = function(self, bb, x, y)
    orig_ReaderView_paintTo(self, bb, x, y)
    GoalPatch.paintBottomBar(self, bb, x, y)
end

-- =========================================================================
-- Okno dialogowe szczegółów celu (ButtonDialog)
-- =========================================================================
function GoalPatch.showDialog(ui)
    if not ui or not ui.doc_settings then return end
    local goal_page = GoalPatch.getGoal(ui)
    if not goal_page then return end

    local current_page = GoalPatch.getCurrentPage(ui)
    local polish = GoalPatch.isPolish()
    local diff = goal_page - current_page

    local lines = {}
    if polish then
        -- 1. Cel czytania: strona xx
        table.insert(lines, string.format("Cel czytania: strona %d", goal_page))
        -- 2. Do celu: 222 str. / 11:44 (lub minutowo)
        if diff > 0 then
            local pages_disp = GoalPatch.formatPagesShort(diff, true)
            local time_disp = GoalPatch.formatTimeToGoal(ui, diff, true)
            table.insert(lines, string.format("Do celu: %s / %s", pages_disp, time_disp))
        elseif diff == 0 then
            table.insert(lines, "Do celu: osiągnięty!")
        else
            local passed = -diff
            table.insert(lines, string.format("Do celu: osiągnięty (+%s)", GoalPatch.formatPagesShort(passed, true)))
        end
    else
        -- 1. Reading goal: page xx
        table.insert(lines, string.format("Reading goal: page %d", goal_page))
        -- 2. To goal: 222 p. / 11:44 (lub minutowo)
        if diff > 0 then
            local pages_disp = GoalPatch.formatPagesShort(diff, false)
            local time_disp = GoalPatch.formatTimeToGoal(ui, diff, false)
            table.insert(lines, string.format("To goal: %s / %s", pages_disp, time_disp))
        elseif diff == 0 then
            table.insert(lines, "To goal: reached!")
        else
            local passed = -diff
            table.insert(lines, string.format("To goal: reached (+%s)", GoalPatch.formatPagesShort(passed, false)))
        end
    end

    local dialog
    local buttons = {
        {
            {
                text = polish and "Usuń cel" or "Clear goal",
                callback = function()
                    UIManager:close(dialog)
                    GoalPatch.clearGoal(ui)
                end,
            },
            {
                text = polish and "Ustaw tu" or "Set here",
                callback = function()
                    UIManager:close(dialog)
                    GoalPatch.setGoalToCurrent(ui)
                end,
            },
            {
                text = polish and "Idź do celu" or "Go to goal",
                callback = function()
                    UIManager:close(dialog)
                    ui:handleEvent(Event:new("GotoPage", goal_page))
                end,
            },
        },
    }

    dialog = ButtonDialog:new{
        title = table.concat(lines, "\n"),
        title_align = "left",
        use_info_style = true,
        buttons = buttons,
    }
    UIManager:show(dialog)
end

-- Ustawienie bieżącej strony jako celu czytania
function GoalPatch.setGoalToCurrent(ui)
    if not ui or not ui.doc_settings then return end
    local curr = GoalPatch.getCurrentPage(ui)
    GoalPatch.setGoal(ui, curr)
    UIManager:show(Notification:new{
        text = string.format(
            GoalPatch.isPolish() and "Cel czytania ustawiony na stronę %d" or "Reading goal set to page %d",
            curr
        ),
    })
    if ui.dialog then
        UIManager:setDirty(ui.dialog, "ui")
    else
        UIManager:setDirty(nil, "ui")
    end
end

-- Główny wyzwalacz akcji Goal (z menu lub gestu)
function GoalPatch.trigger(ui)
    if not ui or not ui.doc_settings then
        UIManager:show(Notification:new{
            text = GoalPatch.isPolish() and "Otwórz książkę, aby zarządzać celem czytania."
                or "Open a book to manage reading goal.",
        })
        return
    end

    local goal = GoalPatch.getGoal(ui)
    if not goal then
        GoalPatch.setGoalToCurrent(ui)
    else
        GoalPatch.showDialog(ui)
    end
end

-- Statystyki celu udostępniane dla innych komponentów
function GoalPatch.getStats(ui)
    ui = ui or (ReaderUI and ReaderUI.instance)
    if not ui then return nil end
    local goal_page = GoalPatch.getGoal(ui)
    if not goal_page then return nil end
    local current_page = GoalPatch.getCurrentPage(ui)
    local total_pages = GoalPatch.getTotalPages(ui)
    local pages_left = goal_page - current_page
    local polish = GoalPatch.isPolish()
    local time_str = GoalPatch.formatTimeToGoal(ui, math.max(0, pages_left), polish)

    return {
        goal_page = goal_page,
        current_page = current_page,
        total_pages = total_pages,
        pages_left = pages_left,
        time_left = time_str,
        reached = current_page >= goal_page,
        exceeded = current_page > goal_page,
        formatted_text = GoalPatch.getBottomBarText(ui, current_page, goal_page),
    }
end

-- =========================================================================
-- Integracja z ReaderUI: obsługa zdarzeń z Dispatchera / Gestów / Skrótów
-- =========================================================================
function ReaderUI:onReadingGoal()
    GoalPatch.trigger(self)
    return true
end

function ReaderUI:onShowReadingGoal()
    GoalPatch.showDialog(self)
    return true
end
ReaderUI.onReadingGoalAbout = ReaderUI.onShowReadingGoal

function ReaderUI:onClearReadingGoal()
    GoalPatch.clearGoal(self)
    return true
end

function ReaderUI:onSetReadingGoal()
    GoalPatch.setGoalToCurrent(self)
    return true
end

function ReaderUI:onToggleGoalBottomBar()
    GoalPatch.toggleBottomBar()
    if self.dialog then
        UIManager:setDirty(self.dialog, "ui")
    else
        UIManager:setDirty(nil, "ui")
    end
    return true
end

function ReaderUI:onCycleGoalTimeFormat()
    GoalPatch.cycleTimeFormat()
    if self.dialog then
        UIManager:setDirty(self.dialog, "ui")
    else
        UIManager:setDirty(nil, "ui")
    end
    return true
end

function ReaderUI:onCycleGoalIcon()
    GoalPatch.cycleIconStyle()
    if self.dialog then
        UIManager:setDirty(self.dialog, "ui")
    else
        UIManager:setDirty(nil, "ui")
    end
    return true
end

-- Metody publiczne na obiekcie ui
function ReaderUI:getReadingGoal()
    return GoalPatch.getGoal(self)
end

function ReaderUI:getReadingGoalStats()
    return GoalPatch.getStats(self)
end

local orig_ReaderUI_init = ReaderUI.init
function ReaderUI:init()
    orig_ReaderUI_init(self)
    self.reading_goal = GoalPatch
end

-- =========================================================================
-- Rejestracja w globalnym środowisku (_G oraz package.loaded)
-- =========================================================================
_G.GoalPatch = GoalPatch
_G.ReadingGoal = GoalPatch
package.loaded["reading_goal"] = GoalPatch

-- =========================================================================
-- Rejestracja w Dispatcherze (Gesture Manager, Profile czytania, Keybindings)
-- =========================================================================
if Dispatcher and Dispatcher.registerAction then
    local pl = GoalPatch.isPolish()

    -- Oczyszczenie wcześniejszych rejestracji
    if Dispatcher.removeAction then
        Dispatcher:removeAction("show_reading_goal")
        Dispatcher:removeAction("reading_goal")
        Dispatcher:removeAction("about_reading_goal")
        Dispatcher:removeAction("clear_reading_goal")
        Dispatcher:removeAction("set_reading_goal")
        Dispatcher:removeAction("toggle_goal_bottom_bar")
        Dispatcher:removeAction("cycle_goal_time_format")
        Dispatcher:removeAction("cycle_goal_icon")
    end

    -- 1. Cel czytania
    Dispatcher:registerAction("reading_goal", {
        category = "none",
        event = "ReadingGoal",
        title = pl and "Goal: Cel czytania" or "Goal: Reading goal",
        reader = true,
    })

    -- 2. O celu
    Dispatcher:registerAction("about_reading_goal", {
        category = "none",
        event = "ShowReadingGoal",
        title = pl and "Goal: O celu" or "Goal: About goal",
        reader = true,
    })

    -- 3. Usuń cel
    Dispatcher:registerAction("clear_reading_goal", {
        category = "none",
        event = "ClearReadingGoal",
        title = pl and "Goal: Usuń cel" or "Goal: Clear goal",
        reader = true,
    })

    -- 4. Ustaw na bieżącą stronę
    Dispatcher:registerAction("set_reading_goal", {
        category = "none",
        event = "SetReadingGoal",
        title = pl and "Goal: Ustaw na bieżącą stronę" or "Goal: Set to current page",
        reader = true,
    })

    -- 5. Przełącz cel na dole strony
    Dispatcher:registerAction("toggle_goal_bottom_bar", {
        category = "none",
        event = "ToggleGoalBottomBar",
        title = pl and "Goal: Przełącz cel na dole strony" or "Goal: Toggle on bottom of page",
        reader = true,
    })

    -- 6. Przełącz format czasu
    Dispatcher:registerAction("cycle_goal_time_format", {
        category = "none",
        event = "CycleGoalTimeFormat",
        title = pl and "Goal: Przełącz format czasu" or "Goal: Toggle time format",
        reader = true,
    })

    -- 7. Przełącz ikonkę celu
    Dispatcher:registerAction("cycle_goal_icon", {
        category = "none",
        event = "CycleGoalIcon",
        title = pl and "Goal: Przełącz ikonkę" or "Goal: Cycle icon",
        reader = true,
    })
end

-- =========================================================================
-- Przechwycenie ReaderMenu:setUpdateItemTable (Menu Tools + Jedno Menu Ustawień)
-- =========================================================================
local orig_ReaderMenu_setUpdateItemTable = ReaderMenu.setUpdateItemTable

function ReaderMenu:setUpdateItemTable()
    local menu_order = require("ui/elements/reader_menu_order")
    if menu_order then
        -- Usunięcie wszelkich starych wpisów celu z menu "navi"
        if menu_order.navi then
            for i = #menu_order.navi, 1, -1 do
                local v = menu_order.navi[i]
                if v == "reading_goal" or v == "goal_settings" or v == "goal_bottom_bar" then
                    table.remove(menu_order.navi, i)
                end
            end
        end

        -- 1. W menu "tools" (Narzędzia) -> dokładnie jedna pozycja "Goal"
        if menu_order.tools then
            for i = #menu_order.tools, 1, -1 do
                local v = menu_order.tools[i]
                if v == "goal_settings" or v == "goal_bottom_bar" or v == "goal_time_format" or v == "goal_icon" then
                    table.remove(menu_order.tools, i)
                end
            end
            local already_in_tools = false
            for _, v in ipairs(menu_order.tools) do
                if v == "reading_goal" then
                    already_in_tools = true
                    break
                end
            end
            if not already_in_tools then
                local insert_pos = nil
                for i, v in ipairs(menu_order.tools) do
                    if v == "read_timer" or v == "statistics" then
                        insert_pos = i + 1
                        break
                    end
                end
                if insert_pos then
                    table.insert(menu_order.tools, insert_pos, "reading_goal")
                else
                    table.insert(menu_order.tools, 1, "reading_goal")
                end
            end
        end

        -- 2. W menu "setting" (Ustawienia) -> DOKŁADNIE JEDNA pozycja "goal_settings"
        if menu_order.setting then
            for i = #menu_order.setting, 1, -1 do
                local v = menu_order.setting[i]
                if v == "goal_settings" or v == "goal_bottom_bar" or v == "goal_time_format"
                    or v == "goal_icon" or v == "goal_icon_style" or v == "reading_goal_bottom" then
                    table.remove(menu_order.setting, i)
                end
            end
            local insert_pos = nil
            for i, v in ipairs(menu_order.setting) do
                if v == "status_bar" then
                    insert_pos = i + 1
                    break
                end
            end
            if insert_pos then
                table.insert(menu_order.setting, insert_pos, "goal_settings")
            else
                table.insert(menu_order.setting, "goal_settings")
            end
        end
    end

    -- W menu Tools: krótka nazwa "Goal"
    self.menu_items.reading_goal = {
        text = "Goal",
        callback = function(touchmenu_instance)
            GoalPatch.trigger(self.ui)
        end,
    }

    -- W menu Ustawienia: JEDNA wspólna pozycja ze wszystkimi opcjami w podmenu
    self.menu_items.goal_settings = {
        text = GoalPatch.isPolish() and "Cel czytania" or "Reading goal",
        sub_item_table = {
            {
                text = GoalPatch.isPolish() and "Pokaż cel na dole strony" or "Show reading goal on bottom of page",
                checked_func = function()
                    return GoalPatch.isBottomBarEnabled()
                end,
                callback = function(touchmenu_instance)
                    GoalPatch.toggleBottomBar()
                    if touchmenu_instance then
                        touchmenu_instance:updateItems()
                    end
                    if self.ui and self.ui.dialog then
                        UIManager:setDirty(self.ui.dialog, "ui")
                    else
                        UIManager:setDirty(nil, "ui")
                    end
                end,
            },
            {
                text_func = function()
                    local fmt = GoalPatch.getTimeFormat()
                    local pl = GoalPatch.isPolish()
                    local name = (fmt == "minutes")
                        and (pl and "Tylko minuty (156 min.)" or "Minutes only (156 min.)")
                        or (pl and "Godziny i minuty (11:44)" or "Hours and minutes (11:44)")
                    return pl and string.format("Format czasu: %s", name)
                        or string.format("Time format: %s", name)
                end,
                sub_item_table = {
                    {
                        text_func = function()
                            return GoalPatch.isPolish()
                                and "Godziny i minuty (np. 11:44)"
                                or "Hours and minutes (e.g. 11:44)"
                        end,
                        checked_func = function()
                            return GoalPatch.getTimeFormat() == "clock"
                        end,
                        callback = function(touchmenu_instance)
                            GoalPatch.setTimeFormat("clock")
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                            if self.ui and self.ui.dialog then UIManager:setDirty(self.ui.dialog, "ui") else UIManager:setDirty(nil, "ui") end
                        end,
                    },
                    {
                        text_func = function()
                            return GoalPatch.isPolish()
                                and "Tylko minuty (np. 156 min.)"
                                or "Minutes only (e.g. 156 min.)"
                        end,
                        checked_func = function()
                            return GoalPatch.getTimeFormat() == "minutes"
                        end,
                        callback = function(touchmenu_instance)
                            GoalPatch.setTimeFormat("minutes")
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                            if self.ui and self.ui.dialog then UIManager:setDirty(self.ui.dialog, "ui") else UIManager:setDirty(nil, "ui") end
                        end,
                    },
                },
            },
            {
                text_func = function()
                    local style = GoalPatch.getIconStyle()
                    local pl = GoalPatch.isPolish()
                    local names = {
                        none = pl and "Brak ikonki" or "No icon",
                        arrow = pl and "Strzałka (↣)" or "Arrow (↣)",
                        flag = pl and "Chorągiewka (⚑)" or "Flag (⚑)",
                        bullet = pl and "Kropka (•)" or "Bullet (•)",
                        nerd_bullseye = pl and "Tarcza NerdFont" or "NerdFont Bullseye",
                        bullseye = pl and "Tarcza (◎)" or "Bullseye (◎)",
                        crosshair = pl and "Celownik (⌖)" or "Crosshair (⌖)",
                    }
                    local name = names[style] or (pl and "Brak" or "None")
                    return pl and string.format("Ikonka celu: %s", name)
                        or string.format("Goal icon: %s", name)
                end,
                sub_item_table = {
                    {
                        text = GoalPatch.isPolish() and "Brak ikonki (samo 222 str. / 11:44)" or "No icon (222 p. / 11:44 only)",
                        checked_func = function()
                            return GoalPatch.getIconStyle() == "none"
                        end,
                        callback = function(touchmenu_instance)
                            GoalPatch.setIconStyle("none")
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                            if self.ui and self.ui.dialog then UIManager:setDirty(self.ui.dialog, "ui") else UIManager:setDirty(nil, "ui") end
                        end,
                    },
                    {
                        text = GoalPatch.isPolish() and "Strzałka (↣) - styl KOReadera" or "Arrow (↣) - KOReader style",
                        checked_func = function()
                            return GoalPatch.getIconStyle() == "arrow"
                        end,
                        callback = function(touchmenu_instance)
                            GoalPatch.setIconStyle("arrow")
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                            if self.ui and self.ui.dialog then UIManager:setDirty(self.ui.dialog, "ui") else UIManager:setDirty(nil, "ui") end
                        end,
                    },
                    {
                        text = GoalPatch.isPolish() and "Chorągiewka (⚑)" or "Flag (⚑)",
                        checked_func = function()
                            return GoalPatch.getIconStyle() == "flag"
                        end,
                        callback = function(touchmenu_instance)
                            GoalPatch.setIconStyle("flag")
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                            if self.ui and self.ui.dialog then UIManager:setDirty(self.ui.dialog, "ui") else UIManager:setDirty(nil, "ui") end
                        end,
                    },
                    {
                        text = GoalPatch.isPolish() and "Kropka (•)" or "Bullet (•)",
                        checked_func = function()
                            return GoalPatch.getIconStyle() == "bullet"
                        end,
                        callback = function(touchmenu_instance)
                            GoalPatch.setIconStyle("bullet")
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                            if self.ui and self.ui.dialog then UIManager:setDirty(self.ui.dialog, "ui") else UIManager:setDirty(nil, "ui") end
                        end,
                    },
                    {
                        text = GoalPatch.isPolish() and "Tarcza NerdFont (mała)" or "NerdFont Bullseye (small)",
                        checked_func = function()
                            return GoalPatch.getIconStyle() == "nerd_bullseye"
                        end,
                        callback = function(touchmenu_instance)
                            GoalPatch.setIconStyle("nerd_bullseye")
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                            if self.ui and self.ui.dialog then UIManager:setDirty(self.ui.dialog, "ui") else UIManager:setDirty(nil, "ui") end
                        end,
                    },
                    {
                        text = GoalPatch.isPolish() and "Tarcza (◎)" or "Bullseye (◎)",
                        checked_func = function()
                            return GoalPatch.getIconStyle() == "bullseye"
                        end,
                        callback = function(touchmenu_instance)
                            GoalPatch.setIconStyle("bullseye")
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                            if self.ui and self.ui.dialog then UIManager:setDirty(self.ui.dialog, "ui") else UIManager:setDirty(nil, "ui") end
                        end,
                    },
                    {
                        text = GoalPatch.isPolish() and "Celownik (⌖)" or "Crosshair (⌖)",
                        checked_func = function()
                            return GoalPatch.getIconStyle() == "crosshair"
                        end,
                        callback = function(touchmenu_instance)
                            GoalPatch.setIconStyle("crosshair")
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                            if self.ui and self.ui.dialog then UIManager:setDirty(self.ui.dialog, "ui") else UIManager:setDirty(nil, "ui") end
                        end,
                    },
                },
            },
            {
                text_func = function()
                    local off = GoalPatch.getVOffset()
                    local pl = GoalPatch.isPolish()
                    local off_str = (off == 0) and (pl and "0 px (dokładna linia)" or "0 px (exact line)")
                        or string.format("%+d px", off)
                    return pl and string.format("Korekta wysokości: %s", off_str)
                        or string.format("Vertical adjustment: %s", off_str)
                end,
                sub_item_table = {
                    {
                        text = GoalPatch.isPolish() and "-2 px (wyżej)" or "-2 px (higher)",
                        checked_func = function() return GoalPatch.getVOffset() == -2 end,
                        callback = function(touchmenu_instance)
                            GoalPatch.setVOffset(-2)
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                            if self.ui and self.ui.dialog then UIManager:setDirty(self.ui.dialog, "ui") else UIManager:setDirty(nil, "ui") end
                        end,
                    },
                    {
                        text = GoalPatch.isPolish() and "-1 px (lekko wyżej)" or "-1 px (slightly higher)",
                        checked_func = function() return GoalPatch.getVOffset() == -1 end,
                        callback = function(touchmenu_instance)
                            GoalPatch.setVOffset(-1)
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                            if self.ui and self.ui.dialog then UIManager:setDirty(self.ui.dialog, "ui") else UIManager:setDirty(nil, "ui") end
                        end,
                    },
                    {
                        text = GoalPatch.isPolish() and "0 px (dokładna linia bazowa)" or "0 px (exact baseline)",
                        checked_func = function() return GoalPatch.getVOffset() == 0 end,
                        callback = function(touchmenu_instance)
                            GoalPatch.setVOffset(0)
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                            if self.ui and self.ui.dialog then UIManager:setDirty(self.ui.dialog, "ui") else UIManager:setDirty(nil, "ui") end
                        end,
                    },
                    {
                        text = GoalPatch.isPolish() and "+1 px (lekko niżej)" or "+1 px (slightly lower)",
                        checked_func = function() return GoalPatch.getVOffset() == 1 end,
                        callback = function(touchmenu_instance)
                            GoalPatch.setVOffset(1)
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                            if self.ui and self.ui.dialog then UIManager:setDirty(self.ui.dialog, "ui") else UIManager:setDirty(nil, "ui") end
                        end,
                    },
                    {
                        text = GoalPatch.isPolish() and "+2 px (niżej)" or "+2 px (lower)",
                        checked_func = function() return GoalPatch.getVOffset() == 2 end,
                        callback = function(touchmenu_instance)
                            GoalPatch.setVOffset(2)
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                            if self.ui and self.ui.dialog then UIManager:setDirty(self.ui.dialog, "ui") else UIManager:setDirty(nil, "ui") end
                        end,
                    },
                },
            },
        },
    }

    orig_ReaderMenu_setUpdateItemTable(self)
end

logger.info("Patch Reading Goal loaded successfully.")
