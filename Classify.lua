-- Classify: sorts a channel message into lfg / trade / services / guilds / other, tells
-- LFM (a group looking for players) from LFG (a player looking for a group), and which
-- roles an LFM asks for. Whole words only ("wts" does not match inside another word).
local _, F = ...

-- Strong words are clear ads (weight 1, services 1.5 so "WTS summons" is a service);
-- weak words are common in normal talk (weight 0.5): one weak word alone is not enough.
local WORDS = {
    trade = {
        strong = { "wts", "wtb", "wtt", "for sale", "pst", "cod" },
        weak = { "selling", "buying", "sell", "buy", "price", "cheap" },
    },
    lfg = {
        strong = { "lfg", "lfm", "lf1m", "lf2m", "lf3m", "lf4m", "lf", "need tank", "need heal", "need healer",
                   "need heals", "need dps", "looking for group", "group for" },
        weak = { "run", "runs", "tank", "healer", "dps", "anyone doing", "anyone up for" },
    },
    services = {
        strong = { "portal", "portals", "port", "ports", "summon", "summons", "summoning", "summ", "summs", "sums",
                   "service", "services", "taxi",
                   "enchant", "enchants", "enchanting", "can craft", "lockpick", "lockpicking", "boost", "boosting" },
        weak = { "crafting", "craft", "tips" },
    },
    guilds = {
        strong = { "recruit", "recruits", "recruiting", "raid team", "semi-hardcore", "progression" },
        weak = { "guild", "raiding", "apply", "hardcore", "casual" },
    },
}
local WEIGHT = { trade = 1, lfg = 1, services = 1.5, guilds = 1 }

-- Dungeons and raids: a hint for LFG.
local INSTANCES = {
    "rfc", "wc", "dm", "deadmines", "sfk", "bfd", "stocks", "gnomer", "rfk", "sm", "gy", "lib", "arm", "cath",
    "rfd", "ulda", "uldaman", "zf", "mara", "st", "sunken", "brd", "lbrs", "ubrs", "dire maul", "dm n", "dm e",
    "dm w", "strat", "strath", "stratholme", "scholo", "scholomance", "ud", "live", "zg", "mc", "ony", "onyxia",
    "bwl", "aq20", "aq40", "naxx",
}

-- The channel's own topic counts a little.
local CHANNEL_HINT = { lookingforgroup = "lfg", services = "services", trade = "trade", tradelocal = "trade" }

local ROLE_WORDS = {
    tank = { "tank", "tanks", "mt", "ot" },
    healer = { "heal", "heals", "healer", "healers", "healz" },
    dps = { "dps", "dd", "damage" },
}

-- Whole word or phrase, case-insensitive (text is already lowercase).
local cache = {}
local function has(text, word)
    local pat = cache[word]
    if not pat then
        pat = "%f[%w]" .. word:gsub("([%-%.%+%*%?%[%]%^%$%(%)%%])", "%%%1") .. "%f[%W]"
        cache[word] = pat
    end
    return text:find(pat) ~= nil
end

local function score(text, list)
    local n = 0
    for _, w in ipairs(list) do
        if has(text, w) then n = n + 1 end
    end
    return n
end

-- Position of the first whole-word match of any of the words, or nil.
local function firstPos(text, words)
    local best
    for _, w in ipairs(words) do
        has(text, w) -- builds the cached pattern
        local s = text:find(cache[w])
        if s and (not best or s < best) then best = s end
    end
    return best
end

local ALL_ROLE_WORDS = {}
for _, words in pairs(ROLE_WORDS) do
    for _, w in ipairs(words) do ALL_ROLE_WORDS[#ALL_ROLE_WORDS + 1] = w end
end

-- "-1dps", "- 1 tank", "-heal": a group missing that role.
local function dashRole(text)
    for _, w in ipairs(ALL_ROLE_WORDS) do
        if text:find("%-%s*%d*%s*" .. w .. "%f[%W]") then return true end
    end
    return false
end

-- Gold sellers: block graphics, web addresses, or Cyrillic look-alike letters mixed into
-- Latin words (a classic trick to get past filters).
local SPAM_MARKS = { "█", "▓", "►", "◄", "■", "▲", "▼", "▶", "◀" }
local function isSpam(text, plain)
    local marks = 0
    for _, m in ipairs(SPAM_MARKS) do
        marks = marks + select(2, text:gsub(m, ""))
    end
    if marks >= 2 then return true end
    if plain:find("%w%w+%.com%f[%W]") or plain:find("%w%w+%.net%f[%W]") or plain:find("www%.") then return true end
    -- UTF-8 Cyrillic (lead bytes 0xD0/0xD1) directly next to a Latin letter.
    if plain:find("[a-z][\208\209]") or plain:find("[\208\209][\128-\191][a-z]") then return true end
    return false
end

-- Plain lowercase text: links become their names (as separate words), colors are removed.
function F.Plain(text)
    return strlower((text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h%[?(.-)%]?|h", " %1 "))
end

-- Guild recruitment in Russian/Ukrainian (stems, matched inside words: word boundaries do
-- not work for Cyrillic bytes). Lowercase only, as usually typed.
local CYRILLIC_GUILD = { "гільді", "гильди", "набір", "набор", "рейд", "спільнот", "сообществ", "комьюніт", "коммьюнит" }

local function cyrillicGuild(plain)
    for _, stem in ipairs(CYRILLIC_GUILD) do
        if plain:find(stem, 1, true) then return true end
    end
    return false
end

-- Returns cat, info = { lfType = "lfm"/"lfg"/nil, roles = { tank = true, ... }, items = n }.
function F.Classify(text, channel)
    local plain = F.Plain(text)
    local extra = F.db and F.db.keywords or {}
    local items = select(2, (text or ""):gsub("|Hitem:", ""))
    if isSpam(text or "", plain) then return "spam", { items = items }, plain end
    local profs = select(2, (text or ""):gsub("|Htrade:", ""))
    local s = {}
    for cat, words in pairs(WORDS) do
        s[cat] = (score(plain, words.strong) + score(plain, extra[cat] or {})) * WEIGHT[cat] + score(plain, words.weak) * 0.5
    end
    s.lfg = s.lfg + (score(plain, INSTANCES) > 0 and 0.5 or 0) -- short names ("live", "st") are also normal words
    -- An item link alone is only a hint (people link items in normal talk too).
    if items > 0 and s.lfg == 0 then s.trade = s.trade + 0.5 end
    -- A profession link ([Tailoring]) is a crafting service.
    if profs > 0 then s.services = s.services + 1.5 end
    -- "need" or "lf" plus a role asks for players, even as "need - TANK -".
    if dashRole(plain) then s.lfg = s.lfg + 1 end
    if has(plain, "need") or has(plain, "lf") then
        for _, words in pairs(ROLE_WORDS) do
            if score(plain, words) > 0 then s.lfg = s.lfg + 1 break end
        end
    end
    local hint = CHANNEL_HINT[strlower(channel or "")]
    if hint then s[hint] = s[hint] + 0.5 end
    -- <Guild Name> in a post is a strong guild hint.
    if plain:find("<[^>]+>") then s.guilds = s.guilds + 1 end
    if cyrillicGuild(plain) then s.guilds = s.guilds + 1 end

    -- At least one real keyword is needed: the channel alone never decides.
    local cat, best = "other", 0.99
    -- On a tie, the more specific kind wins ("WTS summons" in Trade is a service).
    for _, c in ipairs({ "services", "lfg", "trade", "guilds" }) do
        if s[c] > best then cat, best = c, s[c] end
    end

    local info = { items = items }
    if cat == "lfg" then
        -- A group looking for players: "LFM", "LF1M", "need", "-1 dps", or a role AFTER "LF"
        -- ("LF TANK RFC"). A role BEFORE "LF" is a player looking for a group ("DPS LF RFC").
        local lfPos, rolePos = firstPos(plain, { "lf" }), firstPos(plain, ALL_ROLE_WORDS)
        if has(plain, "lfm") or plain:find("%f[%w]lf%dm%f[%W]") or has(plain, "need") or dashRole(plain)
            or (lfPos and rolePos and rolePos > lfPos) then
            info.lfType = "lfm"
            info.roles = {}
            for role, words in pairs(ROLE_WORDS) do
                if score(plain, words) > 0 then info.roles[role] = true end
                for _, w in ipairs(words) do
                    if plain:find("%-%s*%d*%s*" .. w .. "%f[%W]") then info.roles[role] = true end
                end
            end
        elseif has(plain, "lfg") or has(plain, "looking for group") or lfPos then
            info.lfType = "lfg"
        end
    end
    return cat, info, plain
end
