local _, GG = ...
local min, max, floor = math.min, math.max, math.floor

local LEDGER = { goals = true, log = true, nextId = true, pct = true, version = true }
local function sum(goals, field)
    local n = 0
    for _, g in ipairs(goals or {}) do n = n + (g[field] or 0) end
    return n
end

function GG.IsShared()
    return GG.realmAccount ~= nil and GG.activeScope == "shared"
end

function GG.EntryIsMine(e)
    return not GG.IsShared() or e.owner == GG.characterKey
end

function GG.SourceOwed(ledger, key, goalId)
    local n = 0
    for _, e in ipairs(ledger.log) do
        if e.cut and e.owner == key then
            for id, c in pairs(e.remaining or {}) do
                if not goalId or id == goalId then n = n + c end
            end
        end
    end
    return n
end

function GG.MyGoalOwed(g)
    if GG.IsShared() then return GG.SourceOwed(GG.realmAccount.shared, GG.characterKey, g.id) end
    return g.owed
end

function GG.ReservedHere()
    if not GG.personal then return GG.TotalOwed() end
    return sum(GG.personal.goals, "owed") + GG.SourceOwed(GG.realmAccount.shared, GG.characterKey)
end

function GG.RecordWallet()
    if not GG.account or not GG.characterKey then return end
    local money = GG.safe(GetMoney)
    if not GG.isNum(money) then return end
    local row = GG.account.characters[GG.characterKey] or {}
    row.name, row.realm = GG.characterName, GG.characterRealm
    row.money, row.seen = money, time()
    row.personalOwed = sum(GG.personal.goals, "owed")
    row.personalSaved = sum(GG.personal.goals, "saved")
    GG.account.characters[GG.characterKey] = row
end

function GG.CharacterRows()
    GG.RecordWallet()
    local rows, total = {}, 0
    for key, row in pairs(GG.account.characters) do
        rows[#rows + 1] = { key = key, name = row.name, realm = row.realm,
            money = row.money or 0, seen = row.seen or 0, personalOwed = row.personalOwed or 0,
            personalSaved = row.personalSaved or 0 }
        total = total + (row.money or 0)
    end
    table.sort(rows, function(a, b)
        if a.key == GG.characterKey then return true end
        if b.key == GG.characterKey then return false end
        return a.name .. a.realm < b.name .. b.realm
    end)
    return rows, total
end

local function selectLedger()
    local personal = GG.personal
    local ledger = GG.IsShared() and GG.realmAccount.shared or personal
    GG.db = setmetatable({}, {
        __index = function(_, k) return LEDGER[k] and ledger[k] or personal[k] end,
        __newindex = function(_, k, v)
            if LEDGER[k] then ledger[k] = v else personal[k] = v end
        end,
    })
    GG.db.lastMoney = GG.safe(GetMoney)
end

function GG.SetScope(shared)
    if GG.OnMoney then GG.OnMoney() end
    GG.personal.scope = shared and "shared" or "personal"
    GG.activeScope = GG.personal.scope
    -- New alts start with shared goals after sharing is first enabled.
    if shared then GG.realmAccount.mode = "shared" end
    selectLedger()
    GG.lastAt = nil
    GG.RecordWallet()
    if GG.CancelMailDraft then GG.CancelMailDraft() end
    if GG.Show then GG.Show("main") end
end

local init = GG.InitDB
function GG.InitDB()
    -- The original per-character store stays intact, including all old goals.
    GG.realmAccount, GG.activeScope = nil, nil
    init()
    GG.personal = DragsHedgeFundDB
    local name, realm = GG.safe(UnitFullName, "player")
    name = name or GG.safe(UnitName, "player") or "Player"
    realm = type(realm) == "string" and realm ~= "" and realm or GG.safe(GetRealmName) or "Unknown realm"
    GG.characterName, GG.characterRealm = name, realm
    local guid = GG.safe(UnitGUID, "player")
    GG.characterKey = type(guid) == "string" and guid or (realm .. ":" .. name)
    DragsHedgeFundAccountDB = DragsHedgeFundAccountDB or { characters = {}, realms = {} }
    GG.account = DragsHedgeFundAccountDB
    GG.account.characters = GG.account.characters or {}
    GG.account.realms = GG.account.realms or {}
    local data = GG.account.realms[realm]
    if not data then
        data = { mode = "personal", shared = { version = 3, goals = {}, log = {}, nextId = 1, pct = 20 } }
        GG.account.realms[realm] = data
    end
    GG.realmAccount = data
    GG.activeScope = GG.personal.scope or data.mode
    GG.db = data.shared
    GG.RepairLedger()
    selectLedger()
    GG.RecordWallet()
end

local onMoney = GG.OnMoney
function GG.OnMoney(silent)
    local m = GG.safe(GetMoney)
    local skip = GG.personal and GG.personal.skipNextGain
    if not silent and skip and skip >= time() and GG.isNum(m) and
        GG.isNum(GG.db.lastMoney) and m > GG.db.lastMoney then
        -- Explicitly armed for a transfer of the player's own gold.
        onMoney(true)
        GG.personal.skipNextGain = nil
        GG.lastAt = nil
        print("|cffffd700Hedge Fund:|r own transfer skipped. Normal tracking is back on.")
    else
        if skip and skip < time() then GG.personal.skipNextGain = nil end
        onMoney(silent)
    end
    GG.RecordWallet()
end

function GG.SkipOwnTransfer()
    GG.personal.skipNextGain = time() + 1800
    print("|cffffd700Hedge Fund:|r the next gold gain will be ignored. Collect your own transfer now.")
end

local totalOwed, confirmSaved, removeGoal = GG.TotalOwed, GG.ConfirmSaved, GG.RemoveGoal
function GG.TotalOwed()
    if GG.IsShared() then return GG.SourceOwed(GG.realmAccount.shared, GG.characterKey) end
    return totalOwed()
end

function GG.ConfirmSaved(amt, to, limits, postage)
    if GG.IsShared() then
        local capped = {}
        for _, g in ipairs(GG.db.goals) do
            capped[g.id] = min(GG.MyGoalOwed(g), limits and (limits[g.id] or 0) or math.huge)
        end
        limits = capped
    end
    local actual = confirmSaved(amt, to, limits, postage)
    GG.RecordWallet()
    return actual
end

function GG.RemoveGoal(id)
    removeGoal(id)
    GG.RecordWallet()
end

function GG.ShareGoal(id)
    if GG.IsShared() then return false, "This goal is already shared." end
    local shared, old = GG.realmAccount.shared
    if #shared.goals >= GG.MAX_GOALS then return false, "Shared goals are full." end
    for _, g in ipairs(GG.personal.goals) do if g.id == id then old = g break end end
    if not old then return false, "Goal not found." end
    for _, g in ipairs(shared.goals) do
        if g.name == old.name then return false, "A shared goal already has that name." end
    end
    local pct = min(old.pct, max(100 - sum(shared.goals, "pct"), 0))
    local newId = shared.nextId
    shared.nextId = newId + 1
    shared.goals[#shared.goals + 1] = { id = newId, name = old.name, amount = old.amount,
        pct = pct, saved = old.saved, owed = old.owed, metSound = old.metSound }
    if old.owed > 0 then
        local remaining = { [newId] = old.owed }
        shared.log[#shared.log + 1] = { t = time(), gain = 0, cut = old.owed,
            parts = { [newId] = old.owed }, remaining = remaining, owner = GG.characterKey, carried = true }
    end
    removeGoal(id)
    GG.SetScope(true)
    return true
end

-- Build a preview, never reserve the same existing balance twice for the same goal.
function GG.PoolPlan()
    GG.RecordWallet()
    local shared, wallets, raw, stored = GG.realmAccount.shared, {}, 0, 0
    local signature = {}
    for key, row in pairs(GG.account.characters) do
        if row.realm == GG.characterRealm then
            local free = max((row.money or 0) - (row.personalOwed or 0) -
                GG.SourceOwed(shared, key), 0)
            wallets[#wallets + 1] = { key = key, free = free }
            raw = raw + free
            stored = stored + (row.personalSaved or 0)
        end
    end
    stored = stored + sum(shared.goals, "saved")
    -- Stored savings may already be held by a listed bank alt. Do not reserve them again.
    local usable = max(raw - stored, 0)
    signature[#signature + 1] = usable .. ":" .. stored
    local ratio = raw > 0 and usable / raw or 0
    table.sort(wallets, function(a,b) return a.key < b.key end)
    local remaining, plan = {}, { entries = {}, total = 0, available = usable, characters = #wallets }
    for _, g in ipairs(shared.goals) do
        remaining[g.id] = max(g.amount - g.saved - g.owed, 0)
        signature[#signature + 1] = g.id .. ":" .. g.amount .. ":" .. g.pct .. ":" .. g.saved .. ":" .. g.owed
    end
    local availableLeft = usable
    for _, w in ipairs(wallets) do
        local base = min(floor(w.free * ratio), availableLeft)
        availableLeft = availableLeft - base
        local budget = base
        local parts, total = {}, 0
        signature[#signature + 1] = w.key .. ":" .. w.free
        for _, g in ipairs(shared.goals) do
            local seeded = g.seeded and g.seeded[w.key]
            signature[#signature + 1] = seeded and "1" or "0"
            local cut = not seeded and min(floor(base * g.pct / 100 + 0.5), remaining[g.id], budget) or 0
            parts[g.id], total = cut, total + cut
            remaining[g.id], budget = remaining[g.id] - cut, budget - cut
        end
        plan.entries[#plan.entries + 1] = { owner = w.key, gain = base, parts = parts, cut = total }
        plan.total = plan.total + total
    end
    plan.signature = table.concat(signature, "|")
    return plan
end

function GG.ApplyPool(plan)
    if not GG.IsShared() then return false, "Switch to Shared first." end
    if not plan or GG.PoolPlan().signature ~= plan.signature then
        return false, "Balances changed. Preview the amount again."
    end
    if plan.total <= 0 then return false, "Nothing new to reserve." end
    local ledger = GG.realmAccount.shared
    for _, e in ipairs(plan.entries) do
        local rem = {}
        for _, g in ipairs(ledger.goals) do
            g.seeded = g.seeded or {}
            -- A zero balance can be refreshed later; it has not been used yet.
            if e.gain > 0 and g.pct > 0 then g.seeded[e.owner] = true end
            local c = e.parts[g.id] or 0
            g.owed, rem[g.id] = g.owed + c, c
        end
        if e.cut > 0 then
            ledger.log[#ledger.log + 1] = { t = time(), gain = e.gain, cut = e.cut, parts = e.parts,
                remaining = rem, owner = e.owner, pooled = true }
        end
    end
    GG.TrimLog()
    GG.RecordWallet()
    return true, plan.total
end

local logout = CreateFrame("Frame")
logout:RegisterEvent("PLAYER_LOGOUT")
logout:SetScript("OnEvent", function() if GG.account then GG.RecordWallet() end end)
