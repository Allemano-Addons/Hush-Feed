-- Regression test for the sorting, with real WoW Forever posts. Not loaded by the game.
-- Run from the Hush_Feed folder:  lua Tests/classify_test.lua
tinsert, tremove, sort, time, wipe = table.insert, table.remove, table.sort, os.time, function(t) for k in pairs(t) do t[k] = nil end end
strlower = string.lower
local F = { db = { keywords = {}, role = "healer", window = 15, maxPosts = 500 } }
assert(loadfile("Classify.lua"))("Hush_Feed", F)
local lines = {
  { "other", "General", "wtf even is \"everyday meals\" tab in cooking. then puts |cffffffff|Hitem:1|h[Goblin Deviled Clams]|h|r in that tab." },
  { "trade", "Trade", "wtb |cffffffff|Hitem:1|h[Lil Timmy's Peashooter]|h|r" },
  { "trade", "Trade", "WTS|cffffffff|Hitem:1|h[Hook Dagger of Healing]|h|r" },
  { "services", "Trade", "|cffffd000|Htrade:1:2|h[Enchanting]|h|r LFW in org" },
  { "services", "Trade", "lf neck enchant" },
  { "other", "Trade", "is it not possible to keybind the totem bar?" },
  { "lfg", "Trade", "need - TANK - RoL" },
  { "other", "General", "have a trainer paladin to ogri" },
  { "spam", "General", "███ FOREVER GOLD ███ Whу fаrm in bеtа? Вuу gоld, tеst еvеrуthing, bе rеаdу fоr lаunсh! Non-bot only safe-secure! Маil / Тrаdе / АН • 24/7 ███►►ForeverGold.net◄◄ bу Муthiс-Stоrе███" },
  { "spam", "General", "█▓█ MIDNIGHT + TBC █▓█ Еnjоу Fоrеvеr - wе соvеr уоur М+ kеуs, Rаids & ВТ lосkоuts! Stау аhеаd █►►MythicStore.com◄◄█" },
  { "other", "Trade", "is RFC still a thing for mid teen level?" },
  { "services", "Trade", "|cffffd000|Htrade:1:2|h[Tailoring]|h|r" },
  { "other", "Trade", "BEHOLD!!! THE ALMIGHTY HUNTER IS HERE!!! HE WILL ALL THE ALLIANCE!!! but first.. give me some gold!!!!" },
  { "other", "Trade", "gonna need to show a little skin for those bags" },
  { "services", "Trade", "WTS summons to TB.  Whisper 'inv' for an invite!" },
  { "lfg", "LookingForGroup", "LFM Strat UD, need tank + heals" },
  { "other", "General", "crippling poison on MH or OH?" },
  { "guilds", "Trade", "WoW Forever попереду!  Ми збираємо сильну спільноту після релізу. Досвід Classic/TBC, PvE-прогрес, рейди та активне комьюніті! /w inv!" },
  { "other", "Trade", "whats 9 + 10" },
  { "other", "General", "'" },
  { "guilds", "General", "<Iron Oath> semi-hardcore raiding, recruiting healers and hunters" },
  -- Optional 4th/5th value: expected lfType and a role the post asks for.
  { "lfg", "Trade", "LF TANK RFC LAST SPOT", "lfm", "tank" },
  { "lfg", "Trade", "DPS LF RFC", "lfg" },
  { "lfg", "Trade", "SFK -1DPS", "lfm", "dps" },
  { "lfg", "Trade", "Anyone doing BFD ?" },
  { "services", "Trade", "< Taxi Service > Thunderbluff /w" },
  { "services", "Trade", "WTB summon TB" },
  { "guilds", "General", "<Homies Forever> is building its launch roster. Progression raiders who also enjoy PvP and just love the game" },
  { "services", "Trade", "LF ENCHANTER UC" },
  { "services", "Trade", "LF tailor to craft" },
}
local bad = 0
for _, l in ipairs(lines) do
  local cat, info = F.Classify(l[3], l[2])
  local ok = cat == l[1]
  if l[4] and info.lfType ~= l[4] then ok = false end
  if l[5] and not (info.roles and info.roles[l[5]]) then ok = false end
  if not ok then bad = bad + 1 end
  print(string.format("%s %-9s %-4s (want %-8s) %s", ok and "OK " or "BAD", cat, tostring(info.lfType), l[1],
    l[3]:gsub("|c%x+|H.-|h", ""):sub(1, 50)))
end
print(bad == 0 and "ALL OK" or (bad .. " wrong"))
