local _, GG = ...

-- Small overlay that can stay on screen. Drag to move, right-click opens the big window.
local FONT = "Fonts\\FRIZQT__.TTF"
local W = 260
local floor = math.floor
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
    M.goal = text(M, 14, 1, 0.82, 0)
    M.goal:SetPoint("TOPLEFT", L, -10)
    M.goal:SetPoint("RIGHT", M, "RIGHT", -50, 0)
    M.goal:SetWordWrap(false)
    M.pct = text(M, 14, 1, 1, 1, "RIGHT")
    M.pct:SetPoint("TOPRIGHT", R, -10)

    M.saved = text(M, 22)
    M.saved:SetPoint("TOPLEFT", L, -30)
    M.of = text(M, 14, 0.8, 0.8, 0.8, "RIGHT")
    M.of:SetPoint("TOPRIGHT", R, -36)

    local bar = CreateFrame("StatusBar", nil, M)
    bar:SetPoint("TOPLEFT", L, -58)
    bar:SetPoint("TOPRIGHT", R, -58)
    bar:SetHeight(14)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(1, 0.75, 0)
    bar:SetMinMaxValues(0, 1)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.15, 0.15, 1)
    M.bar = bar

    M.needL = text(M, 14, 1, 0.82, 0)
    M.needL:SetPoint("TOPLEFT", L, -80)
    M.need = text(M, 14, 1, 1, 1, "RIGHT")
    M.need:SetPoint("TOPRIGHT", R, -80)

    M.owedL = text(M, 14)
    M.owedL:SetPoint("TOPLEFT", L, -102)
    M.saveBtn = CreateFrame("Button", nil, M, "UIPanelButtonTemplate")
    M.saveBtn:SetSize(64, 22)
    M.saveBtn:SetPoint("TOPRIGHT", R + 2, -98)
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
    M.line:SetPoint("TOPLEFT", L, -124)
    M.line:SetPoint("RIGHT", M, "RIGHT", R, 0)
    M.line:SetWordWrap(false)

    M.tip = text(M, 13, 0.85, 0.85, 0.85)
    M.tip:SetPoint("TOPLEFT", L, -144)
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
    local st = GG.Status()
    local g = st.goal
    if not g then
        M.goal:SetText("Drags Hedge Fund")
        M.pct:SetText("")
        M.saved:SetText("No goal yet")
        M.of:SetText("")
        M.bar:SetValue(0)
        M.needL:SetText("Right-click to pick one"); M.need:SetText("")
        M.line:SetText(""); M.tip:SetText("")
        M.owedL:SetText(""); M.saveBtn:Hide()
        M:SetHeight(102)
        return
    end

    M.goal:SetText(g.name)
    M.pct:SetText(GG.PctText(st.frac))
    M.saved:SetText(GG.Money(st.saved))
    M.of:SetText("of " .. GG.Money(st.amount))
    M.bar:SetValue(st.frac)

    if st.done then
        M.needL:SetText("|cff20ff20GOAL MET!|r")
        M.need:SetText("Go buy it")
    elseif st.allIn then
        M.needL:SetText("Put away the rest!")
        M.need:SetText("")
    else
        M.needL:SetText("Still need")
        M.need:SetText(GG.Money(st.need))
    end

    if st.owed > 0 then
        M.owedL:SetText("|cffffd100To put away|r " .. GG.MoneyShort(st.owed))
        M.saveBtn:Show()
    else
        M.owedL:SetText("|cffaaaaaaNothing to put away|r")
        M.saveBtn:Hide()
    end

    local now = GetTime()
    if GG.lastAt and now - GG.lastAt < 20 and (GG.lastPut or 0) > 0 then
        M.line:SetText("|cff20ff20+|r" .. GG.Money(GG.lastGain) .. "  |cffffd100put away|r " .. GG.Money(GG.lastPut))
    elseif not st.done then
        M.line:SetText("Saving " .. db.pct .. "% of each gain")
    else
        M.line:SetText("")
    end

    local tip = (db.miniTips ~= false) and GG.Tips()[1] or nil
    M.tip:SetText(tip or "")
    -- grow to fit the tip (it can wrap to 2 lines)
    local th = tip and M.tip.GetStringHeight and M.tip:GetStringHeight()
    if type(th) ~= "number" or th <= 0 then th = 16 end
    M:SetHeight(tip and (148 + th + 6) or 146)
end

-- hook into the rest of the addon
do
    local build, refresh = GG.BuildUI, GG.Refresh
    function GG.BuildUI() build(); GG.BuildMini() end
    function GG.Refresh() refresh(); GG.RefreshMini() end
end
