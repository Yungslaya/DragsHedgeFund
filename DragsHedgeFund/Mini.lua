local _, GG = ...

-- Small overlay that can stay on screen. Drag to move, right-click opens the big window.
-- Same look as the big window (Theme.lua). Each goal shows its own share of every gain.
local W = 310
local ROW = 52       -- one goal row: name line, bar, share line
local L, R = 12, -12
local M

local function text(parent, size, color, justify)
    return GG.Text(parent, size, color, justify or "LEFT")
end

function GG.BuildMini()
    if M then return end
    local db = GG.db
    M = CreateFrame("Frame", "DragsHedgeFundMini", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    GG.mini = M
    M:SetSize(W, 150)
    M:SetFrameStrata("LOW")
    M:SetClampedToScreen(true)
    GG.Skin(M, 32, nil, { compact = true })
    local p = db.miniPos
    if p then M:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else M:SetPoint("TOPRIGHT", -220, -200) end
    M:SetScale(db.miniScale or 1)

    M:EnableMouse(true)
    M:SetMovable(true)
    M:RegisterForDrag("LeftButton")
    M:SetScript("OnDragStart", function(self) if not GG.db.miniLock then self:StartMoving() end end)
    M:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local a, _, b, x, y = self:GetPoint()
        GG.db.miniPos = { a, b, x, y }
    end)
    M:SetScript("OnMouseUp", function(_, btn) if btn == "RightButton" then GG.Toggle() end end)
    M:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Savings Pal", unpack(GG.C.gold))
        GameTooltip:AddLine("Right-click: big window", 1, 1, 1)
        GameTooltip:AddLine(GG.db.miniLock and "Locked. /gg lock to move." or "Drag to move", 1, 1, 1)
        GameTooltip:Show()
    end)
    M:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    -- header band: what you can spend
    M.spendLabel = text(M, 14, GG.C.gray)
    M.spendLabel:SetPoint("LEFT", M, "TOPLEFT", L, -17)
    M.spend = text(M, 18, GG.C.white, "RIGHT")
    M.spend:SetPoint("RIGHT", M, "TOPRIGHT", R, -17)

    -- what to put away now (all goals together) + Saved button
    M.owedL = text(M, 15, GG.C.gold)
    M.owedL:SetWordWrap(false)
    M.saveBtn = GG.FlatButton(M, "Saved", 66, 24, 14, function() GG.ConfirmSaved(); GG.Refresh() end)
    M.saveBtn:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Click when you put this gold away", 1, 1, 1)
        GameTooltip:Show()
    end)
    M.saveBtn:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    M.line = text(M, 14, GG.C.gray)
    M.line:SetWordWrap(false)

    -- one row per goal: name + saved/goal, bar, then "20% of gains" and its own set-aside
    M.rows = {}
    for i = 1, GG.MAX_GOALS do
        local r = {}
        r.name = text(M, 15, GG.C.gold)
        r.name:SetWordWrap(false)
        r.val = text(M, 14, GG.C.white, "RIGHT")
        r.bar = GG.GoalBar(M, W - 2 * L, 8, 12)
        r.bar.label:Hide()
        r.share = text(M, 13, GG.C.gray)
        r.aside = text(M, 13, GG.C.gold, "RIGHT")
        M.rows[i] = r
    end
    M.none = text(M, 14, GG.C.gray)
    M.none:SetPoint("TOPLEFT", L, -46)
    M.none:SetText("No goals. Right-click to add one.")

    M.tip = text(M, 13, GG.C.gray)

    -- its own 1-second clock, so it updates while the big window is closed
    local acc = 0
    M:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc >= 1 then acc = 0; GG.RefreshMini() end
    end)

    M:SetShown(db.mini and true or false)
    GG.RefreshMini()
end

function GG.ToggleMini(on)
    if not M then return end
    if on == nil then on = not M:IsShown() end
    GG.db.mini = on
    M:SetShown(on)
    GG.RefreshMini()
end

function GG.RefreshMini()
    if not M then return end
    local combat = GG.safe(InCombatLockdown) == true
    M:SetShown(GG.db.mini and #GG.db.goals > 0 and not (GG.db.miniHideCombat and combat) and true or false)
    if not M:IsShown() then return end
    local db = GG.db
    local goals = db.goals

    local spend = GG.CanSpend()
    M.spendLabel:SetText(spend < 0 and "|cffff7777Short on savings|r" or "Can spend")
    M.spend:SetText(GG.MoneyShort(math.abs(spend)))

    local y = -44
    local owed = GG.TotalOwed()
    M.owedL:SetShown(owed > 0)
    M.saveBtn:SetShown(owed > 0)
    if owed > 0 then
        M.owedL:ClearAllPoints()
        M.owedL:SetPoint("TOPLEFT", L, y)
        M.owedL:SetPoint("RIGHT", M, "RIGHT", -84, 0)
        M.owedL:SetText("Set aside  " .. GG.MoneyShort(owed))
        M.saveBtn:ClearAllPoints()
        M.saveBtn:SetPoint("TOPRIGHT", R, y + 4)
        y = y - 26
    end

    M.line:ClearAllPoints()
    M.line:SetPoint("TOPLEFT", L, y)
    M.line:SetPoint("RIGHT", M, "RIGHT", R, 0)
    M.line:SetText((GG.IsShared() and "Shared savings  " or "Saved  ") .. GG.MoneyShort(GG.TotalSaved()) ..
        "   |cff8a8478(" .. GG.TotalPct() .. "% of each gain)|r")
    y = y - 26

    M.none:SetShown(#goals == 0)
    for i, r in ipairs(M.rows) do
        local g = goals[i]
        local show = g ~= nil
        r.name:SetShown(show); r.val:SetShown(show); r.bar:SetShown(show)
        r.share:SetShown(show); r.aside:SetShown(show)
        if g then
            local st = GG.GoalStatus(g)
            r.name:ClearAllPoints();  r.name:SetPoint("TOPLEFT", L, y)
            r.name:SetPoint("RIGHT", r.val, "LEFT", -10, 0)   -- the name stops where the gold starts
            r.val:ClearAllPoints();   r.val:SetPoint("TOPRIGHT", R, y)
            r.bar:ClearAllPoints();   r.bar:SetPoint("TOPLEFT", L, y - 20)
            r.share:ClearAllPoints(); r.share:SetPoint("TOPLEFT", L, y - 32)
            r.aside:ClearAllPoints(); r.aside:SetPoint("TOPRIGHT", R, y - 32)
            r.name:SetText(g.name)
            if st.done then
                r.val:SetText("|cff73de99Goal met|r")
            else
                r.val:SetText(GG.MoneyShort(g.saved) .. " |cff8a8478/|r " .. GG.MoneyShort(g.amount))
            end
            r.bar.top:SetValue(st.frac)
            r.bar:SetValue(st.frac2)
            r.share:SetText(g.pct .. "% of each gain")
            local here = GG.MyGoalOwed(g)
            -- right side: gold waiting to be put away, or else how far along the goal is
            r.aside:SetText(here > 0 and ("Set aside  " .. GG.MoneyShort(here))
                or (st.done and "" or ("|cff8a8478" .. GG.PctText(st.frac) .. " saved|r")))
            y = y - ROW
        end
    end

    local tip = (db.miniTips ~= false) and GG.Tips()[1] or nil
    M.tip:ClearAllPoints()
    M.tip:SetPoint("TOPLEFT", L, y - 2)
    M.tip:SetPoint("RIGHT", M, "RIGHT", R, 0)
    M.tip:SetText(tip and tip:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or "")
    -- grow to fit the tip (it can wrap to 2 lines)
    local th = tip and M.tip.GetStringHeight and M.tip:GetStringHeight()
    if type(th) ~= "number" or th <= 0 then th = 16 end
    M:SetHeight(-y + (tip and (th + 10) or 6))
end

-- hook into the rest of the addon
do
    local build, refresh = GG.BuildUI, GG.Refresh
    function GG.BuildUI() build(); GG.BuildMini() end
    function GG.Refresh() refresh(); GG.RefreshMini() end
end
