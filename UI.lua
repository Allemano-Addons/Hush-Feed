-- UI: the Hush Feed window (see the mockup): feeds with counts, watches and channels on the
-- left; search, role, time window and pause on top; one row per post with Whisper / Invite / ×.
-- The list is virtualized and only refreshes while the window is open (and not paused).
local _, F = ...

local Hush = Hush
local Theme, W = Hush.Theme, Hush.Widgets

local UI = {}
F.UI = UI

local WIDTH, HEIGHT, SIDE_W = 980, 600, 240
local ROW_H, PAD, CAT_W = 66, 16, 96
local BUTTONS_W = 250 -- room on the right for Whisper / Invite / ×

local FEEDS = {
    { id = "all", label = "All" }, { id = "lfg", label = "LFG" }, { id = "trade", label = "Trade" },
    { id = "services", label = "Services" }, { id = "guilds", label = "Guilds" }, { id = "other", label = "Other" },
}
local CAT_LABEL = { lfg = "LFG", trade = "TRADE", services = "SERVICES", guilds = "GUILDS", other = "OTHER", spam = "SPAM" }
local WINDOWS = { 5, 15, 30, 60 }
local ROLES = { "none", "tank", "healer", "dps" }
local ROLE_LABEL = { none = "My role: none", tank = "My role: Tank", healer = "My role: Healer", dps = "My role: DPS" }

local frame, listArea, scrollbar, rowPool
local feedButtons = {}
local state = { cat = "all", search = "", offset = 0, paused = false, pausedNew = 0 }
local items = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function classColor(class)
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local c = class and colors and colors[class]
    if c then return c.r, c.g, c.b end
    return Theme:Color("text")
end

local function age(t)
    local s = time() - t
    if s < 60 then return "now" end
    return floor(s / 60) .. "m"
end

local function matchesSearch(p, q)
    if q == "" then return true end
    return p.plain:find(q, 1, true) or strlower(p.author):find(q, 1, true) or strlower(p.channel):find(q, 1, true)
end

-- ---------------------------------------------------------------------------
-- Rows
-- ---------------------------------------------------------------------------

local function enableLinks(f)
    f:SetHyperlinksEnabled(true)
    f:SetScript("OnHyperlinkClick", function(_, link, text, button) SetItemRef(link, text, button, DEFAULT_CHAT_FRAME) end)
    f:SetScript("OnHyperlinkEnter", function(self, link)
        if link:match("^item:") or link:match("^spell:") or link:match("^enchant:") then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            if pcall(GameTooltip.SetHyperlink, GameTooltip, link) then GameTooltip:Show() else GameTooltip:Hide() end
        end
    end)
    f:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
end

local function tag(parent, bgKey)
    local t = CreateFrame("Frame", nil, parent)
    t:SetHeight(18)
    t.bg = t:CreateTexture(nil, "BACKGROUND")
    t.bg:SetAllPoints()
    t.text = W.Text(t, "semibold", -2, "text")
    t.text:SetPoint("CENTER")
    if bgKey == "accent" then
        W.OnAccent(function(r, g, b) t.bg:SetColorTexture(r, g, b, 1) end)
        t.text:SetTextColor(Theme:Color("sidebar"))
    else
        t.bg:SetColorTexture(0, 0, 0, 0)
        t.border = W.Border(t, "line")
        t.text:SetTextColor(Theme:Color("textDim"))
    end
    function t:SetLabel(s)
        self.text:SetText(s)
        self:SetWidth(self.text:GetStringWidth() + 12)
    end
    return t
end

local function createRow()
    local r = CreateFrame("Frame", nil, listArea)
    r:SetHeight(ROW_H)
    r:EnableMouse(true)
    enableLinks(r)
    -- Matches of a watch: accent bar and a faint accent tint.
    r.watchTint = r:CreateTexture(nil, "BACKGROUND")
    r.watchTint:SetAllPoints()
    r.watchBar = r:CreateTexture(nil, "ARTWORK")
    r.watchBar:SetPoint("TOPLEFT")
    r.watchBar:SetPoint("BOTTOMLEFT")
    r.watchBar:SetWidth(3)
    W.OnAccent(function(cr, cg, cb)
        r.watchTint:SetColorTexture(cr, cg, cb, 0.07)
        r.watchBar:SetColorTexture(cr, cg, cb, 1)
    end)
    r.hover = W.Fill(r, "selected", 0.6)
    r.hover:SetAllPoints()
    r.hover:Hide()
    W.Line(r, "bottom", "line")
    r:SetScript("OnEnter", function(self) self.hover:Show() end)
    r:SetScript("OnLeave", function(self) if not self:IsMouseOver() then self.hover:Hide() end end)

    r.cat = W.Text(r, "heading", -1, "textFaint")
    r.cat:SetPoint("TOPLEFT", PAD, -14)

    -- Name (right-click: mute).
    r.nameBtn = CreateFrame("Button", nil, r)
    r.nameBtn:SetPoint("TOPLEFT", PAD + CAT_W, -10)
    r.nameBtn:SetHeight(20)
    r.nameBtn:RegisterForClicks("RightButtonUp")
    r.name = W.Text(r.nameBtn, "semibold", 2)
    r.name:SetPoint("LEFT")
    r.nameBtn:SetScript("OnClick", function()
        local p = r.post
        if not p then return end
        W.OpenMenu({
            { text = "Whisper " .. p.author, onClick = function() Hush.OpenWhisper(p.author) end },
            { text = "Mute " .. p.author .. " (this session)", danger = true, onClick = function()
                F.Mute(p.author)
                UI.Refresh()
            end },
        })
    end)

    r.meta = W.Text(r, "regular", -1, "textFaint")
    r.meta:SetPoint("LEFT", r.nameBtn, "RIGHT", 8, 0)
    r.count = tag(r, "plain")
    r.count:SetPoint("LEFT", r.meta, "RIGHT", 8, 0)
    r.need = tag(r, "accent")
    r.need:SetLabel("Needs your role")

    r.text = W.Text(r, "regular", 1, "text")
    r.text:SetPoint("TOPLEFT", r.nameBtn, "BOTTOMLEFT", 0, -6)
    r.text:SetWordWrap(true)
    if r.text.SetMaxLines then r.text:SetMaxLines(2) end
    r.text:SetJustifyV("TOP")

    -- Buttons, right to left: ×, Invite, Whisper.
    r.close = W.IconButton(r, "close", 26, "Hide this post", function()
        if r.post then F.Hide(r.post) UI.Refresh() end
    end, "x")
    r.close:SetPoint("TOPRIGHT", -PAD, -12)
    r.invite = W.Button(r, "Invite", "default", function()
        if r.post then Hush.InviteToGroup(r.post.author) end
    end)
    r.invite:SetHeight(28)
    r.whisper = W.Button(r, "Whisper", "default", function()
        if r.post then Hush.OpenWhisper(r.post.author) end
    end)
    r.whisper:SetHeight(28)
    return r
end

local function fillRow(r, p)
    r.post = p
    r.cat:SetText(CAT_LABEL[p.cat] or "")
    r.name:SetText(p.author)
    r.name:SetTextColor(classColor(p.class))
    r.nameBtn:SetWidth(r.name:GetStringWidth() + 2)
    r.meta:SetText(p.channel .. " · " .. age(p.last))
    r.count:SetShown(p.count > 1)
    if p.count > 1 then r.count:SetLabel("x" .. p.count) end
    r.need:ClearAllPoints()
    r.need:SetPoint("LEFT", p.count > 1 and r.count or r.meta, "RIGHT", 8, 0)
    r.need:SetShown(p.needsRole == true)

    r.text:SetWidth(max(120, listArea:GetWidth() - PAD * 2 - CAT_W - BUTTONS_W))
    r.text:SetText(p.text)

    -- Invite for players looking for a group and for services (portals, summons...).
    local canInvite = p.cat == "services" or (p.cat == "lfg" and p.info and p.info.lfType == "lfg")
    r.invite:SetShown(canInvite)
    r.invite:ClearAllPoints()
    r.invite:SetPoint("RIGHT", r.close, "LEFT", -8, 0)
    r.whisper:ClearAllPoints()
    r.whisper:SetPoint("RIGHT", canInvite and r.invite or r.close, "LEFT", -8, 0)

    -- Older posts fade out before they expire.
    local window = (F.db.window or 15) * 60
    r:SetAlpha((time() - p.last) > window * 0.66 and 0.45 or 1)
    r.watchTint:SetShown(p.watched == true)
    r.watchBar:SetShown(p.watched == true)
end

-- ---------------------------------------------------------------------------
-- List
-- ---------------------------------------------------------------------------

local function contentH() return #items * ROW_H end
local function maxOffset() return max(0, contentH() - listArea:GetHeight()) end

local function render()
    rowPool:ReleaseAll()
    local viewH = listArea:GetHeight()
    local first = floor(state.offset / ROW_H) + 1
    for i = first, #items do
        local top = (i - 1) * ROW_H - state.offset
        if top >= viewH then break end
        local r = rowPool:Acquire()
        fillRow(r, items[i])
        r:SetPoint("TOPLEFT", listArea, "TOPLEFT", 0, -top)
        r:SetPoint("TOPRIGHT", listArea, "TOPRIGHT", 0, -top)
    end
    scrollbar:Update(state.offset, contentH(), viewH)
end

function UI.SetOffset(v)
    state.offset = min(max(0, v), maxOffset())
    render()
end

-- Watches in the sidebar: click shows the matches (and clears the badge), right-click edits.
local watchRows = {}
local MAX_WATCH_ROWS = 5

local function watchRow(i)
    local b = watchRows[i]
    if b then return b end
    b = CreateFrame("Button", nil, frame.side)
    b:SetHeight(28)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.sel = W.Fill(b, "selected", 1)
    b.sel:SetAllPoints()
    b.label = W.Text(b, "semibold", 0, "textDim")
    b.label:SetPoint("LEFT", PAD, 0)
    b.label:SetWidth(SIDE_W - PAD * 2 - 44)
    b.badge = W.Badge(b)
    b.badge:SetPoint("RIGHT", -PAD, 0)
    b:SetScript("OnClick", function(self, button)
        local w = F.WatchById(self.watchId)
        if not w then return end
        if button == "RightButton" then
            W.OpenMenu({
                { text = "Edit", onClick = function() F.EditWatch(w) end },
                { text = w.paused and "Resume" or "Pause", onClick = function()
                    w.paused = not w.paused
                    F.RecheckWatches()
                    UI.Refresh()
                end },
                { separator = true },
                { text = "Delete", danger = true, onClick = function()
                    F.DeleteWatch(w.id)
                    if state.watch == w.id then state.watch = nil end
                    F.RecheckWatches()
                    UI.Refresh()
                end },
            })
        else
            state.watch = w.id
            state.offset = 0
            UI.Refresh()
        end
    end)
    watchRows[i] = b
    return b
end

local function layoutWatches()
    local y = frame.watchTop
    local list = F.db.watches
    for i = 1, max(#list, #watchRows) do
        local w = list[i]
        if w and i <= MAX_WATCH_ROWS then
            local b = watchRow(i)
            b.watchId = w.id
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", frame.side, "TOPLEFT", 0, y)
            b:SetPoint("TOPRIGHT", frame.side, "TOPRIGHT", 0, y)
            b.label:SetText(w.name .. (w.paused and " |cff7c858f(paused)|r" or ""))
            local active = state.watch == w.id
            b.sel:SetShown(active)
            b.label:SetTextColor(Theme:Color(active and "text" or "textDim"))
            b.badge:SetCount(F.hits[w.id] or 0)
            b:Show()
            y = y - 28
        elseif watchRows[i] then
            watchRows[i]:Hide()
        end
    end
    frame.newWatch:ClearAllPoints()
    frame.newWatch:SetPoint("TOPLEFT", frame.side, "TOPLEFT", PAD - 8, y - 4)
end

local function updateSidebar()
    local counts = F.Counts()
    -- Viewing a watch counts as seeing its matches.
    if state.watch then F.hits[state.watch] = 0 end
    layoutWatches()
    for _, b in ipairs(feedButtons) do
        local active = not state.watch and b.id == state.cat
        b.sel:SetShown(active)
        b.label:SetTextColor(Theme:Color(active and "text" or "textDim"))
        b.count:SetText(counts[b.id] or 0)
    end
    local names = {}
    for name, on in pairs(F.db.channels) do if on then names[#names + 1] = name end end
    sort(names)
    for _, n in ipairs(F.db.customChannels) do names[#names + 1] = n end
    frame.channels:SetText(table.concat(names, " · "))
    frame.footer:SetText(("%d posts · duplicates merged%s"):format(#items,
        counts.spam > 0 and (" · " .. counts.spam .. " spam filtered") or ""))
end

function UI.Refresh()
    if not frame or not frame:IsShown() then return end
    local q = strlower(strtrim(state.search))
    wipe(items)
    -- A selected watch shows its matches from all categories.
    for _, p in ipairs(F.Posts(state.watch and "all" or state.cat)) do
        local inWatch = not state.watch or (p.watchIds and p.watchIds[state.watch])
        if inWatch and matchesSearch(p, q) then items[#items + 1] = p end
    end
    state.offset = min(state.offset, maxOffset())
    updateSidebar()
    render()
end

-- New posts arrive often in busy channels: refresh at most twice a second.
local pending = false
local function queueRefresh()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        UI.Refresh()
    end)
end

-- ---------------------------------------------------------------------------
-- Top bar
-- ---------------------------------------------------------------------------

local function updateTopBar()
    local role = F.db.role or "none"
    frame.roleBtn.text:SetText(ROLE_LABEL[role])
    frame.roleBtn:SetWidth(frame.roleBtn.text:GetStringWidth() + 28)
    if frame.roleBtn.bg then
        if role ~= "none" then
            frame.roleBtn.bg:SetColorTexture(Theme:Accent())
            frame.roleBtn.text:SetTextColor(Theme:Color("sidebar"))
        else
            frame.roleBtn.bg:SetColorTexture(Theme:Color("field"))
            frame.roleBtn.text:SetTextColor(Theme:Color("text"))
        end
    end
    frame.windowBtn.text:SetText("Last " .. (F.db.window or 15) .. " min")
    frame.windowBtn:SetWidth(frame.windowBtn.text:GetStringWidth() + 28)
    frame.pauseBtn.text:SetText(state.paused and ("Resume" .. (state.pausedNew > 0 and (" · " .. state.pausedNew .. " new") or "")) or "Pause")
    frame.pauseBtn:SetWidth(frame.pauseBtn.text:GetStringWidth() + 28)
end

local function nextIn(list, value)
    for i, v in ipairs(list) do
        if v == value then return list[i % #list + 1] end
    end
    return list[1]
end

-- ---------------------------------------------------------------------------
-- Build
-- ---------------------------------------------------------------------------

local function header(parent, text, y)
    local fs = W.Text(parent, "heading", -1, "textFaint")
    fs:SetPoint("TOPLEFT", PAD, y)
    fs:SetText(text)
    return fs
end

local function build()
    -- Named only so ESC closes it (UISpecialFrames).
    frame = CreateFrame("Frame", "HushFeedFrame", UIParent)
    tinsert(UISpecialFrames, "HushFeedFrame")
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    W.SetResizeBounds(frame, 760, 420, 2000, 1400)
    frame.bg = W.Fill(frame, "window", 0.98)
    frame.bg:SetAllPoints()

    local d = F.db.feedWindow
    frame:SetSize(d.w or WIDTH, d.h or HEIGHT)
    if d.left and d.top then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", d.left, d.top)
    else
        frame:SetPoint("CENTER", 0, 20)
    end
    local function save()
        d.left, d.top = Theme:Snap(frame:GetLeft(), frame), Theme:Snap(frame:GetTop(), frame)
        d.w, d.h = Theme:Snap(frame:GetWidth(), frame), Theme:Snap(frame:GetHeight(), frame)
    end

    -- Sidebar
    local side = CreateFrame("Frame", nil, frame)
    side:SetPoint("TOPLEFT")
    side:SetPoint("BOTTOMLEFT")
    side:SetWidth(SIDE_W)
    side.bg = W.Fill(side, "sidebar", 1)
    side.bg:SetAllPoints()
    W.Line(side, "right", "line")

    local title = CreateFrame("Frame", nil, side)
    title:SetPoint("TOPLEFT")
    title:SetPoint("TOPRIGHT")
    title:SetHeight(56)
    title:EnableMouse(true)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function() frame:StartMoving() end)
    title:SetScript("OnDragStop", function() frame:StopMovingOrSizing() save() end)
    W.Line(title, "bottom", "line")
    local square = title:CreateTexture(nil, "ARTWORK")
    square:SetSize(10, 10)
    square:SetPoint("LEFT", PAD, 0)
    W.OnAccent(function(r, g, b) square:SetColorTexture(r, g, b, 1) end)
    local name = W.Text(title, "heading", 5, "text")
    name:SetPoint("LEFT", square, "RIGHT", 10, 0)
    name:SetText("HUSH |cff9aa3adFEED|r")
    frame.titleText = name

    header(side, "FEEDS", -74)
    for i, def in ipairs(FEEDS) do
        local b = CreateFrame("Button", nil, side)
        b.id = def.id
        b:SetPoint("TOPLEFT", 0, -92 - (i - 1) * 34)
        b:SetPoint("TOPRIGHT", 0, -92 - (i - 1) * 34)
        b:SetHeight(34)
        b.sel = W.Fill(b, "selected", 1)
        b.sel:SetAllPoints()
        b.label = W.Text(b, "semibold", 1, "textDim")
        b.label:SetPoint("LEFT", PAD, 0)
        b.label:SetText(def.label)
        b.count = W.Text(b, "regular", -1, "textFaint")
        b.count:SetPoint("RIGHT", -PAD, 0)
        b:SetScript("OnClick", function(self)
            state.cat = self.id
            state.watch = nil
            state.offset = 0
            UI.Refresh()
        end)
        feedButtons[i] = b
    end

    local watchY = -92 - #FEEDS * 34 - 22
    header(side, "WATCHES", watchY)
    frame.watchTop = watchY - 18
    frame.side = side
    frame.newWatch = W.Button(side, "+  New watch", "ghost", function() F.EditWatch(nil) end)

    local chHeader = W.Text(side, "heading", -1, "textFaint")
    chHeader:SetPoint("BOTTOMLEFT", PAD, 62)
    chHeader:SetText("CHANNELS")
    frame.channels = W.Text(side, "regular", -1, "textDim")
    frame.channels:SetPoint("TOPLEFT", chHeader, "BOTTOMLEFT", 0, -8)
    frame.channels:SetWidth(SIDE_W - PAD * 2)
    frame.channels:SetWordWrap(true)

    -- Content
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", side, "TOPRIGHT")
    content:SetPoint("BOTTOMRIGHT")

    local close = W.IconButton(content, "close", 24, "Close", function() frame:Hide() end, "x")
    close:SetPoint("TOPRIGHT", -8, -8)

    local search = W.EditBox(content, "Search posts, items, players", 32)
    search:SetPoint("TOPLEFT", PAD, -40)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:HookScript("OnTextChanged", function(self)
        state.search = self:GetText() or ""
        state.offset = 0
        UI.Refresh()
    end)

    frame.pauseBtn = W.Button(content, "Pause", "default", function()
        state.paused = not state.paused
        state.pausedNew = 0
        updateTopBar()
        if not state.paused then UI.Refresh() end
    end)
    frame.pauseBtn:SetHeight(32)
    frame.pauseBtn:SetPoint("TOPRIGHT", -PAD, -40)

    frame.windowBtn = W.Button(content, "Last 15 min", "default", function()
        F.db.window = nextIn(WINDOWS, F.db.window)
        updateTopBar()
        UI.Refresh()
    end)
    frame.windowBtn:SetHeight(32)
    frame.windowBtn:SetPoint("RIGHT", frame.pauseBtn, "LEFT", -8, 0)

    frame.roleBtn = W.Button(content, "My role", "default", function()
        F.db.role = nextIn(ROLES, F.db.role)
        F.RefreshRoles()
        updateTopBar()
        UI.Refresh()
    end)
    frame.roleBtn:SetHeight(32)
    frame.roleBtn:SetPoint("RIGHT", frame.windowBtn, "LEFT", -8, 0)
    frame.roleBtn:HookScript("OnLeave", function() updateTopBar() end)
    search:SetPoint("RIGHT", frame.roleBtn, "LEFT", -8, 0)

    -- Footer
    local foot = CreateFrame("Frame", nil, content)
    foot:SetPoint("BOTTOMLEFT")
    foot:SetPoint("BOTTOMRIGHT")
    foot:SetHeight(40)
    W.Line(foot, "top", "line")
    frame.footer = W.Text(foot, "regular", -1, "textFaint")
    frame.footer:SetPoint("LEFT", PAD, 0)
    local hint = W.Text(foot, "regular", -1, "textFaint")
    hint:SetPoint("RIGHT", -PAD - 16, 0)
    hint:SetText("Older posts fade out and expire")

    -- List
    listArea = CreateFrame("Frame", nil, content)
    listArea:SetPoint("TOPLEFT", 0, -84)
    listArea:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT")
    listArea:SetClipsChildren(true)
    W.Line(listArea, "top", "line")
    listArea:EnableMouseWheel(true)
    listArea:SetScript("OnMouseWheel", function(_, delta) UI.SetOffset(state.offset - delta * ROW_H) end)
    listArea:SetScript("OnSizeChanged", function() if frame:IsShown() then UI.Refresh() end end)
    rowPool = W.Pool(createRow, function(r) r.post = nil; r.hover:Hide(); r:SetAlpha(1) end)
    scrollbar = W.Scrollbar(listArea, UI.SetOffset)

    -- Resize grip
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(frame:GetFrameLevel() + 20)
    grip.icon = W.Icon(grip, "grip", 12, "/")
    grip.icon:SetColor(Theme:Color("textFaint"))
    grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() save() end)

    frame.border = W.Border(frame, "line")
    for _, s in ipairs({ "top", "bottom", "left", "right" }) do frame.border[s]:SetDrawLayer("OVERLAY", 7) end
    if W.SkinPanel then
        W.SkinPanel(frame, { kind = "dialog", hide = { frame.bg, side.bg }, borders = { frame.border }, title = name })
    end

    -- While open: refresh on new posts and every 20 s (ages, fading, expiry).
    local token = 0
    local function tick(t)
        if t ~= token or not frame:IsShown() then return end
        if not state.paused then UI.Refresh() end
        C_Timer.After(20, function() tick(t) end)
    end
    frame:SetScript("OnShow", function()
        token = token + 1
        updateTopBar()
        UI.Refresh()
        local t = token
        C_Timer.After(20, function() tick(t) end)
    end)
    frame:SetScript("OnHide", function() token = token + 1; W.CloseMenus() end)
    frame:Hide()
end

-- Every new post: refresh (throttled) or count it while paused.
function F.OnPost()
    if not frame or not frame:IsShown() then return end
    if state.paused then
        state.pausedNew = state.pausedNew + 1
        updateTopBar()
        return
    end
    queueRefresh()
end

function UI.Toggle()
    if not F.db then return end
    if not frame then build() end
    frame:SetShown(not frame:IsShown())
end

-- Entry points in Hush: a title-row button and the launcher menu.
Hush.AddTitleButton({ icon = "list", glyph = "F", tooltip = "Hush Feed", onClick = function() UI.Toggle() end })
Hush.AddLauncherMenuItems(function() return { text = "Hush Feed", onClick = function() UI.Toggle() end } end)
