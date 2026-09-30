std = "lua51"
exclude_files = { "Tests/**" }
max_line_length = false
self = false

globals = {
    "HushFeedDB",
    "SLASH_HUSHFEED1", "SLASH_HUSHFEED2", "SlashCmdList",
    "HushFeedFrame", -- window name, only so ESC closes it
    -- Hush is read-only except Hush.Feed, the public API for other modules.
    Hush = { read_only = true, other_fields = true, fields = { Feed = { read_only = false, other_fields = true } } },
}

read_globals = {
    "issecretvalue",
    -- (Hush: see globals)
    "strjoin", "strsplit", "strtrim", "strlower", "strupper", "tostringall", "tinsert", "tremove", "wipe",
    "sort", "floor", "ceil", "min", "max", "format", "date", "time", "CopyTable", "geterrorhandler",
    "CreateFrame", "UIParent", "DEFAULT_CHAT_FRAME", "GetTime", "Ambiguate", "GetPlayerInfoByGUID",
    "UISpecialFrames", "C_Timer", "RAID_CLASS_COLORS", "CUSTOM_CLASS_COLORS", "SetItemRef", "GameTooltip",
    "PlaySound", "SOUNDKIT", "UnitAffectingCombat", "InCombatLockdown", "IsShiftKeyDown", "GetCursorPosition", "GetChannelList", "GetChannelName",
}
