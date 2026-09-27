# Changelog

## 0.1.0 (in progress)

### Step 1 – Capture and sorting
- Module skeleton (`## Dependencies: Hush`), `HushFeedDB` for settings only – the feed itself lives in memory and is never saved.
- Reads General, Trade, TradeLocal, Services and LookingForGroup (LocalDefense off), plus custom channels.
- Sorting into LFG / Trade / Services / Guilds / Other by whole-word keywords, item links, instance names, `<Guild>` tags and the channel's topic; extra keywords per category.
- LFM (group looking for players) vs LFG (player looking for a group), requested roles, and "needs your role" for the role you choose.
- Repeated posts from the same player are merged (xN); posts expire after 60 min, max 500 kept.
- `/feed dump [category]`, `/feed stats`, `/feed role <tank|healer|dps|none>`, `/feed test`, `/feed clear`.
- Sorting tuned on real Forever posts: strong vs weak keywords (one weak word like "selling" or "guild" in normal talk is not enough), the channel alone never decides (chat in Trade becomes Other), services outweigh WTS ("WTS summons" is a service), "summ" abbreviations, instance names count half ("live", "st" are also normal words).
- More real posts: links count as separate words ("WTS[item]"), an item link alone is only a hint, profession links ([Tailoring]) are services, "need"/"lf" + a role is LFG ("need - TANK -"), and a hidden **Spam** category for gold sellers (block graphics, web addresses, Cyrillic look-alike letters). Spam is left out of All and counted separately.
- `Tests/classify_test.lua`: regression test with real posts (not loaded by the game).
