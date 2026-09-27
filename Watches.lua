-- Watches: saved searches. A post matches when it contains ALL of the watch's words (and is
-- in its category, unless "any"). A new match plays a sound (also when the window is
-- closed, never in combat), bumps the watch's badge and highlights the row.
local _, F = ...

local Hush = Hush
local W = Hush.Widgets

F.hits = {} -- unseen matches per watch id (this session)

-- SOUNDKIT names with numeric fallbacks.
F.SOUNDS = {
    { id = "bell", label = "Bell", kit = "READY_CHECK", fallback = 8960 },
    { id = "ping", label = "Ping", kit = "MAP_PING", fallback = 3175 },
    { id = "raid", label = "Raid warning", kit = "RAID_WARNING", fallback = 8959 },
    { id = "whisper", label = "Whisper", kit = "TELL_MESSAGE", fallback = 3081 },
    { id = "click", label = "Click", kit = "IG_MAINMENU_OPTION_CHECKBOX_ON", fallback = 856 },
}

function F.PlaySound(id)
    local sound = F.SOUNDS[1]
    for _, s in ipairs(F.SOUNDS) do if s.id == id then sound = s end end
    PlaySound((SOUNDKIT and SOUNDKIT[sound.kit]) or sound.fallback, "Master")
end

local lastSound = 0
local function alert()
    if InCombatLockdown() or UnitAffectingCombat("player") then return end
    local now = GetTime()
    if now - lastSound < 3 then return end
    lastSound = now
    F.PlaySound(F.db.watchSound)
end

-- "Healer UBRS" -> { "healer", "ubrs" }
function F.ParseWords(text)
    local words = {}
    for w in strlower(text or ""):gmatch("%S+") do words[#words + 1] = w end
    return words
end

local function matches(watch, p)
    if watch.paused or #watch.words == 0 then return false end
    if watch.cat and watch.cat ~= "any" and p.cat ~= watch.cat then return false end
    for _, w in ipairs(watch.words) do
        if not p.plain:find(w, 1, true) then return false end
    end
    return true
end

-- Called for every post; isNew is false for a merged repeat (which does not alert again).
function F.CheckWatches(p, isNew)
    p.watched = nil
    local fired = false
    for _, watch in ipairs(F.db.watches) do
        if matches(watch, p) then
            p.watched = true
            p.watchIds = p.watchIds or {}
            if not p.watchIds[watch.id] then
                p.watchIds[watch.id] = true
                if isNew or not p.alerted then
                    F.hits[watch.id] = (F.hits[watch.id] or 0) + 1
                    fired = true
                end
            end
        end
    end
    if fired then
        p.alerted = true
        alert()
    end
end

function F.WatchById(id)
    for i, w in ipairs(F.db.watches) do
        if w.id == id then return w, i end
    end
end

function F.SaveWatch(watch)
    if not watch.id then
        F.db.nextWatchId = (F.db.nextWatchId or 0) + 1
        watch.id = F.db.nextWatchId
        tinsert(F.db.watches, watch)
    end
end

function F.DeleteWatch(id)
    local _, i = F.WatchById(id)
    if i then tremove(F.db.watches, i) end
    F.hits[id] = nil
end

-- ---------------------------------------------------------------------------
-- Editor: name, words, category.
-- ---------------------------------------------------------------------------

local editor
local CATS = {
    { value = "any", label = "Any" }, { value = "lfg", label = "LFG" }, { value = "trade", label = "Trade" },
    { value = "services", label = "Services" }, { value = "guilds", label = "Guilds" },
}

local function buildEditor()
    local e = CreateFrame("Frame", nil, UIParent)
    e:SetSize(400, 250)
    e:SetPoint("CENTER", 0, 60)
    e:SetFrameStrata("DIALOG")
    e:EnableMouse(true)
    e:SetClampedToScreen(true)
    e.bg = W.Fill(e, "window", 0.98)
    e.bg:SetAllPoints()
    e.border = W.Border(e, "line")
    e.title = W.Text(e, "heading", 2, "text")
    e.title:SetPoint("TOPLEFT", 16, -16)

    local function label(text, y)
        local fs = W.Text(e, "semibold", -1, "textDim")
        fs:SetPoint("TOPLEFT", 16, y)
        fs:SetText(text)
    end
    label("Name", -48)
    e.name = W.EditBox(e, "e.g. Healer · UBRS", 28)
    e.name:SetPoint("TOPLEFT", 16, -66)
    e.name:SetWidth(368)
    e.name:SetMaxLetters(40)
    label("Words (all must be in the post)", -102)
    e.words = W.EditBox(e, "e.g. healer ubrs", 28)
    e.words:SetPoint("TOPLEFT", 16, -120)
    e.words:SetWidth(368)
    e.words:SetMaxLetters(100)
    label("Category", -156)
    e.cat = W.Segment(e, CATS)
    e.cat:SetPoint("TOPLEFT", 16, -174)

    local function close() e:Hide() end
    e.save = W.Button(e, "Save", "accent", function()
        local words = F.ParseWords(e.words:GetText())
        if #words == 0 then return end
        local w = e.watch or {}
        w.words = words
        w.name = strtrim(e.name:GetText() or "") ~= "" and strtrim(e.name:GetText()) or table.concat(words, " ")
        w.cat = e.cat.value or "any"
        F.SaveWatch(w)
        F.RecheckWatches()
        close()
        if F.UI then F.UI.Refresh() end
    end)
    e.save:SetPoint("BOTTOMRIGHT", -16, 14)
    e.cancel = W.Button(e, "Cancel", "ghost", close)
    e.cancel:SetPoint("RIGHT", e.save, "LEFT", -8, 0)
    e.words:SetScript("OnEnterPressed", function() e.save:Click() end)
    e.name:SetScript("OnEnterPressed", function() e.words:SetFocus() end)
    e.name:SetScript("OnTabPressed", function() e.words:SetFocus() end)
    e.words:SetScript("OnEscapePressed", close)
    e.name:SetScript("OnEscapePressed", close)
    if W.SkinPanel then W.SkinPanel(e, { kind = "dialog", hide = { e.bg }, borders = { e.border }, title = e.title }) end
    return e
end

-- watch = nil for a new one.
function F.EditWatch(watch)
    editor = editor or buildEditor()
    editor.watch = watch
    editor.title:SetText(watch and "EDIT WATCH" or "NEW WATCH")
    editor.name:SetText(watch and watch.name or "")
    editor.words:SetText(watch and table.concat(watch.words, " ") or "")
    editor.cat:Set(watch and watch.cat or "any")
    editor:Show()
    editor.name:SetFocus()
end

-- Re-check all posts after watches change (new matches do not alert).
function F.RecheckWatches()
    for _, p in ipairs(F.Posts("all", 60)) do
        p.watchIds = nil
        local saved = p.alerted
        p.alerted = true
        F.CheckWatches(p, false)
        p.alerted = saved
    end
end
