-- Classify: sorts a channel message into lfg / trade / services / guilds / other, tells
-- LFM (a group looking for players) from LFG (a player looking for a group), and which
-- roles an LFM asks for. Whole words only ("wts" does not match inside another word).
local _, F = ...

local WORDS = {
    trade = { "wts", "wtb", "wtt", "selling", "buying", "sell", "buy", "for sale", "price", "pst", "cod" },
    lfg = { "lfg", "lfm", "lf1m", "lf2m", "lf3m", "lf4m", "lf", "need tank", "need heal", "need healer", "need heals",
            "need dps", "looking for group", "group for", "run", "runs" },
    services = { "portal", "portals", "port", "ports", "summon", "summons", "summoning", "enchant", "enchants",
                 "enchanting", "can craft", "crafting", "craft", "tips", "lockpick", "lockpicking", "boost", "boosting" },
    guilds = { "recruit", "recruits", "recruiting", "guild", "raiding", "raid team", "apply", "semi-hardcore",
               "hardcore", "casual", "progression" },
}

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

-- Plain lowercase text: links become their names, colors are removed.
function F.Plain(text)
    return strlower((text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h%[?(.-)%]?|h", "%1"))
end

-- Returns cat, info = { lfType = "lfm"/"lfg"/nil, roles = { tank = true, ... }, items = n }.
function F.Classify(text, channel)
    local plain = F.Plain(text)
    local extra = F.db and F.db.keywords or {}
    local items = select(2, (text or ""):gsub("|Hitem:", ""))
    local s = {}
    for cat, words in pairs(WORDS) do
        s[cat] = score(plain, words) + score(plain, extra[cat] or {})
    end
    s.lfg = s.lfg + (score(plain, INSTANCES) > 0 and 1 or 0)
    if items > 0 and s.lfg == 0 then s.trade = s.trade + 1 end
    local hint = CHANNEL_HINT[strlower(channel or "")]
    if hint then s[hint] = s[hint] + 0.5 end
    -- <Guild Name> in a post is a strong guild hint.
    if plain:find("<[^>]+>") then s.guilds = s.guilds + 1 end

    local cat, best = "other", 0
    for _, c in ipairs({ "trade", "lfg", "services", "guilds" }) do
        if s[c] > best then cat, best = c, s[c] end
    end

    local info = { items = items }
    if cat == "lfg" then
        if has(plain, "lfm") or plain:find("%f[%w]lf%dm%f[%W]") or has(plain, "need") then
            info.lfType = "lfm"
            info.roles = {}
            for role, words in pairs(ROLE_WORDS) do
                if score(plain, words) > 0 then info.roles[role] = true end
            end
        elseif has(plain, "lfg") or has(plain, "looking for group") then
            info.lfType = "lfg"
        end
    end
    return cat, info, plain
end
