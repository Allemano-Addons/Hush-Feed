# Hush Feed

A module for [Hush](../Hush) on WoW Forever. It reads the public channels (General, Trade,
Services, LookingForGroup, TradeLocal, optionally LocalDefense and your own channels) and sorts
every post into **LFG**, **Trade**, **Services**, **Guilds** or **Other**. Gold-seller spam is
filtered out.

Requires Hush 0.1.27 or newer.

## Open it
- `/feed` (or `/hf`), the list button in the Hush title row, or the Hush launcher menu.

## The window
- **Feeds** on the left with counts; **search** posts, items and players.
- **My role**: LFG posts that need your role are tagged "Needs your role".
- **Time window** 5 / 15 / 30 / 60 min; older posts fade out.
- **Pause** freezes the list while you read; Resume shows what came in.
- Repeated posts from the same player are merged (x3).
- Click a post to see the whole message. **Whisper** opens Hush, **Invite** invites
  (players looking for a group, services), **×** hides the post, right-click a name to mute.

## Watches
Saved searches: all words must be in the post, optionally in one category. A new match
plays a sound (never in combat) and is highlighted.

## Settings
`/feed options` or the gear in the window: role, time window, watch sound, channels (add your
own by name) and extra sorting words per category.

## Commands
`/feed`, `/feed options`, `/feed stats`, `/feed dump [category]`, `/feed role <tank|healer|dps|none>`,
`/feed sound <bell|ping|raid|whisper|click>`, `/feed clear`.

The feed lives in memory only; nothing from the channels is saved.
