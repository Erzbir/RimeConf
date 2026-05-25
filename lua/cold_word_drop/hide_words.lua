local source = debug.getinfo(1, "S").source
local path = source:sub(1, 1) == "@" and source:sub(2) or source
local root = path:gsub("[/\\]lua[/\\].*$", "")
return dofile(root .. "/packages/rime-ice/lua/cold_word_drop/hide_words.lua")
