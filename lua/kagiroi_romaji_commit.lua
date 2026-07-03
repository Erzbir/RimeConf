-- Local kagiroi customization: commit typed romaji with Shift+Return.

local kAccepted = 1
local kNoop = 2
local XK_BackSpace = 0xff08
local XK_Return = 0xff0d

local processor = {}

local function reset(env)
    env.romaji_input = ""
    env.romaji_by_context = {[""] = ""}
    env.pending_insert = nil
    env.pending_delete = nil
end

local function ensure_state(env)
    if not env.romaji_by_context then
        reset(env)
    end
end

local function set_romaji_for_context(env, input, romaji)
    env.romaji_input = romaji or ""
    env.romaji_by_context[input or ""] = env.romaji_input
end

local function sync_from_context(ctx, env)
    ensure_state(env)
    local input = ctx.input or ""

    if env.pending_insert then
        env.romaji_input = env.pending_insert
        if input ~= "" and env.romaji_by_context[input] == nil then
            env.romaji_by_context[input] = env.pending_insert
        end
        return
    end

    if env.pending_delete then
        if input == "" then
            reset(env)
        elseif env.romaji_by_context[input] ~= nil then
            env.romaji_input = env.romaji_by_context[input]
        else
            set_romaji_for_context(env, input, env.pending_delete)
        end
        env.pending_delete = nil
        return
    end

    if input == "" then
        reset(env)
    elseif env.romaji_by_context[input] ~= nil then
        env.romaji_input = env.romaji_by_context[input]
    else
        env.romaji_input = ""
    end
end

local function prepare_for_key(ctx, env)
    ensure_state(env)
    local input = ctx.input or ""
    if input == "" and not ctx:is_composing() then
        reset(env)
    elseif env.romaji_by_context[input] ~= nil then
        env.romaji_input = env.romaji_by_context[input]
    end
    env.pending_insert = nil
    env.pending_delete = nil
end

local function drop_last_ascii_char(text)
    if not text or text == "" then
        return ""
    end
    return text:sub(1, -2)
end

function processor.init(env)
    env.alphabet = env.engine.schema.config:get_string("kagiroi/speller/alphabet") or
        "zyxwvutsrqponmlkjihgfedcba-;"
    reset(env)
    env.update_notifier = env.engine.context.update_notifier:connect(function(ctx)
        sync_from_context(ctx, env)
    end, 0)
end

function processor.fini(env)
    if env.update_notifier then
        env.update_notifier:disconnect()
    end
end

function processor.func(key_event, env)
    if key_event:release() then
        return kNoop
    end

    local context = env.engine.context
    prepare_for_key(context, env)

    local keycode = key_event.keycode
    if keycode == XK_Return and key_event:shift() and
        not key_event:ctrl() and not key_event:alt() and not key_event:super() then
        if context:is_composing() and env.romaji_input ~= "" then
            env.engine:commit_text(env.romaji_input)
            context:clear()
            reset(env)
            return kAccepted
        end
        return kNoop
    end

    if key_event:ctrl() or key_event:alt() or key_event:super() then
        return kNoop
    end

    if keycode == XK_BackSpace then
        if context:is_composing() then
            env.pending_delete = drop_last_ascii_char(env.romaji_input)
            env.romaji_input = env.pending_delete
        end
        return kNoop
    end

    if keycode < 0x20 or keycode > 0x7e then
        return kNoop
    end

    local ch = string.char(keycode)
    if not env.alphabet:find(ch, 1, true) then
        return kNoop
    end

    env.pending_insert = (env.romaji_input or "") .. ch
    env.romaji_input = env.pending_insert
    return kNoop
end

return processor
