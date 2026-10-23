-- =============================================================================
-- ChainGuide.lua : a skillchain guide for Windower 4 (v0.1.0, English edition)
-- =============================================================================
-- Purpose:
-- Show, on a small HUD, the skillchain that is currently resonating on your target, how long its window has left,
-- and which of YOUR weapon skills would continue it. It never uses a weapon skill for you: it does not send any
-- command to the game, so you choose and press the weapon skill yourself.
--
-- What it shows:
--   - A colored bar for the chain (the color follows the element of the chain property; chains with several elements
--     cycle through their colors). The bar stays solid until the window opens (about 3 s), then blinks faster as the window closes.
--   - The chain property, its level, the step number, and the time until the window opens / closes.
--   - A list of your usable weapon skills that would chain from here, with the resulting property and level
--     (the weapon skills you cannot use right now because of TP or range are dimmed).
--   - While no chain is active: a short list of your weapon skills and their properties, to help you pick an opener.
--
-- How it works:
--   - The action packet (0x028) tells it which weapon skill was used on your current target and whether it made a skillchain.
--     Weapon skills of anyone (you, party members, trusts, other players) on the enemy you are targeting are counted.
--   - Skillchain rules (which property chains into which) are from the BG-Wiki "Skillchain" page. The window length and the
--     time until the window opens are the values OmniChain uses (measured by me; see its README); they are guides, not exact.
--   - Weapon skill properties are read from Windower's resources. Nothing is read from or written to game memory.
--   - Not verified in game yet (v0.1.0).
-- =============================================================================

_addon.name     = "ChainGuide"
_addon.author   = "hikaruoshino"
_addon.version  = "0.1.0"
_addon.commands = {"chainguide", "cgd"}

local config  = require("config")
local texts   = require("texts")
local images  = require("images")
local res     = require("resources")
local packets = require("packets")

-- -----------------------------------------------------------------------------
-- Settings (data/settings.xml)
-- -----------------------------------------------------------------------------
local defaults = {}
defaults.show = true          -- show the guide
defaults.only_combat = true   -- show it only while you are engaged or a chain is active (//cgd test always shows it)
defaults.rows = 6             -- how many weapon skills to list
defaults.openers = true       -- when no chain is active, list your weapon skills and their properties
defaults.bar = true           -- show the colored bar
defaults.bar_width = 220
defaults.bar_height = 12
defaults.min_tp = 1000        -- TP needed to use a weapon skill
defaults.ws_reach = 3.5       -- distance (as shown by distanceplus) within which a melee weapon skill reaches
defaults.pos = {x = 40, y = 330}
defaults.text = {font = "Consolas", size = 11, alpha = 255}
defaults.bg = {alpha = 180, red = 10, green = 10, blue = 15}
defaults.padding = 6

local settings = config.load(defaults)

-- -----------------------------------------------------------------------------
-- Skillchain data (BG-Wiki "Skillchain"; same tables as OmniChain)
-- -----------------------------------------------------------------------------
local SC_ELEMENTS = {
    ["Liquefaction"] = {level = 1, elements = {"Fire"}},
    ["Induration"] = {level = 1, elements = {"Ice"}},
    ["Detonation"] = {level = 1, elements = {"Wind"}},
    ["Scission"] = {level = 1, elements = {"Earth"}},
    ["Impaction"] = {level = 1, elements = {"Thunder"}},
    ["Reverberation"] = {level = 1, elements = {"Water"}},
    ["Transfixion"] = {level = 1, elements = {"Light"}},
    ["Compression"] = {level = 1, elements = {"Dark"}},
    ["Fusion"] = {level = 2, elements = {"Fire", "Light"}},
    ["Gravitation"] = {level = 2, elements = {"Earth", "Dark"}},
    ["Fragmentation"] = {level = 2, elements = {"Wind", "Thunder"}},
    ["Distortion"] = {level = 2, elements = {"Ice", "Water"}},
    ["Light"] = {level = 3, elements = {"Fire", "Wind", "Thunder", "Light"}},
    ["Darkness"] = {level = 3, elements = {"Ice", "Earth", "Water", "Dark"}},
    ["Radiance"] = {level = 4, elements = {"Fire", "Wind", "Thunder", "Light"}},
    ["Umbra"] = {level = 4, elements = {"Ice", "Earth", "Water", "Dark"}},
}

-- [previous property][closing weapon skill property] = resulting chain
local SC_COMBO_MAP = {
    ["Liquefaction"] = {["Scission"] = "Scission", ["Impaction"] = "Fusion"},
    ["Induration"] = {["Compression"] = "Compression", ["Reverberation"] = "Fragmentation", ["Impaction"] = "Impaction"},
    ["Detonation"] = {["Scission"] = "Scission", ["Compression"] = "Gravitation"},
    ["Scission"] = {["Liquefaction"] = "Liquefaction", ["Reverberation"] = "Reverberation", ["Detonation"] = "Detonation"},
    ["Impaction"] = {["Liquefaction"] = "Liquefaction", ["Detonation"] = "Detonation"},
    ["Reverberation"] = {["Induration"] = "Induration", ["Impaction"] = "Impaction"},
    ["Transfixion"] = {["Compression"] = "Compression", ["Scission"] = "Distortion", ["Reverberation"] = "Reverberation"},
    ["Compression"] = {["Transfixion"] = "Transfixion", ["Detonation"] = "Detonation"},
    ["Fusion"] = {["Gravitation"] = "Gravitation", ["Fragmentation"] = "Light"},
    ["Gravitation"] = {["Distortion"] = "Darkness", ["Fragmentation"] = "Fragmentation"},
    ["Fragmentation"] = {["Fusion"] = "Light", ["Distortion"] = "Distortion"},
    ["Distortion"] = {["Gravitation"] = "Darkness", ["Fusion"] = "Fusion"},
    ["Light"] = {["Light"] = "Light"},
    ["Darkness"] = {["Darkness"] = "Darkness"},
}

-- Aeonic weapon skills add a Level 3 property (Light/Darkness) while you wield that weapon (BG-Wiki "Aeonic Weapon Skill")
local AEONIC_WS = {
    ["Shijin Spiral"] = {prop = "Light", weapon = "Godhands"},
    ["Exenterator"]   = {prop = "Light", weapon = "Aeneas"},
    ["Requiescat"]    = {prop = "Darkness", weapon = "Sequence"},
    ["Resolution"]    = {prop = "Light", weapon = "Lionheart"},
    ["Ruinator"]      = {prop = "Darkness", weapon = "Tri-edge"},
    ["Upheaval"]      = {prop = "Light", weapon = "Chango"},
    ["Entropy"]       = {prop = "Darkness", weapon = "Anguta"},
    ["Stardiver"]     = {prop = "Darkness", weapon = "Trishula"},
    ["Blade: Shun"]   = {prop = "Light", weapon = "Heishi Shorinken"},
    ["Tachi: Shoha"]  = {prop = "Light", weapon = "Dojikiri Yasutsuna"},
    ["Realmrazer"]    = {prop = "Light", weapon = "Tishtrya"},
    ["Shattersoul"]   = {prop = "Darkness", weapon = "Khatvanga"},
    ["Apex Arrow"]    = {prop = "Light", weapon = "Fail-Not", slot = "range"},
    ["Last Stand"]    = {prop = "Light", weapon = "Fomalhaut", slot = "range"},
}

-- Trust moves whose chain properties are missing from the resources
local TRUST_WS_EXTRA = {
    ["Eternal Vana Illusion"] = {"Fusion"},
    ["Final Eternal Heart"] = {"Fragmentation"},
}

-- Action messages: skillchain results (288-301 / 385-398 in the order below, 767-770 Radiance/Umbra)
local SKILLCHAIN_MESSAGES = {}
do
    local order = {"Light", "Darkness", "Gravitation", "Fragmentation", "Distortion", "Fusion", "Compression", "Liquefaction",
                   "Induration", "Reverberation", "Transfixion", "Scission", "Detonation", "Impaction"}
    for i, name in ipairs(order) do
        SKILLCHAIN_MESSAGES[287 + i] = name
        SKILLCHAIN_MESSAGES[384 + i] = name
    end
    SKILLCHAIN_MESSAGES[767] = "Radiance"; SKILLCHAIN_MESSAGES[769] = "Radiance"
    SKILLCHAIN_MESSAGES[768] = "Umbra"; SKILLCHAIN_MESSAGES[770] = "Umbra"
end
local NO_HIT_MESSAGES = {[31] = true, [188] = true, [189] = true, [323] = true, [324] = true}
local AUTO_ATTACK_MESSAGES = {[1] = true, [15] = true, [67] = true, [352] = true, [353] = true, [354] = true, [576] = true, [577] = true}
local JA_RESULT_MESSAGES = {[100] = true, [102] = true, [110] = true, [158] = true, [317] = true, [323] = true, [324] = true}

-- Timing guides (measured for OmniChain)
local SC_OPEN_SEC = 3.3          -- seconds until the window opens (a weapon skill earlier than this does not chain; the same value OmniChain uses)
local SC_WINDOW_BASE_SEC = 10.0
local SC_WINDOW_MIN_SEC = 4.0
local DONE_NOTE_SEC = 4.0        -- how long "chain complete" stays on the screen
local REFRESH_SEC = 0.15

-- Colors of the elements (for the bar and the text)
local ELEMENT_COLORS = {
    Fire = {255, 70, 50}, Ice = {120, 220, 255}, Wind = {80, 230, 100}, Earth = {210, 165, 60},
    Thunder = {190, 90, 255}, Water = {60, 120, 255}, Light = {255, 255, 255}, Dark = {150, 100, 210},
}

-- -----------------------------------------------------------------------------
-- Small helpers
-- -----------------------------------------------------------------------------
local function num(v, default)
    if type(v) == "number" then return v end
    local n = tonumber(v)
    return n or default or 0
end

local function color_text(str, c, dim)
    local r, g, b = c[1], c[2], c[3]
    if dim then r, g, b = math.floor(r * 0.45), math.floor(g * 0.45), math.floor(b * 0.45) end
    return string.format("\\cs(%d,%d,%d)%s\\cr", r, g, b, tostring(str))
end

local function chat(text, color)
    windower.add_to_chat(color or 207, text)
end

-- The color of a chain property at this moment (a chain with several elements cycles through them)
local function property_color(prop, now)
    local info = SC_ELEMENTS[prop]
    if not info then return {200, 200, 200} end
    local n = #info.elements
    local idx = (n == 1) and 1 or (math.floor(now / 0.6) % n + 1)
    return ELEMENT_COLORS[info.elements[idx]] or {200, 200, 200}
end

local function level_of(prop)
    return SC_ELEMENTS[prop] and SC_ELEMENTS[prop].level or 1
end

local function window_sec(step)
    return math.max(SC_WINDOW_MIN_SEC, SC_WINDOW_BASE_SEC - num(step, 0))
end

-- The resulting chain when a weapon skill with `props` is used after `prev` (a property name or a list in priority order)
local function evaluate(props, prev)
    if not props or not prev then return nil end
    local prev_list = type(prev) == "table" and prev or {prev}
    for _, prev_prop in ipairs(prev_list) do
        local map = SC_COMBO_MAP[prev_prop]
        if map then
            for _, ws_prop in ipairs(props) do
                local result = map[ws_prop]
                if result then return {result = result, level = level_of(result), via = ws_prop} end
            end
        end
    end
    return nil
end

local function is_terminal(prev, result)
    if result == "Radiance" or result == "Umbra" then return true end
    return (result == "Light" or result == "Darkness") and prev == result
end

-- -----------------------------------------------------------------------------
-- Your weapon skills
-- -----------------------------------------------------------------------------
local weapon_cache = {time = -10, names = {}}
local function equipped_weapon_names()
    local now = os.clock()
    if now - weapon_cache.time < 1.0 then return weapon_cache.names end
    weapon_cache.time = now
    local names = {}
    local eq = windower.ffxi.get_items('equipment')
    for _, slot in ipairs({'main', 'range'}) do
        local index = eq and eq[slot]
        if index and index ~= 0 then
            local item = windower.ffxi.get_items(eq[slot .. '_bag'], index)
            local info = item and res.items and res.items[item.id]
            names[slot] = info and info.en
        end
    end
    weapon_cache.names = names
    return names
end

local function aeonic_prop(ws_en)
    local a = ws_en and AEONIC_WS[ws_en]
    if not a then return nil end
    return equipped_weapon_names()[a.slot or 'main'] == a.weapon and a.prop or nil
end

local function ws_properties(def)
    local props = {}
    for _, key in ipairs({"skillchain_a", "skillchain_b", "skillchain_c"}) do
        local en = def[key]
        if en and en ~= "" then
            props[#props + 1] = (en == "Dark") and "Darkness" or en
        end
    end
    local lv3 = aeonic_prop(def.en)
    if lv3 then table.insert(props, 1, lv3) end
    return props
end

-- [{id, en, props}] of the weapon skills you can use now (windower.ffxi.get_abilities). The HUD reads it often, so it is kept for 1 s
local ws_cache = {time = -10, list = {}}
local function my_weapon_skills()
    local now = os.clock()
    if now - ws_cache.time < 1.0 then return ws_cache.list end
    ws_cache.time = now
    local list = {}
    local ok, abil = pcall(windower.ffxi.get_abilities)
    if ok and type(abil) == "table" and type(abil.weapon_skills) == "table" then
        for k, v in pairs(abil.weapon_skills) do
            local id = (type(v) == "number") and v or ((v == true) and k or nil)
            local def = id and res.weapon_skills and res.weapon_skills[id]
            if def then
                local props = ws_properties(def)
                if #props > 0 then list[#list + 1] = {id = id, en = def.en, props = props, range = def.range} end
            end
        end
    end
    table.sort(list, function(a, b) return a.en < b.en end)
    ws_cache.list = list
    return list
end

-- Can the weapon skill reach the target? (same rule of thumb as OmniChain)
local WS_RANGE_MULT = {
    [2] = 1.55, [3] = 1.490909, [4] = 1.44, [5] = 1.377778, [6] = 1.30, [7] = 1.15,
    [8] = 1.25, [9] = 1.377778, [10] = 1.45, [11] = 1.454545454545455, [12] = 1.666666666666667,
}
local WS_RANGE_MARGIN = 0.2
local function in_range(ws, t)
    local mult = ws.range and WS_RANGE_MULT[ws.range]
    if not mult or not t or not t.distance then return true end
    if ws.range == 2 then
        return math.sqrt(num(t.distance, 0)) <= num(settings.ws_reach, 3.5)
    end
    local me = windower.ffxi.get_mob_by_target('me')
    if not t.model_size then return true end
    local reach = t.model_size + ws.range * mult + num(me and me.model_size, 0) - WS_RANGE_MARGIN
    return math.sqrt(num(t.distance, 0)) <= reach
end

-- -----------------------------------------------------------------------------
-- Chain state (from action packets)
-- -----------------------------------------------------------------------------
local chain = nil        -- {props = {...}, step = n, t0 = clock, expire = clock, target = id or nil, starter = name, test = bool}
local done_note = nil    -- {prop = name, until_time = clock}

local function clear_chain()
    chain = nil
end

local function apply_chain(sc_name, target_id, starter)
    local now = os.clock()
    local prev = chain and chain.props and chain.props[1] or nil
    if is_terminal(prev, sc_name) then
        done_note = {prop = sc_name, until_time = now + DONE_NOTE_SEC}
        chain = nil
        return
    end
    local step = (chain and chain.step or 0) + 1
    chain = {props = {sc_name}, step = step, t0 = now, expire = now + window_sec(step), target = target_id, starter = starter}
    done_note = nil
end

local function start_opener(props, target_id, starter)
    local now = os.clock()
    chain = {props = props, step = 0, t0 = now, expire = now + window_sec(0), target = target_id, starter = starter}
    done_note = nil
end

local function on_action(data)
    local p = packets.parse("incoming", data)
    if not p then return end
    local cat = num(p["Category"], 0)
    if cat ~= 3 and cat ~= 11 then return end
    local msg = num(p["Target 1 Action 1 Message"], 0)
    if cat == 3 and JA_RESULT_MESSAGES[msg] then return end          -- some abilities (jumps etc.) arrive as category 3
    if cat == 11 and AUTO_ATTACK_MESSAGES[msg] then return end       -- trust/monster normal attacks are not weapon skills
    local t = windower.ffxi.get_mob_by_target('t')
    local target_id = p["Target 1 ID"]
    if not t or t.id ~= target_id or t.id == p["Actor"] then return end   -- only moves used on the enemy you are targeting

    local actor = windower.ffxi.get_mob_by_id(p["Actor"])
    local name = actor and actor.name or tostring(p["Actor"])
    local me = windower.ffxi.get_player()
    local is_self = me and p["Actor"] == me.id

    local add_msg = p["Target 1 Action 1 Has Added Effect"] and num(p["Target 1 Action 1 Added Effect Message"], 0) or 0
    local sc = SKILLCHAIN_MESSAGES[add_msg]
    if sc then
        apply_chain(sc, target_id, name)
        return
    end
    if NO_HIT_MESSAGES[msg] then return end     -- a miss / no effect is not an opener

    local table_name = (cat == 3) and "weapon_skills" or "monster_abilities"
    local def = res[table_name] and res[table_name][num(p["Param"], 0)]
    if not def then return end
    local props = {}
    for _, key in ipairs({"skillchain_a", "skillchain_b", "skillchain_c"}) do
        local en = def[key]
        if en and en ~= "" then props[#props + 1] = (en == "Dark") and "Darkness" or en end
    end
    if #props == 0 and cat == 11 then
        for _, prop in ipairs(TRUST_WS_EXTRA[def.en] or {}) do props[#props + 1] = prop end
    end
    if is_self and cat == 3 then
        local lv3 = aeonic_prop(def.en)
        if lv3 then table.insert(props, 1, lv3) end
    end
    if #props > 0 then start_opener(props, target_id, name) end
end

-- -----------------------------------------------------------------------------
-- Display
-- -----------------------------------------------------------------------------
local hud = texts.new("", settings)
local bar = images.new({
    pos = {x = settings.pos.x, y = settings.pos.y - settings.bar_height - 4},
    color = {alpha = 0, red = 255, green = 255, blue = 255},
    size = {width = settings.bar_width, height = settings.bar_height},
    draggable = false,
})
local last_text = nil
local next_refresh = 0
local test_until = 0     -- //cgd test keeps the guide visible until this clock time
local bar_chain = false -- true while the bar should be drawn for an active chain
local bar_last = {-1, -1, -1, -1}

local function hide_bar()
    bar:hide()
    bar_last = {-1, -1, -1, -1}
end

local function hide_all()
    hud:hide()
    hide_bar()
    bar_chain = false
    last_text = nil
end

local function set_bar(color, alpha)
    if settings.bar and alpha > 0 then
        local px, py = hud:pos()
        local scale = num(hud:size(), 11) / 11
        local bw, bh = math.floor(settings.bar_width * scale + 0.5), math.max(4, math.floor(settings.bar_height * scale + 0.5))
        local y = py - bh - 4
        if bar_last[5] ~= px or bar_last[6] ~= y or bar_last[7] ~= bw then
            bar:pos(px, y)
            bar:size(bw, bh)
            bar_last[5], bar_last[6], bar_last[7] = px, y, bw
        end
        if bar_last[1] ~= color[1] or bar_last[2] ~= color[2] or bar_last[3] ~= color[3] then
            bar:color(color[1], color[2], color[3])
            bar_last[1], bar_last[2], bar_last[3] = color[1], color[2], color[3]
        end
        if bar_last[4] ~= alpha then
            bar:alpha(alpha)
            bar_last[4] = alpha
        end
        bar:show()
    else
        hide_bar()
    end
end

-- 1 when the bar is lit, 0 when it is dim. Solid until the window opens, then it blinks faster as the window closes
local function blink_state(now)
    local open_at = chain.t0 + SC_OPEN_SEC
    if now < open_at then return 1 end
    local left = math.max(0, chain.expire - now)
    local period = math.max(0.25, math.min(1.0, left / 6))
    return (math.floor(now / (period / 2)) % 2 == 0) and 1 or 0
end

local function build_lines(now, tp, target)
    local lines = {}
    lines[#lines + 1] = "=== ChainGuide ==="
    local active = chain and now < chain.expire and (chain.test or (target and (chain.target == nil or chain.target == target.id)))
    if chain and not active and now >= chain.expire then chain = nil end

    if active then
        local prop_names = {}
        for _, prop in ipairs(chain.props) do prop_names[#prop_names + 1] = color_text(prop, property_color(prop, now)) end
        local lv = level_of(chain.props[1])
        lines[#lines + 1] = string.format("Chain: %s (Lv%d)  step %d  by %s", table.concat(prop_names, "/"), lv, chain.step, tostring(chain.starter or "?"))
        local open_at = chain.t0 + SC_OPEN_SEC
        local on = blink_state(now) == 1
        if now < open_at then
            lines[#lines + 1] = color_text(string.format("WAIT  window opens in %.1fs", open_at - now), {255, 200, 80})
        else
            local c = on and {120, 255, 120} or {60, 120, 60}
            lines[#lines + 1] = color_text(string.format("GO!   %.1fs left", math.max(0, chain.expire - now)), c)
        end

        local ready_tp = tp >= num(settings.min_tp, 1000)
        local rows = {}
        for _, ws in ipairs(my_weapon_skills()) do
            local ev = evaluate(ws.props, chain.props)
            if ev then
                local reach = in_range(ws, target)
                rows[#rows + 1] = {ws = ws, ev = ev, ready = ready_tp and reach, reach = reach}
            end
        end
        table.sort(rows, function(a, b)
            if a.ready ~= b.ready then return a.ready end
            if a.ev.level ~= b.ev.level then return a.ev.level > b.ev.level end
            return a.ws.en < b.ws.en
        end)
        if #rows == 0 then
            lines[#lines + 1] = color_text("None of your weapon skills continue this chain", {200, 200, 200})
        else
            lines[#lines + 1] = "Your weapon skills that chain:"
            for i = 1, math.min(#rows, num(settings.rows, 6)) do
                local r = rows[i]
                local mark = (i == 1 and r.ready) and ">" or " "
                local why = ""
                if not ready_tp then why = " (TP)" elseif not r.reach then why = " (range)" end
                local line = string.format("%s %s -> %s (Lv%d)%s", mark, r.ws.en, r.ev.result, r.ev.level, why)
                lines[#lines + 1] = color_text(line, property_color(r.ev.result, now), not r.ready)
            end
        end
    elseif done_note and now < done_note.until_time then
        lines[#lines + 1] = color_text(string.format("Chain complete: %s (Lv%d). Nothing chains after this.", done_note.prop, level_of(done_note.prop)), property_color(done_note.prop, now))
    else
        lines[#lines + 1] = color_text("No skillchain on your target", {180, 180, 180})
        if settings.openers then
            local shown = 0
            for _, ws in ipairs(my_weapon_skills()) do
                if shown >= num(settings.rows, 6) then break end
                lines[#lines + 1] = string.format("  %s (%s)", ws.en, table.concat(ws.props, "/"))
                shown = shown + 1
            end
            if shown > 0 then table.insert(lines, #lines - shown + 1, "Openers (your weapon skills):") end
        end
    end
    return table.concat(lines, "\n"), active
end

local function refresh(now)
    if not settings.show then hide_all() return end
    local player = windower.ffxi.get_player()
    if not player then hide_all() return end
    local target = windower.ffxi.get_mob_by_target('t')
    local engaged = num(player.status, 0) == 1
    local chain_alive = chain and now < chain.expire
    if settings.only_combat and not (engaged or chain_alive or now < test_until or (done_note and now < done_note.until_time)) then
        hide_all()
        return
    end
    local tp = num(player.vitals and player.vitals.tp, 0)
    local body, active = build_lines(now, tp, target)
    if body ~= last_text then
        hud:text(body)
        last_text = body
    end
    hud:show()

    bar_chain = active and true or false
    if not active then hide_bar() end
end

-- The bar blinks every frame (it only calls the draw functions when the color or the brightness changed)
local function tick_bar(now)
    if not bar_chain or not chain then return end
    local alpha = (blink_state(now) == 1) and 230 or 50
    set_bar(property_color(chain.props[1], now), alpha)
end

-- -----------------------------------------------------------------------------
-- Events
-- -----------------------------------------------------------------------------
local function guarded(fn)
    return function(...)
        local args, n = {...}, select("#", ...)
        local ok, err = pcall(function() return fn(unpack(args, 1, n)) end)
        if not ok then
            chat("[ChainGuide] error: " .. tostring(err):match("^[^\n]*"), 123)
        end
    end
end

windower.register_event("prerender", function()
    local now = os.clock()
    pcall(tick_bar, now)
    if now < next_refresh then return end   -- the text is rebuilt only every REFRESH_SEC
    next_refresh = now + REFRESH_SEC
    local ok, err = pcall(refresh, now)
    if not ok then
        next_refresh = now + 5
        chat("[ChainGuide] display error: " .. tostring(err):match("^[^\n]*"), 123)
    end
end)

windower.register_event("incoming chunk", function(id, data)
    if id ~= 0x028 then return end
    local ok, err = pcall(on_action, data)
    if not ok then chat("[ChainGuide] packet error: " .. tostring(err):match("^[^\n]*"), 123) end
end)

windower.register_event("zone change", function()
    clear_chain()
    done_note = nil
    test_until = 0
    ws_cache.time, weapon_cache.time = -10, -10
end)

windower.register_event("job change", function()
    ws_cache.time, weapon_cache.time = -10, -10
end)

windower.register_event("logout", function()
    clear_chain()
    done_note = nil
    test_until = 0
    hide_all()
end)

windower.register_event("unload", function()
    config.save(settings)
    if hud then hud:destroy() end
    if bar then bar:destroy() end
end)


-- -----------------------------------------------------------------------------
-- Mouse: drag the HUD to move it (libs/texts does this and saves the position), wheel over the HUD to scale it
-- (the bar scales with the text). Returning true keeps the wheel from reaching the game while the cursor is on the HUD.
-- -----------------------------------------------------------------------------
local MOUSE_WHEEL = 10
local SIZE_MIN, SIZE_MAX = 6, 40

local function set_size(size)
    size = math.max(SIZE_MIN, math.min(SIZE_MAX, math.floor(size + 0.5)))
    settings.text.size = size
    hud:size(size)
    last_text = nil
    return size
end

windower.register_event("mouse", function(mtype, x, y, delta, blocked)
    if blocked or mtype ~= MOUSE_WHEEL then return end
    local ok, result = pcall(function()
        if not hud:visible() or not hud:hover(x, y) then return nil end
        local step = num(delta, 0) > 0 and 1 or -1
        set_size(num(hud:size(), num(settings.text and settings.text.size, 11)) + step)
        config.save(settings)
        return true
    end)
    if ok then return result end
end)

-- -----------------------------------------------------------------------------
-- Commands (//cgd or //chainguide)
-- -----------------------------------------------------------------------------
local function on_off(arg, current)
    if arg == "on" then return true end
    if arg == "off" then return false end
    return not current
end

local function print_help()
    chat("[ChainGuide] //cgd on|off              : show / hide the guide")
    chat("[ChainGuide] //cgd combat [on|off]     : show it only while engaged or a chain is active (default on)")
    chat("[ChainGuide] //cgd rows <n>            : how many weapon skills to list (default 6)")
    chat("[ChainGuide] //cgd openers [on|off]    : list your weapon skills while no chain is active")
    chat("[ChainGuide] //cgd bar [on|off]        : the colored bar")
    chat("[ChainGuide] //cgd pos <x> <y> / size <n> : position / text size")
    chat("[ChainGuide] //cgd test                : show a sample chain for 12 s (to check the display)")
    chat("[ChainGuide] //cgd status              : current settings")
    chat("[ChainGuide] This addon only shows information. It never uses a weapon skill for you.")
end

windower.register_event("addon command", function(cmd, ...)
    local ok, err = pcall(function(...)
        local args = {...}
        cmd = cmd and cmd:lower() or "help"
        local a1 = args[1] and args[1]:lower()
        if cmd == "on" or cmd == "off" then
            settings.show = (cmd == "on")
            config.save(settings)
            if not settings.show then hide_all() end
            chat("[ChainGuide] " .. (settings.show and "on" or "off"))
        elseif cmd == "combat" then
            settings.only_combat = on_off(a1, settings.only_combat)
            config.save(settings)
            chat("[ChainGuide] show only while engaged or a chain is active: " .. (settings.only_combat and "on" or "off"))
        elseif cmd == "rows" and tonumber(args[1]) then
            settings.rows = math.max(1, math.min(20, math.floor(tonumber(args[1]))))
            config.save(settings)
            chat("[ChainGuide] rows: " .. settings.rows)
        elseif cmd == "openers" then
            settings.openers = on_off(a1, settings.openers)
            config.save(settings)
            chat("[ChainGuide] openers list: " .. (settings.openers and "on" or "off"))
        elseif cmd == "bar" then
            settings.bar = on_off(a1, settings.bar)
            config.save(settings)
            if not settings.bar then hide_bar() end
            chat("[ChainGuide] bar: " .. (settings.bar and "on" or "off"))
        elseif cmd == "pos" and tonumber(args[1]) and tonumber(args[2]) then
            settings.pos.x, settings.pos.y = tonumber(args[1]), tonumber(args[2])
            hud:pos(settings.pos.x, settings.pos.y)
            config.save(settings)
        elseif cmd == "size" and tonumber(args[1]) then
            set_size(tonumber(args[1]))
            config.save(settings)
        elseif cmd == "test" then
            local now = os.clock()
            test_until = now + 13
            chain = {props = {"Fusion"}, step = 1, t0 = now, expire = now + 12, target = nil, starter = "test", test = true}
            done_note = nil
            ws_cache.time = -10
            chat("[ChainGuide] showing a sample chain (Fusion) for 12 s")
        elseif cmd == "status" then
            chat(string.format("[ChainGuide] v%s show=%s combat=%s rows=%d openers=%s bar=%s", _addon.version, tostring(settings.show),
                tostring(settings.only_combat), num(settings.rows, 6), tostring(settings.openers), tostring(settings.bar)))
        else
            print_help()
        end
    end, ...)
    if not ok then chat("[ChainGuide] command error: " .. tostring(err):match("^[^\n]*"), 123) end
end)

