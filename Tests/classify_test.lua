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
  { "guilds", "General", "<Iron Oath> semi-hardcore raiding, recruiting healers and hunters" },
}
local bad = 0
for _, l in ipairs(lines) do
  local cat = F.Classify(l[3], l[2])
  local ok = cat == l[1]
  if not ok then bad = bad + 1 end
  print(string.format("%s %-9s (want %-8s) %s", ok and "OK " or "BAD", cat, l[1], l[3]:gsub("|c%x+|H.-|h", ""):sub(1, 50)))
end
print(bad == 0 and "ALL OK" or (bad .. " wrong"))
