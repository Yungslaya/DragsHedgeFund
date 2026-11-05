local ADDON, GG = ...
DragsHedgeFund = GG

local floor, max, min = math.floor, math.max, math.min
local COPPER_PER_GOLD = 10000

local function isNum(v)
    return type(v) == "number" and not (issecretvalue and issecretvalue(v))
end
GG.isNum = isNum

local function safe(f, ...)
    if type(f) ~= "function" then return end
    local r = { pcall(f, ...) }
    if r[1] then return unpack(r, 2) end
end
GG.safe = safe

------------------------------------------------------------ money text
do
    local ICON = "|TInterface\\MoneyFrame\\UI-%sIcon:0:0:2:0|t"
    local function commas(n)
        local s = tostring(n)
        while true do
            local k
            s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
            if k == 0 then return s end
        end
    end
    GG.Commas = commas
    -- 1234567 -> "123g 45s" with gold/silver/copper colors and coin icons.
    -- same, but no copper once there is gold (for tight spots)
    function GG.MoneyShort(c)
        c = floor((c or 0) + 0.5)
        if c >= 10000 then c = floor(c / 100) * 100 end
        return GG.Money(c)
    end
    function GG.Money(c)
        c = floor((c or 0) + 0.5)
        if c < 0 then c = 0 end
        local g, s, cp = floor(c / 10000), floor(c / 100) % 100, c % 100
        local out = {}
        if g > 0 then out[#out + 1] = "|cffffd700" .. commas(g) .. "|r" .. ICON:format("Gold") end
        if s > 0 and g < 1000 then out[#out + 1] = "|cffd0d0d8" .. s .. "|r" .. ICON:format("Silver") end
        if (cp > 0 and g < 10) or c == 0 then out[#out + 1] = "|cffeda55f" .. cp .. "|r" .. ICON:format("Copper") end
        return table.concat(out, " ")
    end
end

------------------------------------------------------------ saved data
function GG.InitDB()
    DragsHedgeFundDB = DragsHedgeFundDB or {}
    local db = DragsHedgeFundDB
    if not isNum(db.pct) then db.pct = 20 end
    -- version 2: only confirmed cuts from new gains count. Start clean.
    if (db.version or 1) < 2 then
        db.saved, db.owed, db.log = 0, 0, {}
        if db.goal then db.goal.metSound = nil end
        db.version = 2
    end
    -- old builds kept pace data here; not used any more
    db.auto, db.days, db.trackStart, db.xpLvl, db.xpCur, db.xpMax = nil, nil, nil, nil, nil, nil
    if db.goal then
        db.goal.level, db.goal.deadline, db.goal.startSaved = nil, nil, nil
        -- old custom goal names had "by level 40" / "in 7 days" in them
        if type(db.goal.name) == "string" then
            db.goal.name = db.goal.name:gsub(" by level %d+", ""):gsub(" in %d+ days?", "")
        end
    end
    if not isNum(db.owed) then db.owed = 0 end
    if not isNum(db.saved) then db.saved = 0 end
    db.log = db.log or {}
    if db.mini == nil then db.mini = true end
    if db.shown == nil then db.shown = true end
    GG.db = db
end

------------------------------------------------------------ money
function GG.OnMoney(silent)
    local m = safe(GetMoney)
    if not isNum(m) then return end
    local db = GG.db
    if silent then
        -- loading screens: just remember the amount. 0 may mean "not loaded yet".
        db.lastMoney = (m > 0) and m or nil
        return
    end
    if isNum(db.lastMoney) and m > db.lastMoney then
        local gain = m - db.lastMoney
        local g = db.goal
        local cut = 0
        if g then
            -- take your % from this one gain, but never more than the goal still needs
            cut = min(floor(gain * db.pct / 100 + 0.5), max(g.amount - db.saved - db.owed, 0))
        end
        if cut > 0 then
            db.owed = db.owed + cut
            local log = db.log
            log[#log + 1] = { t = time(), gain = gain, cut = cut }
            while #log > 300 do table.remove(log, 1) end
        end
        GG.lastGain, GG.lastPut, GG.lastAt = gain, cut, GetTime()
    end
    db.lastMoney = m
end

-- You moved the gold somewhere safe (bank alt, mail...). Count it as saved.
-- amt: how much (default all of it). to: who it was mailed to, if mailed.
function GG.ConfirmSaved(amt, to)
    local db = GG.db
    if db.owed <= 0 then return end
    amt = min(amt or db.owed, db.owed)
    if amt <= 0 then return end
    if amt >= db.owed then
        for _, e in ipairs(db.log) do if e.cut and not e.done then e.done = true end end
    else
        -- only part of it: mark the oldest gains first
        local left = amt
        for _, e in ipairs(db.log) do
            if e.cut and not e.done and e.cut <= left then e.done = true; left = left - e.cut end
        end
    end
    db.log[#db.log + 1] = { t = time(), saved = amt, to = to }
    while #db.log > 300 do table.remove(db.log, 1) end
    db.saved = db.saved + amt
    db.owed = max(db.owed - amt, 0)
    local g = db.goal
    if g and db.saved >= g.amount and not g.metSound then
        g.metSound = true
        if PlaySound and SOUNDKIT then safe(PlaySound, SOUNDKIT.LEVEL_UP or 888) end
    end
    print("|cffffd700Hedge Fund:|r saved " .. GG.Money(amt) .. (to and (" (mailed to " .. to .. ")") or "") ..
        ". Total saved: " .. GG.Money(db.saved))
end

-- 0.0005 -> "under 1%" (plain floor would show 0% and look broken)
function GG.PctText(frac)
    if frac > 0 and frac < 0.01 then return "under 1%" end
    return floor(frac * 100) .. "%"
end

-- "5g 37s 2c" with no colors or icons (for mail text)
function GG.MoneyPlain(c)
    c = floor((c or 0) + 0.5)
    local g, s, cp = floor(c / 10000), floor(c / 100) % 100, c % 100
    local out = {}
    if g > 0 then out[#out + 1] = GG.Commas(g) .. "g" end
    if s > 0 then out[#out + 1] = s .. "s" end
    if cp > 0 or c == 0 then out[#out + 1] = cp .. "c" end
    return table.concat(out, " ")
end

-- How many gains are waiting to be put away.
function GG.OwedCount()
    local n = 0
    for _, e in ipairs(GG.db.log) do if e.cut and not e.done then n = n + 1 end end
    return n
end

------------------------------------------------------------ goal
function GG.SetGoal(name, gold)
    local db, old = GG.db, GG.db.goal
    -- last goal was met (you bought it): start the new one from 0
    if old and db.saved >= old.amount then
        db.saved, db.owed = 0, 0
        for _, e in ipairs(db.log) do if e.cut then e.done = true end end
    end
    db.goal = { name = name, amount = floor(gold * COPPER_PER_GOLD), start = time() }
end

function GG.PresetGold(p)
    local _, class = safe(UnitClass, "player")
    if GG.CLASS_MOUNT[class] then return GG.CLASS_PRESET_GOLD[p.key] or p.gold end
    return p.gold
end

function GG.PickPreset(key)
    for _, p in ipairs(GG.PRESETS) do
        if p.key == key then GG.SetGoal(p.name, GG.PresetGold(p)) return end
    end
end

-- Everything the window shows, worked out in one place.
function GG.Status()
    local db, g = GG.db, GG.db.goal
    local s = { saved = db.saved, owed = db.owed }
    if not g then return s end
    s.goal, s.amount = g, g.amount
    s.need = max(g.amount - db.saved, 0)                 -- still need to save
    s.frac = g.amount > 0 and min(db.saved / g.amount, 1) or 1
    s.frac2 = g.amount > 0 and min((db.saved + db.owed) / g.amount, 1) or 1
    s.done = db.saved >= g.amount
    s.allIn = db.saved + db.owed >= g.amount              -- no more cuts needed
    return s
end

------------------------------------------------------------ tips
function GG.MyProfessions()
    local out, seen = {}, {}
    local function add(name, line)
        local key = (isNum(line) and GG.PROF_TIPS[line]) and line or GG.PROF_BY_NAME[name]
        if key and not seen[key] then seen[key] = true; out[#out + 1] = key end
    end
    if GetProfessions and GetProfessionInfo then
        local list = { safe(GetProfessions) }
        for i = 1, 6 do
            local idx = list[i]
            if idx then
                local name, _, _, _, _, _, line = safe(GetProfessionInfo, idx)
                add(name, line)
            end
        end
    end
    if #out == 0 and GetNumSkillLines and GetSkillLineInfo then
        local n = safe(GetNumSkillLines) or 0
        if not isNum(n) then n = 0 end
        for i = 1, n do
            local name, header = safe(GetSkillLineInfo, i)
            if name and not header then add(name) end
        end
    end
    return out
end

function GG.ScanGrays()
    local n, total = 0, 0
    if not (C_Container and C_Container.GetContainerNumSlots and C_Item and C_Item.GetItemInfo) then return 0, 0 end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = safe(C_Container.GetContainerNumSlots, bag) or 0
        if not isNum(slots) then slots = 0 end
        for slot = 1, slots do
            local info = safe(C_Container.GetContainerItemInfo, bag, slot)
            if type(info) == "table" and info.quality == 0 and not info.hasNoValue and info.itemID then
                local price = select(11, safe(C_Item.GetItemInfo, info.itemID))
                if isNum(price) and price > 0 then
                    n = n + 1
                    total = total + price * (info.stackCount or 1)
                end
            end
        end
    end
    GG.grayCount, GG.grayValue = n, total
    return n, total
end

GG.tipStep = 0
function GG.Tips()
    local list = {}
    if (GG.grayCount or 0) > 0 then
        list[#list + 1] = "|cff9d9d9dSell grays:|r " .. GG.Money(GG.grayValue)
    end
    local pool = {}
    for _, line in ipairs(GG.MyProfessions()) do
        local t = GG.PROF_TIPS[line]
        for i = 2, #t do pool[#pool + 1] = "|cffffd100" .. t[1] .. ":|r " .. t[i] end
    end
    for _, t in ipairs(GG.TIPS) do pool[#pool + 1] = t end
    local start = GG.tipStep % #pool
    for i = 0, #pool - 1 do
        if #list >= 2 then break end
        list[#list + 1] = pool[(start + i) % #pool + 1]
    end
    return list
end

------------------------------------------------------------ events
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_MONEY")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("SKILL_LINES_CHANGED")
ev:SetScript("OnEvent", function(_, e)
    if e == "PLAYER_LOGIN" then
        GG.InitDB()
        GG.OnMoney(true)
        GG.ScanGrays()
        if GG.BuildUI then GG.BuildUI() end
    elseif not GG.db then
        return
    elseif e == "PLAYER_ENTERING_WORLD" then
        GG.OnMoney(true)
    elseif e == "PLAYER_MONEY" then
        GG.OnMoney()
    elseif e == "BAG_UPDATE_DELAYED" then
        GG.ScanGrays()
    end
    if GG.Refresh then GG.Refresh() end
end)

------------------------------------------------------------ slash
SLASH_DRAGSHEDGEFUND1, SLASH_DRAGSHEDGEFUND2, SLASH_DRAGSHEDGEFUND3 = "/gg", "/hedge", "/dhf"
SlashCmdList.DRAGSHEDGEFUND = function(msg)
    if not GG.db then return end
    local cmd, rest = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local num = tonumber(rest)
    local db = GG.db
    if cmd == "" then
        GG.Toggle()
    elseif cmd == "goal" then
        GG.Show("setup")
    elseif cmd == "pct" and num then
        db.pct = min(max(floor(num), 1), 100)
        print("|cffffd700Hedge Fund:|r saving " .. db.pct .. "% of each gain.")
    elseif cmd == "add" and num then
        db.saved = max(db.saved + floor(num * COPPER_PER_GOLD), 0)
        print("|cffffd700Hedge Fund:|r saved is now " .. GG.Money(db.saved))
    elseif cmd == "set" and num then
        db.saved = max(floor(num * COPPER_PER_GOLD), 0)
        print("|cffffd700Hedge Fund:|r saved is now " .. GG.Money(db.saved))
    elseif cmd == "mini" or cmd == "overlay" then
        if GG.ToggleMini then GG.ToggleMini() end
    elseif cmd == "lock" then
        db.miniLock = not db.miniLock
        print("|cffffd700Hedge Fund:|r overlay " .. (db.miniLock and "locked." or "unlocked. Drag to move."))
    elseif cmd == "scale" and num then
        db.miniScale = min(max(num, 0.5), 2)
        if GG.mini then GG.mini:SetScale(db.miniScale) end
    elseif cmd == "tips" then
        db.miniTips = db.miniTips == false
        print("|cffffd700Hedge Fund:|r overlay tip " .. (db.miniTips and "on." or "off."))
    elseif cmd == "saved" then
        GG.ConfirmSaved()
    elseif cmd == "reset" then
        db.goal, db.saved, db.owed = nil, 0, 0
        for _, e in ipairs(db.log) do if e.cut then e.done = true end end
        print("|cffffd700Hedge Fund:|r goal cleared.")
    else
        print("|cffffd700Hedge Fund:|r /gg  - show or hide")
        print("  /gg goal  - pick a goal")
        print("  /gg mini  - show or hide the overlay")
        print("  /gg lock  - lock the overlay")
        print("  /gg scale 1.2  - overlay size")
        print("  /gg tips  - overlay tip on or off")
        print("  /gg pct 20  - save 20% of each gain")
        print("  /gg saved  - I put the gold away")
        print("  /gg add 10  - add 10g to saved")
        print("  /gg set 50  - set saved to 50g")
        print("  /gg reset  - clear the goal")
    end
    if GG.Refresh then GG.Refresh() end
end
