# Hush Feed

**Trade, General and LFG chat, sorted and readable.** Hush Feed is a module for [Hush](https://www.curseforge.com/wow/addons/hush) on WoW Forever. It reads the public channels and sorts every post into a clean list you can search, filter and act on, instead of a wall of scrolling chat.

> **Alpha.** Requires Hush. The sorting is tuned on real WoW Forever posts, but new phrasings turn up all the time; you can add your own words in the settings.

## What it does

### Sorts every post into a feed
Hush Feed reads General, Trade, TradeLocal, Services and LookingForGroup (plus any custom channel you add) and puts each post in one of:
**LFG**, **Trade**, **Services**, **Guilds** or **Other**, with a count for each. It tells a group looking for players ("LF TANK RFC") from a player looking for a group ("DPS LF RFC"), recognizes dungeon names and abbreviations, and treats "LF enchanter" as a service request, not a group.

### Filters out gold-seller spam
Gold-selling ads (block graphics, web addresses, look-alike letters) go into a hidden Spam category that is left out of every list.

### Made for actually finding things
- **Search** posts, items and players.
- **My role:** set tank, healer or DPS and LFG posts that need your role are tagged **"Needs your role"**.
- **Time window:** 5, 15, 30 or 60 minutes. Older posts fade out.
- **Pause** freezes the list while you read; Resume shows what came in. The counter tells you how many new posts arrived meanwhile.
- **Repeated posts** from the same player are merged ("x3") instead of filling the list.
- Click a post to read the whole message, and click item links to see the item.
- **Whisper** opens the conversation in Hush, **Invite** invites players looking for a group (and services), and right-click a name to mute someone for the session.

### Watches: get told when something you want shows up
Save a search (all words must be in the post, optionally in one category), for example "Thorium" in Trade, or "Deadmines" in LFG. A new match plays a sound (never in combat), lights up a badge and highlights the row.

*Example:* Make a watch for "Enchanting" in Services and carry on playing; you hear a bell when someone asks for an enchanter.

## Settings
`/feed options` or the gear in the window: role, time window, watch sound, which channels to read (add your own by name) and extra sorting words per category.

The feed only lives in memory. Nothing from the channels is saved to disk.

## Commands
`/feed` (or `/hf`) opens the window, `/feed options`, `/feed role <tank|healer|dps|none>`, `/feed sound <bell|ping|raid|whisper|click>`, `/feed clear`.

## Installing manually (WoW Forever)
Requires **Hush**. Made for WoW Forever (interface 16001). If the CurseForge app does not install it into the right folder, download the file from the **Files** tab and unzip it so that the folder is `World of Warcraft\_classic_beta_\Interface\AddOns\Hush_Feed`, next to the Hush folder. Restart the game.

Part of **Allemano Addons**. Source code and issues: https://github.com/Allemano-Addons/Hush-Feed
