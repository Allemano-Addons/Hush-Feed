-- Hush_Feed: sorts and filters channel chat for Hush.
-- Core: namespace, saved settings (posts are kept in memory only), channel capture, slash.
local addonName, F = ...

F.name = addonName


function F.Print(...)
    local msg = strjoin(" ", tostringall(...))
    DEFAULT_CHAT_FRAME:AddMessage("|cff3fc7ebHush Feed|r " .. msg)
end

-- ---------------------------------------------------------------------------
-- Saved settings (account-wide). The feed itself is never saved.
-- ---------------------------------------------------------------------------

local DEFAULTS = {
    -- Channels to read, by base name (the part before " - "). LocalDefense is off.
    channels = { General = true, Trade = true, TradeLocal = true, Services = true, LookingForGroup = true, LocalDefense = false },
    customChannels = {},        -- extra channel names added by the player
    role = "none",              -- "tank" / "healer" / "dps" / "none" (chosen by the player)
    window = 15,                -- minutes shown in the feed
    maxPosts = 500,             -- kept in memory
    keywords = { trade = {}, lfg = {}, services = {}, guilds = {} }, -- extra words per category
    watches = {},
    watchSound = "bell",
    feedWindow = {},
}

local function fill(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = type(v) == "table" and CopyTable(v) or v
        elseif type(v) == "table" and type(dst[k]) == "table" then
            fill(dst[k], v)
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= addonName then return end
        if type(HushFeedDB) ~= "table" then HushFeedDB = {} end
        fill(HushFeedDB, DEFAULTS)
        F.db = HushFeedDB
        frame:UnregisterEvent("ADDON_LOADED")
        frame:RegisterEvent("CHAT_MSG_CHANNEL")
    elseif event == "CHAT_MSG_CHANNEL" then
        -- Secret text/sender (instances, boss fights on WoW Forever) can't be read: skip it.
        if issecretvalue then
            local text, sender, _, channel = ...
            if issecretvalue(text) or issecretvalue(sender) or issecretvalue(channel) then return end
        end
        -- Protected, so a problem here never breaks anything else.
        local ok, err = pcall(F.OnChannelMessage, ...)
        if not ok then geterrorhandler()(err) end
    end
end)

-- ---------------------------------------------------------------------------
-- Channels
-- ---------------------------------------------------------------------------

-- "Trade - City" -> "Trade"; "5. Services" -> "Services".
function F.ChannelBase(name)
    if not name or name == "" then return nil end
    name = name:gsub("^%d+%.%s*", "")
    return (name:match("^(.-)%s+%-%s+") or name)
end

function F.IsWatchedChannel(base)
    if not base then return false end
    local lower = strlower(base)
    for name, on in pairs(F.db.channels) do
        if on and strlower(name) == lower then return true end
    end
    for _, name in ipairs(F.db.customChannels) do
        if strlower(name) == lower then return true end
    end
    return false
end

-- CHAT_MSG_CHANNEL: text, sender, language, channelName, target, flags, zoneID,
-- channelIndex, channelBaseName, languageID, lineID, guid, ...
function F.OnChannelMessage(text, sender, _, channelName, _, _, _, _, channelBaseName, _, _, guid)
    if not F.db then return end
    local base = F.ChannelBase(channelBaseName ~= "" and channelBaseName or channelName)
    if not F.IsWatchedChannel(base) then return end
    local name = Ambiguate(sender or "", "none")
    if name == "" then return end
    F.AddPost(name, base, text or "", guid)
end

-- ---------------------------------------------------------------------------
-- Slash: /feed (/hf). The window arrives in step 2; until then, dev output.
-- ---------------------------------------------------------------------------

local function dump(cat)
    local posts = F.Posts(cat)
    F.Print(("%d post(s)%s, window %d min:"):format(#posts, cat and (" in " .. cat) or "", F.db.window))
    for i = 1, math.min(#posts, 15) do
        local p = posts[i]
        local tag = p.needsRole and " |cff3fc7eb[needs your role]|r" or ""
        F.Print(("  [%s] %s (%s)%s%s: %s"):format(p.cat, p.author, p.channel,
            p.count > 1 and (" x" .. p.count) or "", tag, p.text))
    end
end

SLASH_HUSHFEED1 = "/feed"
SLASH_HUSHFEED2 = "/hf"
SlashCmdList.HUSHFEED = function(msg)
    local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
    cmd = strlower(cmd or "")
    if cmd == "" then
        F.UI.Toggle()
    elseif cmd == "dump" then
        dump(rest ~= "" and strlower(rest) or nil)
    elseif cmd == "stats" then
        local counts = F.Counts()
        F.Print(("all %d · lfg %d · trade %d · services %d · guilds %d · other %d · spam filtered %d"):format(
            counts.all, counts.lfg, counts.trade, counts.services, counts.guilds, counts.other, counts.spam))
    elseif cmd == "role" then
        local r = strlower(rest)
        if r == "tank" or r == "healer" or r == "dps" or r == "none" then
            F.db.role = r
            F.RefreshRoles()
            F.UI.Refresh()
            F.Print("Role:", r)
        else
            F.Print("Usage: /feed role tank|healer|dps|none")
        end
    elseif cmd == "sound" then
        local known = false
        for _, s in ipairs(F.SOUNDS) do if s.id == strlower(rest) then known = true end end
        if known then
            F.db.watchSound = strlower(rest)
            F.PlaySound(F.db.watchSound)
            F.Print("Watch sound:", F.db.watchSound)
        else
            F.Print("Sounds: bell, ping, raid, whisper, click")
        end
    elseif cmd == "test" then
        F.InjectSamples()
        F.Print("Added sample posts. Try /feed dump or /feed stats.")
    elseif cmd == "clear" then
        F.Clear()
        F.Print("Feed cleared.")
    elseif cmd == "options" or cmd == "settings" then
        Hush.OpenSettings("feed")
    else
        F.Print("/feed - open the window, /feed options, /feed dump [lfg|trade|services|guilds|other|spam], /feed stats, /feed role <role>, /feed test, /feed clear")
    end
end

-- ---------------------------------------------------------------------------
-- Public API for other Hush modules (Hush_LFG): Hush.Feed
-- ---------------------------------------------------------------------------

local Hush = Hush
F.listeners = {}
Hush.Feed = {
    apiVersion = 1,
    -- Posts inside the time window, newest first (cat = nil for all).
    Posts = function(cat, windowMinutes) return F.Posts(cat, windowMinutes) end,
    GetRole = function() return F.db and F.db.role or "none" end,
    SetRole = function(role)
        F.db.role = role
        F.RefreshRoles()
        if F.UI then F.UI.Refresh() end
    end,
    -- fn(post) runs for every new or repeated post.
    OnPost = function(fn) tinsert(F.listeners, fn) end,
}
