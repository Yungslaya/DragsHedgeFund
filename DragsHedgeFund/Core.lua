local ADDON, GG = ...
DragsHedgeFund = GG

local floor, max, min = math.floor, math.max, math.min
local COPPER_PER_GOLD = 10000

local function isNum(v)
    return type(v) == "number" and not (issecretvalue and issecretvalue(v)) and v == v and v > -math.huge and v < math.huge
end
GG.isNum = isNum

local function safe(f, ...)
    if type(f) ~= "function" then return end
    local function pack(...) return { n = select("#", ...), ... } end
    local r = pack(pcall(f, ...))
    if r[1] then return unpack(r, 2, r.n) end
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
        if s > 0 then out[#out + 1] = "|cffd0d0d8" .. s .. "|r" .. ICON:format("Silver") end
        if cp > 0 or c == 0 then out[#out + 1] = "|cffeda55f" .. cp .. "|r" .. ICON:format("Copper") end
        return table.concat(out, " ")
    end
end


-- Keep reservations within the money actually received.
function GG.TotalPct(except)
    local total = 0
    for _, g in ipairs(GG.db.goals) do if g ~= except then total = total + g.pct end end
    return total
end

function GG.SetSavedCopper(goal, amount)
    if not goal or not isNum(amount) or amount < 0 or amount ~= floor(amount) then return false end
    goal.saved = amount
    return true
end

function GG.SetGoalPct(g, pct)
    g.pct = min(max(floor(pct), 0), 100 - GG.TotalPct(g))
end

function GG.AllocateGain(gain)
    local parts, candidates, exact, assigned = {}, {}, 0, 0
    for i, g in ipairs(GG.db.goals) do
        local share = min(gain * g.pct / 100, max(g.amount - g.saved - g.owed, 0))
        local whole = floor(share)
        parts[g.id], exact, assigned = whole, exact + share, assigned + whole
        candidates[#candidates + 1] = { id = g.id, fraction = share - whole, order = i }
    end
    table.sort(candidates, function(a, b)
        if a.fraction == b.fraction then return a.order < b.order end
        return a.fraction > b.fraction
    end)
    local extra = min(gain, floor(exact + 0.5)) - assigned
    for _, c in ipairs(candidates) do
        if extra > 0 and c.fraction > 0 then
            parts[c.id], assigned, extra = parts[c.id] + 1, assigned + 1, extra - 1
        end
    end
    return assigned, parts
end

function GG.UpdateEntry(e)
    if not e.cut then return end
    local unpaid = 0
    for _, c in pairs(e.remaining or {}) do unpaid = unpaid + c end
    e.unpaid, e.done = unpaid, unpaid == 0
end

function GG.TrimLog()
    -- Never discard an unpaid gain. Keep the newest 300 settled records as well.
    local log, paid = GG.db.log, 0
    for i = #log, 1, -1 do
        if not log[i].cut or log[i].done then
            paid = paid + 1
            if paid > 300 then table.remove(log, i) end
        end
    end
end

function GG.RepairLedger()
    local db, totals = GG.db, {}
    for _, g in ipairs(db.goals) do totals[g.id] = g.owed end
    for _, e in ipairs(db.log) do
        if e.cut then
            local original = e.remaining or (not e.done and e.parts) or {}
            local remaining = {}
            -- Old single-goal records have no parts map.
            if not e.parts and not e.done and db.goals[1] then
                original = { [db.goals[1].id] = e.cut }
            end
            for _, g in ipairs(db.goals) do
                local c = min(max(original[g.id] or 0, 0), totals[g.id])
                remaining[g.id], totals[g.id] = c, totals[g.id] - c
            end
            e.remaining = remaining
            GG.UpdateEntry(e)
        end
    end
    local missing, parts = 0, {}
    for id, c in pairs(totals) do parts[id], missing = c, missing + c end
    if missing > 0 then
        table.insert(db.log, 1, { t = time(), gain = 0, cut = missing, remaining = parts,
            parts = parts, unpaid = missing, carried = true })
    end
    GG.TrimLog()
end


------------------------------------------------------------ saved data
GG.MAX_GOALS = 5

function GG.InitDB()
    DragsHedgeFundDB = DragsHedgeFundDB or {}
    local db = DragsHedgeFundDB
    local fresh=next(db)==nil
    if not isNum(db.pct) then db.pct = 20 end          -- % for new goals
    -- version 2: only confirmed cuts from new gains count. Start clean.
    if (db.version or 1) < 2 then
        db.saved, db.owed, db.log = 0, 0, {}
        if db.goal then db.goal.metSound = nil end
        db.version = 2
    end
    -- version 3: many goals, each with its own %, saved and owed
    if db.version < 3 then
        db.goals = {}
        local g = db.goal
        if g and isNum(g.amount) then
            local name = type(g.name) == "string" and g.name or "My goal"
            name = name:gsub(" by level %d+", ""):gsub(" in %d+ days?", "")
            db.goals[1] = { id = 1, name = name, amount = g.amount, pct = db.pct,
                            saved = isNum(db.saved) and db.saved or 0, owed = isNum(db.owed) and db.owed or 0,
                            metSound = g.metSound }
        end
        db.nextId = 2
        db.goal, db.saved, db.owed = nil, nil, nil
        db.version = 3
    end
    -- old builds kept pace data here; not used any more
    db.auto, db.days, db.trackStart, db.xpLvl, db.xpCur, db.xpMax = nil, nil, nil, nil, nil, nil
    db.goals = db.goals or {}
    db.nextId = db.nextId or (#db.goals + 1)
    db.log = db.log or {}
    if db.mini == nil then db.mini = true end
    if db.shown == nil then db.shown = not fresh end
    if db.miniLock == nil then db.miniLock = fresh end
    if db.miniTips == nil then db.miniTips = not fresh end
    if db.miniHideCombat == nil then db.miniHideCombat = fresh end
    if db.sound == nil then db.sound = not fresh end
    GG.db = db
    local available, adjusted = 100, false
    for _, g in ipairs(db.goals) do
        local old = g.pct
        g.pct = min(max(floor(isNum(g.pct) and g.pct or db.pct), 0), available)
        adjusted = adjusted or old ~= g.pct
        available = available - g.pct
    end
    if adjusted then
        print("|cffffd700Hedge Fund:|r goal percentages were reduced to keep the total at 100% or less.")
    end
    GG.RepairLedger()
end

-- Display presets never change goals, ledgers, scope or percentages.
function GG.StarterSetup(restore)
    local keys={mini=true,miniLock=true,miniTips=false,miniHideCombat=true,sound=false}
    if restore then
        if not GG.db.starterBackup then return false end
        for key,value in pairs(GG.db.starterBackup) do GG.db[key]=value.value end
        GG.db.starterBackup=nil
    else
        local old={}
        for key,value in pairs(keys) do old[key]={value=GG.db[key]};GG.db[key]=value end
        GG.db.starterBackup=GG.db.starterBackup or old
    end
    if GG.Refresh then GG.Refresh() end
    return true
end

------------------------------------------------------------ goals
function GG.Goals() return GG.db.goals end

function GG.TotalOwed()
    local s = 0
    for _, g in ipairs(GG.db.goals) do s = s + (g.owed or 0) end
    return s
end

function GG.TotalSaved()
    local s = 0
    for _, g in ipairs(GG.db.goals) do s = s + (g.saved or 0) end
    return s
end

function GG.AddGoal(name, gold, pct)
    local db = GG.db
    if type(name) ~= "string" or not name:match("%S") then return false, "Type a goal name." end
    if not isNum(gold) or gold <= 0 or gold > 999999 then return false, "Use 1 to 999999 gold." end
    pct = pct or min(db.pct, 100 - GG.TotalPct())
    if not isNum(pct) or pct < 0 or pct > 100 - GG.TotalPct() then
        return false, "All goal percentages together must be 100% or less."
    end
    name = name:sub(1, 48):gsub("|", "")
    if #db.goals >= GG.MAX_GOALS then return false, "You can have " .. GG.MAX_GOALS .. " goals." end
    for _, g in ipairs(db.goals) do
        if g.name == name then return false, "You already have that goal." end
    end
    db.goals[#db.goals + 1] = { id = db.nextId, name = name, amount = floor(gold * COPPER_PER_GOLD),
                                pct = pct or db.pct, saved = 0, owed = 0 }
    db.nextId = db.nextId + 1
    return true
end

function GG.RemoveGoal(id)
    local goals = GG.db.goals
    for i, g in ipairs(goals) do
        if g.id == id then
            for _, e in ipairs(GG.db.log) do
                if e.remaining then e.remaining[id] = nil; GG.UpdateEntry(e) end
            end
            table.remove(goals, i)
            return
        end
    end
end

function GG.PresetGold(p)
    local _, class = safe(UnitClass, "player")
    if GG.CLASS_MOUNT[class] then return GG.CLASS_PRESET_GOLD[p.key] or p.gold end
    return p.gold
end

function GG.PickPreset(key)
    for _, p in ipairs(GG.PRESETS) do
        if p.key == key then return GG.AddGoal(p.name, GG.PresetGold(p)) end
    end
end

-- Numbers for one goal.
function GG.GoalStatus(g)
    local s = {}
    s.need = max(g.amount - g.saved, 0)                       -- still need to save
    s.frac = g.amount > 0 and min(g.saved / g.amount, 1) or 1
    s.frac2 = g.amount > 0 and min((g.saved + g.owed) / g.amount, 1) or 1
    s.done = g.saved >= g.amount
    s.allIn = g.saved + g.owed >= g.amount                    -- no more cuts needed
    return s
end

------------------------------------------------------------ money
function GG.OnMoney(silent)
    local m = safe(GetMoney)
    if not isNum(m) then return end
    local db = GG.db
    if silent then
        -- loading screens: just remember the amount. 0 may mean "not loaded yet".
        db.lastMoney = m
        return
    end
    if isNum(db.lastMoney) and m > db.lastMoney then
        local gain = m - db.lastMoney
        local total, parts = GG.AllocateGain(gain)
        for _, g in ipairs(db.goals) do g.owed = g.owed + (parts[g.id] or 0) end
        if total > 0 then
            local log = db.log
            local remaining = {}
            for id, c in pairs(parts) do remaining[id] = c end
            log[#log + 1] = { t = time(), gain = gain, cut = total, parts = parts, remaining = remaining, owner = GG.characterKey }
            GG.TrimLog()
        end
        GG.lastGain, GG.lastPut, GG.lastAt = gain, total, GetTime()
    end
    -- spent into the gold you still have to put away? warn once
    local owed = GG.ReservedHere and GG.ReservedHere() or GG.TotalOwed()
    if not GG.mailInFlight and isNum(db.lastMoney) and m < db.lastMoney and owed > 0 and m < owed and db.lastMoney >= owed then
        print("|cffffd700Hedge Fund:|r |cffff3030You spent into your savings! You are short " ..
            GG.Money(owed - m) .. ".|r")
        if GG.db.sound and PlaySound and SOUNDKIT then safe(PlaySound, SOUNDKIT.RAID_WARNING or 8959) end
    end
    db.lastMoney = m
end

-- What you can spend: bag gold minus the gold you still have to put away.
-- Returns spend (can be below 0), bag gold.
function GG.CanSpend()
    local m = safe(GetMoney)
    if not isNum(m) then m = GG.db.lastMoney or 0 end
    return m - (GG.ReservedHere and GG.ReservedHere() or GG.TotalOwed()), m
end

-- "Can spend: 12g" in green, or "Spent into savings: 1g" in red
function GG.SpendText(short)
    local spend = GG.CanSpend()
    local money = GG.Money
    if spend >= 0 then return "|cff20ff20Can spend:|r " .. money(spend) end
    return "|cffff3030Spent into savings:|r " .. money(-spend)
end

-- You moved the gold somewhere safe (bank alt, mail...). Count it as saved.
-- amt: how much (default all of it). to: who it was mailed to, if mailed.
function GG.ConfirmSaved(amt, to, limits, postage)
    local db = GG.db
    local owed = GG.TotalOwed()
    if owed <= 0 or (amt ~= nil and not isNum(amt)) then return end
    amt = floor(min(amt or owed, owed))
    if amt <= 0 then return end
    local left, savedParts = amt, {}
    local feeLeft = postage or 0
    for _, g in ipairs(db.goals) do
        local available = min(g.owed, limits and (limits[g.id] or 0) or g.owed)
        local take = min(available, left)
        local fee = min(available - take, feeLeft)
        if take + fee > 0 then
            g.owed, g.saved = g.owed - take - fee, g.saved + take
            if take > 0 then savedParts[g.id] = take end
            left, feeLeft = left - take, feeLeft - fee
            local payment = take + fee
            for _, e in ipairs(db.log) do
                if e.remaining and payment > 0 and (not GG.EntryIsMine or GG.EntryIsMine(e)) then
                    local used = min(e.remaining[g.id] or 0, payment)
                    e.remaining[g.id] = (e.remaining[g.id] or 0) - used
                    payment = payment - used
                    GG.UpdateEntry(e)
                end
            end
            if g.saved >= g.amount and not g.metSound then
                g.metSound = true
                if GG.db.sound and PlaySound and SOUNDKIT then safe(PlaySound, SOUNDKIT.LEVEL_UP or 888) end
            end
        end
    end
    local actual = amt - left
    if actual <= 0 then return end
    db.log[#db.log + 1] = { t = time(), saved = actual, to = to, parts = savedParts, owner = GG.characterKey }
    GG.TrimLog()
    print("|cffffd700Hedge Fund:|r saved " .. GG.Money(actual) ..
        (to and (" (mailed to " .. to .. ")") or "") .. ". Total saved: " .. GG.Money(GG.TotalSaved()))
    return actual
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
    for _, e in ipairs(GG.db.log) do if e.cut and not e.done and (not GG.EntryIsMine or GG.EntryIsMine(e)) then n = n + 1 end end
    return n
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
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
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
        -- Zoning must not erase a gain observed before the next money event.
        GG.OnMoney()
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
    local a1, a2 = rest:match("^(%S*)%s*(%S*)")
    local num = tonumber(a1)
    local goal = GG.db.goals[tonumber(a2) or 1]
    local db = GG.db
    if cmd == "" then
        GG.Toggle()
    elseif cmd == "starter" or cmd == "restore" then
        GG.StarterSetup(cmd=="restore")
    elseif cmd == "goal" then
        GG.Show("setup")
    elseif cmd == "pct" and num then
        local count = max(#db.goals, 1)
        db.pct = min(max(floor(num), 0), floor(100 / count))
        for _, g in ipairs(db.goals) do g.pct = db.pct end
        print("|cffffd700Hedge Fund:|r every goal now saves " .. db.pct .. "% of each gain.")
    elseif (cmd == "add" or cmd == "set") and num then
        if not goal then print("|cffffd700Hedge Fund:|r no goal with that number.") return end
        local c = floor(num * COPPER_PER_GOLD)
        goal.saved = max(cmd == "add" and (goal.saved + c) or c, 0)
        print("|cffffd700Hedge Fund:|r " .. goal.name .. ": saved is now " .. GG.Money(goal.saved))
    elseif cmd == "characters" or cmd == "chars" then
        GG.Show("characters")
    elseif cmd == "shared" then
        GG.SetScope(true)
    elseif cmd == "personal" then
        GG.SetScope(false)
    elseif cmd == "transfer" then
        GG.SkipOwnTransfer()
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
        wipe(db.goals)
        for _, e in ipairs(db.log) do
            if e.cut then e.remaining = {}; GG.UpdateEntry(e) end
        end
        print("|cffffd700Hedge Fund:|r all goals cleared.")
    else
        print("|cffffd700Hedge Fund:|r /gg  - show or hide")
        print("  /gg goal  - add or change goals")
        print("  /gg mini  - show or hide the overlay")
        print("  /gg lock  - lock the overlay")
        print("  /gg scale 1.2  - overlay size")
        print("  /gg tips  - overlay tip on or off")
        print("  /gg pct 20  - every goal saves 20%")
        print("  /gg saved  - I put the gold away")
        print("  /gg add 10 2  - add 10g to goal 2 (fix)")
        print("  /gg set 50 1  - set goal 1 saved to 50g (fix)")
        print("  /gg reset  - clear all goals")
    end
    if GG.Refresh then GG.Refresh() end
end
