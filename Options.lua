-- Options: two pages in the Hush settings – "Feed" (role, time window, watch sound,
-- channels incl. custom ones) and "Feed sorting" (extra keywords per category).
local _, F = ...

local Hush = Hush
local W = Hush.Widgets

local ROW = 30

local function refreshUI()
    if F.UI then F.UI.Refresh() end
end

-- Channel names to offer: defaults, channels you are in right now, and custom ones.
local function channelNames()
    local seen, list = {}, {}
    local function add(name, custom)
        name = F.ChannelBase(name)
        if name and name ~= "" and not seen[strlower(name)] then
            seen[strlower(name)] = true
            list[#list + 1] = { name = name, custom = custom }
        end
    end
    for name in pairs(F.db.channels) do add(name) end
    if GetChannelList then
        local t = { GetChannelList() }
        for i = 1, #t, 3 do
            if type(t[i + 1]) == "string" then add(t[i + 1]) end
        end
    end
    for _, name in ipairs(F.db.customChannels) do add(name, true) end
    sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function isOn(entry)
    if entry.custom then return true end
    return F.db.channels[entry.name] == true
end

Hush.AddSettingsPage({
    id = "feed",
    label = "Feed",
    build = function(page)
        page:Header("General")
        page:Segment("My role", "LFG posts that need this role are tagged.",
            { { value = "none", label = "None" }, { value = "tank", label = "Tank" },
              { value = "healer", label = "Healer" }, { value = "dps", label = "DPS" } },
            function() return F.db.role end,
            function(v) F.db.role = v; F.RefreshRoles(); refreshUI() end)
        page:Segment("Time window", nil,
            { { value = 5, label = "5 min" }, { value = 15, label = "15 min" }, { value = 30, label = "30 min" }, { value = 60, label = "60 min" } },
            function() return F.db.window end,
            function(v) F.db.window = v; refreshUI() end)
        local sounds = {}
        for _, s in ipairs(F.SOUNDS) do sounds[#sounds + 1] = { value = s.id, label = s.label } end
        page:Segment("Watch sound", "Plays when you pick it. Never in combat.", sounds,
            function() return F.db.watchSound end,
            function(v) F.db.watchSound = v; F.PlaySound(v) end)

        page:Header("Channels")
        local entries = channelNames()
        local shown = math.min(#entries, 8)
        page:Custom(shown * ROW + 34, function(c)
            local rows = {}
            for i = 1, shown do
                local e = entries[i]
                local row = CreateFrame("Frame", nil, c)
                row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
                row:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW)
                row:SetHeight(ROW - 4)
                row.toggle = W.Toggle(row, function(on)
                    if e.custom then
                        if not on then
                            for j = #F.db.customChannels, 1, -1 do
                                if strlower(F.db.customChannels[j]) == strlower(e.name) then tremove(F.db.customChannels, j) end
                            end
                        end
                    else
                        F.db.channels[e.name] = on
                    end
                    refreshUI()
                end)
                row.toggle:SetPoint("LEFT")
                row.label = W.Text(row, "semibold", 0, "text")
                row.label:SetPoint("LEFT", row.toggle, "RIGHT", 10, 0)
                row.label:SetText(e.name .. (e.custom and "  |cff7c858f(custom)|r" or ""))
                row.entry = e
                rows[i] = row
            end
            -- Add a custom channel by name.
            local add = W.EditBox(c, "Add a channel by name, e.g. WorldDefense", 28)
            add:SetPoint("TOPLEFT", 0, -shown * ROW - 2)
            add:SetWidth(280)
            add:SetMaxLetters(40)
            local addBtn = W.Button(c, "Add", "default", function()
                local name = strtrim(add:GetText() or "")
                if name == "" then return end
                if not F.IsWatchedChannel(name) then tinsert(F.db.customChannels, name) end
                add:SetText("")
                add:ClearFocus()
                refreshUI()
                F.Print("Added", name .. ". Reopen the settings to see it in the list.")
            end)
            addBtn:SetHeight(28)
            addBtn:SetPoint("LEFT", add, "RIGHT", 8, 0)
            add:SetScript("OnEnterPressed", function() addBtn:Click() end)
            return function()
                for _, row in ipairs(rows) do row.toggle:Set(isOn(row.entry)) end
            end
        end)
        if #entries > shown then
            page:Text(("%d more channels are not shown."):format(#entries - shown))
        end
    end,
})

Hush.AddSettingsPage({
    id = "feedsorting",
    label = "Feed sorting",
    build = function(page)
        page:Text("Extra words for each category, separated by spaces. They are added to the built-in "
            .. "words (whole words, e.g. a guild name or a service your server uses). Changes apply to new posts.")
        local cats = { { "lfg", "LFG" }, { "trade", "Trade" }, { "services", "Services" }, { "guilds", "Guilds" } }
        page:Custom(#cats * 60, function(c)
            local boxes = {}
            for i, def in ipairs(cats) do
                local label = W.Text(c, "semibold", 0, "text")
                label:SetPoint("TOPLEFT", 0, -(i - 1) * 60)
                label:SetText(def[2])
                local e = W.EditBox(c, "e.g. extra words", 28)
                e:SetPoint("TOPLEFT", 0, -(i - 1) * 60 - 20)
                e:SetPoint("TOPRIGHT", 0, -(i - 1) * 60 - 20)
                e:SetMaxLetters(300)
                e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
                e:HookScript("OnEditFocusLost", function(self)
                    F.db.keywords[def[1]] = F.ParseWords(self:GetText())
                end)
                boxes[def[1]] = e
            end
            return function()
                for cat, e in pairs(boxes) do e:SetText(table.concat(F.db.keywords[cat] or {}, " ")) end
            end
        end)
        page:Button("Open Hush Feed", nil, "Open", "accent", function() F.UI.Toggle() end)
    end,
})
