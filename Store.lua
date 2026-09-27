-- Store: the feed in memory (never saved). Repeated posts from the same player are merged
-- ("x5"); old posts expire after the longest time window; at most maxPosts are kept.
local _, F = ...

local posts = {}      -- newest activity first
local byKey = {}
local nextId = 0
local MAX_AGE = 60 * 60 -- the longest window (60 min)

F.CATEGORIES = { "lfg", "trade", "services", "guilds", "other" } -- "spam" is kept apart

-- Same player + same text (links as names, spacing and case ignored) = the same post.
local function keyFor(author, plain)
    return author .. "|" .. plain:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
end

local function prune()
    local now = time()
    local limit = F.db and F.db.maxPosts or 500
    for i = #posts, 1, -1 do
        local p = posts[i]
        if now - p.last > MAX_AGE or i > limit then
            byKey[p.key] = nil
            tremove(posts, i)
        end
    end
end

local function moveToFront(p)
    for i, q in ipairs(posts) do
        if q == p then
            tremove(posts, i)
            break
        end
    end
    tinsert(posts, 1, p)
end

-- Does an LFM ask for my role?
local function needsMyRole(info)
    local role = F.db and F.db.role or "none"
    return role ~= "none" and info.lfType == "lfm" and info.roles and info.roles[role] == true
end

function F.AddPost(author, channel, text, guid)
    local cat, info, plain = F.Classify(text, channel)
    local key = keyFor(author, plain)
    local now = time()
    local p = byKey[key]
    if p then
        p.count = p.count + 1
        p.last = now
        p.text = text
        p.hidden = nil -- posted again: show it again
        moveToFront(p)
    else
        nextId = nextId + 1
        local class
        if guid and guid ~= "" and GetPlayerInfoByGUID then
            local ok, _, classFile = pcall(GetPlayerInfoByGUID, guid)
            if ok then class = classFile end
        end
        p = {
            id = nextId, key = key, author = author, class = class, channel = channel,
            text = text, plain = plain, cat = cat, info = info,
            first = now, last = now, count = 1,
        }
        byKey[key] = p
        tinsert(posts, 1, p)
    end
    p.needsRole = needsMyRole(p.info)
    if F.CheckWatches then F.CheckWatches(p, p.count == 1) end
    prune()
    if F.OnPost then F.OnPost(p) end
    for _, fn in ipairs(F.listeners) do
        local ok, err = pcall(fn, p)
        if not ok then geterrorhandler()(err) end
    end
    return p
end

-- Posts inside the time window, newest first. cat = nil for all.
function F.Posts(cat, windowMinutes)
    local cutoff = time() - (windowMinutes or F.db.window or 15) * 60
    local list = {}
    for _, p in ipairs(posts) do
        -- Spam only shows when asked for explicitly.
        local match = (cat == p.cat) or ((not cat or cat == "all") and p.cat ~= "spam")
        if p.last >= cutoff and not p.hidden and match and not F.muted[p.author] then
            list[#list + 1] = p
        end
    end
    return list
end

function F.Counts(windowMinutes)
    local counts = { all = 0, lfg = 0, trade = 0, services = 0, guilds = 0, other = 0 }
    for _, p in ipairs(F.Posts(nil, windowMinutes)) do
        counts.all = counts.all + 1
        counts[p.cat] = counts[p.cat] + 1
    end
    counts.spam = #F.Posts("spam", windowMinutes)
    return counts
end

function F.Hide(p) p.hidden = true end

-- Muted players (this session): their posts are left out of the feed.
F.muted = {}
function F.Mute(author) F.muted[author] = true end
function F.Unmute(author) F.muted[author] = nil end

function F.Clear()
    wipe(posts)
    wipe(byKey)
end

-- Re-check "needs your role" after the role changes.
function F.RefreshRoles()
    for _, p in ipairs(posts) do p.needsRole = needsMyRole(p.info) end
end

-- Sample posts for testing without busy channels (/feed test).
function F.InjectSamples()
    local samples = {
        { "Kodoklant", "LookingForGroup", "LF1M healer for UBRS, rest ready at the instance" },
        { "Vinterfluga", "Services", "Portals to IF / SW / Darnassus, tips welcome" },
        { "Zarkov", "Trade", "WTS |cff1eff00|Hitem:12360::::::::60:::::::|h[Arcanite Bar]|h|r 8g each, can also transmute your mats" },
        { "Ashveil", "Services", "Summons anywhere, 5g. Whisper me" },
        { "Grimstrand", "LookingForGroup", "LFM Strat UD, need tank + heals" },
        { "Mirelle", "LookingForGroup", "LFG Scholomance, 60 mage" },
        { "Hollowmere", "Trade", "WTB [Righteous Orb] x6, paying well" },
        { "Tarn", "General", "<Iron Oath> semi-hardcore raiding, recruiting healers and hunters" },
        { "Brum", "General", "anyone know where the flight master is in Orgrimmar?" },
    }
    for _, s in ipairs(samples) do F.AddPost(s[1], s[2], s[3]) end
    -- The same ad again: merged into "x2".
    F.AddPost("Kodoklant", "LookingForGroup", "LF1M  healer for UBRS, rest ready at the instance")
end
