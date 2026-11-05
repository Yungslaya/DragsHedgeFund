local _, GG = ...

-- Small overlay that can stay on screen. Drag to move, right-click opens the big window.
local FONT = "Fonts\\FRIZQT__.TTF"
local W = 270
local ROW = 36       -- one goal row
local M

local function text(parent, size, r, g, b, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size, "OUTLINE")
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetShadowOffset(1, -1)
    return fs
end

function GG.BuildMini()
    if M then return end
    local db = GG.db
    M = CreateFrame("Frame", "DragsHedgeFundMini", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    GG.mini = M
    M:SetSize(W, 150)
    M:SetFrameStrata("LOW")
    M:SetClampedToScreen(true)
    M:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    M:SetBackdropColor(0, 0, 0, 0.75)
    M:SetBackdropBorderColor(0.8, 0.65, 0.2, 1)
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
        GameTooltip:AddLine("Drags Hedge Fund", 1, 0.82, 0)
        GameTooltip:AddLine("Right-click: big window", 1, 1, 1)
        GameTooltip:AddLine(GG.db.miniLock and "Locked. /gg lock to move." or "Drag to move", 1, 1, 1)
        GameTooltip:Show()
    end)
    M:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    local L, R = 12, -12
    -- top: what to put away + Saved button
    M.owedL = text(M, 15)
    M.owedL:SetPoint("TOPLEFT", L, -12)
    M.saveBtn = CreateFrame("Button", nil, M, "UIPanelButtonTemplate")
    M.saveBtn:SetSize(64, 22)
    M.saveBtn:SetPoint("TOPRIGHT", R + 2, -8)
    M.saveBtn:SetText("Saved")
    local bfs = M.saveBtn:GetFontString()
    if bfs then bfs:SetFont(FONT, 13, "") end
    M.saveBtn:SetScript("OnClick", function() GG.ConfirmSaved(); GG.Refresh() end)
    M.saveBtn:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Click when you put this gold away", 1, 1, 1)
        GameTooltip:Show()
    end)
    M.saveBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    M.line = text(M, 14)
    M.line:SetPoint("TOPLEFT", L, -34)
    M.line:SetPoint("RIGHT", M, "RIGHT", R, 0)
    M.line:SetWordWrap(false)

    -- one row per goal: name + saved/goal, then a bar
    M.rows = {}
    for i = 1, GG.MAX_GOALS do
        local y = -56 - (i - 1) * ROW
        local r = {}
        r.name = text(M, 13, 1, 0.82, 0)
        r.name:SetPoint("TOPLEFT", L, y)
        r.name:SetWidth(120)
        r.name:SetWordWrap(false)
        r.val = text(M, 13, 1, 1, 1, "RIGHT")
        r.val:SetPoint("TOPRIGHT", R, y)
        r.bar = GG.GoalBar(M, W - 2 * L, 14, 11)
        r.bar:SetPoint("TOPLEFT", L, y - 16)
        M.rows[i] = r
    end
    M.none = text(M, 14, 0.8, 0.8, 0.8)
    M.none:SetPoint("TOPLEFT", L, -58)
    M.none:SetText("No goals. Right-click to add one.")

    M.tip = text(M, 13, 0.85, 0.85, 0.85)
    M.tip:SetPoint("RIGHT", M, "RIGHT", R, 0)

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
    if not M or not M:IsShown() then return end
    local db = GG.db
    local goals = db.goals

    local owed = GG.TotalOwed()
    if owed > 0 then
        M.owedL:SetText("|cffffd100To put away|r " .. GG.MoneyShort(owed))
        M.saveBtn:Show()
    else
        M.owedL:SetText("|cffaaaaaaNothing to put away|r")
        M.saveBtn:Hide()
    end

    local now = GetTime()
    if GG.lastAt and now - GG.lastAt < 20 and (GG.lastPut or 0) > 0 then
        M.line:SetText("|cff20ff20+|r" .. GG.Money(GG.lastGain) .. "  |cffffd100put away|r " .. GG.Money(GG.lastPut))
    else
        M.line:SetText("|cffffd100Total saved|r " .. GG.MoneyShort(GG.TotalSaved()))
    end

    M.none:SetShown(#goals == 0)
    for i, r in ipairs(M.rows) do
        local g = goals[i]
        local show = g ~= nil
        r.name:SetShown(show); r.val:SetShown(show); r.bar:SetShown(show)
        if g then
            local st = GG.GoalStatus(g)
            r.name:SetText(g.name)
            if st.done then
                r.val:SetText("|cff20ff20GOAL MET!|r")
            else
                r.val:SetText(GG.MoneyShort(g.saved) .. " |cffaaaaaa/|r " .. GG.MoneyShort(g.amount))
            end
            r.bar.top:SetValue(st.frac)
            r.bar:SetValue(st.frac2)
            r.bar.label:SetText(GG.PctText(st.frac))
        end
    end

    local y = -56 - math.max(#goals, 1) * ROW
    local tip = (db.miniTips ~= false) and GG.Tips()[1] or nil
    M.tip:ClearAllPoints()
    M.tip:SetPoint("TOPLEFT", 12, y - 2)
    M.tip:SetPoint("RIGHT", M, "RIGHT", -12, 0)
    M.tip:SetText(tip or "")
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
