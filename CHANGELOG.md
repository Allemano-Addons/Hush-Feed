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
- Guild recruitment in Russian/Ukrainian (stems like "гильди", "рейд", "набор", "спільнот") counts as Guilds.

### Step 2 – Window (with step 3's buttons)
- The Hush Feed window from the mockup (`/feed`, the list button in the Hush title row, or the launcher menu): FEEDS (All / LFG / Trade / Services / Guilds / Other with counts), WATCHES (next step), CHANNELS; search (posts, items, players), My role (click to cycle), time window (5/15/30/60 min), Pause (counts new posts while paused).
- Rows: category, class-colored name, channel · age, xN for merged repeats, "Needs your role", the text with clickable item links; Whisper (opens Hush), Invite (players looking for a group, services), × hides the post. Right-click a name: Whisper or Mute (this session). Older posts fade before they expire.
- Virtualized list; refreshes only while the window is open (at most twice a second on busy channels, plus every 20 s for ages). Movable, resizable, position saved, ESC closes, follows the Hush theme (incl. Blizzard Style).
- Requires Hush 0.1.27 (`Hush.OpenWhisper`, list icon).
- Sorting from the first window test: a role AFTER "LF" is a group looking for players ("LF TANK RFC" → Needs your role), a role BEFORE "LF" is a player ("DPS LF RFC"); "-1DPS" / "- 1 tank" is a missing role; "anyone doing <dungeon>" is LFG; "service"/"taxi" are services (beating a `< >` tag). The regression test now also checks LFM/LFG and roles.
