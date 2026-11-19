local _, GG = ...

-- Gold coach: one short line about the best thing to do for your gold right now.
-- It only reads your bags, your level, your professions and which window is open.
-- It never sells, buys or moves anything.
--
-- Rules follow the launch tips this was first built from (read 2026-11-10): Wowhead's
-- WoW: Forever riding guide, Icy Veins' level 40 mount tips and Mobalytics' launch tips:
-- fill every bag slot, take gathering professions, sell grays, and after level 20 train
-- only the spells you use until riding is paid for.

local GATHER = { [186] = "Mining", [182] = "Herbalism", [393] = "Skinning" }
local open = {}   -- merchant / trainer = true while that window is open
GG.coachOpen = open

local function num(v) return GG.isNum(v) and v or 0 end

-- Free slots in all your bags, and how many of the four bag slots hold no bag at all.
local function bagRoom()
    local C = C_Container
    if not (C and C.GetContainerNumSlots and C.GetContainerNumFreeSlots) then return nil, 0 end
    local free, emptyBags = 0, 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = num((GG.safe(C.GetContainerNumSlots, bag)))
        if bag >= 1 and slots == 0 then emptyBags = emptyBags + 1 end
        free = free + num((GG.safe(C.GetContainerNumFreeSlots, bag)))
    end
    return free, emptyBags
end

-- Still saving for riding? True while a goal that is not full yet exists.
local function stillSaving()
    for _, g in ipairs(GG.db and GG.db.goals or {}) do
        if num(g.saved) < num(g.amount) then return true end
    end
    return false
end

-- The one thing to do now, or nil when there is nothing special.
-- Second return: true when the line is already about gray items.
function GG.CoachAdvice()
    if not GG.db or GG.db.coach == false then return nil end
    local level = num((GG.safe(UnitLevel, "player")))
    local grays, grayValue = GG.grayCount or 0, GG.grayValue or 0
    if open.merchant and grays > 0 then
        return "|cffffd100Vendor is open:|r sell grays, " .. GG.Money(grayValue), true
    end
    if open.trainer and level >= 20 and stillSaving() then
        return "|cffffd100Trainer:|r learn only what you use"
    end
    local free, emptyBags = bagRoom()
    if free and free <= 2 and grays > 0 then
        return "|cffffd100Bags full:|r sell grays, " .. GG.Money(grayValue), true
    end
    if emptyBags > 0 and level >= 5 then
        return "|cffffd100Empty bag slot:|r buy a bag"
    end
    if level >= 5 then
        local gather, jobs, skinning = 0, 0, false
        for _, line in ipairs(GG.MyProfessions()) do
            if GATHER[line] then gather = gather + 1 end
            if line == 393 then skinning = true end
            if line ~= 185 and line ~= 356 and line ~= 129 then jobs = jobs + 1 end
        end
        if jobs < 2 then
            if not skinning then return "|cffffd100Open job slot:|r learn Skinning" end
            return "|cffffd100Open job slot:|r learn Mining or Herbalism"
        end
    end
    if grays >= 5 then
        return "|cff9d9d9dSell grays:|r " .. GG.Money(grayValue), true
    end
    return nil
end

local ev = CreateFrame("Frame")
local WINDOWS = {
    MERCHANT_SHOW = { "merchant", true }, MERCHANT_CLOSED = { "merchant", false },
    TRAINER_SHOW = { "trainer", true }, TRAINER_CLOSED = { "trainer", false },
}
for name in pairs(WINDOWS) do pcall(ev.RegisterEvent, ev, name) end
pcall(ev.RegisterEvent, ev, "PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function(_, e)
    local w = WINDOWS[e]
    if w then open[w[1]] = w[2] end
    if not GG.db then return end
    if e == "MERCHANT_SHOW" and GG.ScanGrays then GG.ScanGrays() end
    if GG.Refresh then GG.Refresh() end
end)
