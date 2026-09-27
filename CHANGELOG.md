# Changelog

## 0.1.0 (2026-09-27)

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

### Step 4 – Watches
- Saved searches: a name, words that must ALL be in the post, and a category (Any / LFG / Trade / Services / Guilds). "+ New watch" opens an editor; right-click a watch for Edit, Pause/Resume, Delete.
- A new match plays a sound (also when the Feed window is closed; never in combat; at most one per 3 s), adds to the watch's badge and highlights the row (accent bar + tint). A merged repeat (xN) does not alert again.
- Clicking a watch shows only its matches (from all categories) and clears its badge.
- Sounds: Bell (default), Ping, Raid warning, Whisper, Click – `/feed sound <name>` until the settings page exists.

### Step 5 – Settings
- New "Feed" page in the Hush settings (`/feed options` or the gear in the Feed window): My role, default time window, watch sound (plays when you pick it), and Channels – toggle the defaults (incl. LocalDefense) and any channel you are in, add your own by name, turn a custom one off to remove it.
- New "Feed sorting" page: extra words per category (LFG, Trade, Services, Guilds), added to the built-in words; they apply to new posts.
- `/feed role` now updates the window right away.
- Click a post to see the whole message (click again to fold it); clicking an item link still shows the item.
- Pause now really freezes the list: only the posts shown when you pressed Pause, in the same order, even if you hide a post, switch feed, search or resize. Resume shows everything.

## 0.1.1 (in progress)
- `Hush.Feed`: a small public API for other Hush modules (posts, shared "My role", a callback for new posts). Used by Hush LFG.
- "LF enchanter", "LF tailor", "LF alchemist" and other crafters are Services, not LFG.
