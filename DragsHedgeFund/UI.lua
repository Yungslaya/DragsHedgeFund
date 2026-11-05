local _, GG = ...

local FONT = "Fonts\\FRIZQT__.TTF"
local W = 380
local CARD = 66      -- height of one goal card
local floor, max, min = math.floor, math.max, math.min

local function text(parent, size, r, g, b, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size, "OUTLINE")
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:SetJustifyH(justify or "CENTER")
    fs:SetShadowOffset(1, -1)
    return fs
end

local function button(parent, label, w, h, size, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h)
    b:SetText(label)
    local fs = b:GetFontString()
    if fs then fs:SetFont(FONT, size or 14, "") end
    b:SetScript("OnClick", onClick)
    return b
end

local function editBox(parent, w, numeric, maxLetters)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(w, 28)
    e:SetAutoFocus(false)
    e:SetNumeric(numeric and true or false)
    e:SetMaxLetters(maxLetters or 6)
    e:SetFont(FONT, 15, "")
    e:SetJustifyH(numeric and "CENTER" or "LEFT")
    e:SetScript("OnEnterPressed", e.ClearFocus)
    e:SetScript("OnEscapePressed", e.ClearFocus)
    return e
end

-- bright bar = saved, dim bar behind it = waiting to be put away
local function goalBar(parent, w, h, size)
    local back = CreateFrame("StatusBar", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    back:SetSize(w, h)
    back:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    back:SetStatusBarColor(0.55, 0.42, 0.1)
    back:SetMinMaxValues(0, 1)
    local bg = back:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)
    if back.SetBackdrop then
        back:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
                           insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    end
    local bar = CreateFrame("StatusBar", nil, back)
    bar:SetAllPoints()
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(1, 0.75, 0)
    bar:SetMinMaxValues(0, 1)
    back.top = bar
    back.label = text(bar, size or 14)
    back.label:SetPoint("CENTER")
    return back
end
GG.GoalBar = goalBar

local F -- the window
local confirm = { id = nil, at = 0 }   -- two-click Remove

------------------------------------------------------------ main view
local function BuildMain(m)
    m.owedLabel = text(m, 15, 1, 0.82, 0)
    m.owedLabel:SetPoint("TOP", 0, -34)
    m.owed = text(m, 24)
    m.owed:SetPoint("TOP", 0, -52)
    m.saveBtn = button(m, "I saved it", 140, 28, 15, function() GG.ConfirmSaved(); GG.Refresh() end)
    m.saveBtn:SetPoint("TOP", 0, -82)
    m.gain = text(m, 15)
    m.gain:SetPoint("TOP", 0, -116)
    m.gain:SetWidth(W - 40)

    m.none = text(m, 16, 0.8, 0.8, 0.8)
    m.none:SetPoint("TOP", 0, -160)
    m.none:SetText("No goals yet. Click Goals to add one.")

    m.cards = {}
    for i = 1, GG.MAX_GOALS do
        local c = CreateFrame("Frame", nil, m)
        c:SetSize(W - 40, CARD - 6)
        c:SetPoint("TOP", 0, -142 - (i - 1) * CARD)
        c.name = text(c, 16, 1, 0.82, 0, "LEFT")
        c.name:SetPoint("TOPLEFT", 4, 0)
        c.name:SetPoint("RIGHT", c, "RIGHT", -60, 0)
        c.name:SetWordWrap(false)
        c.pct = text(c, 15, 1, 1, 1, "RIGHT")
        c.pct:SetPoint("TOPRIGHT", -4, 0)
        c.bar = goalBar(c, W - 48, 22, 14)
        c.bar:SetPoint("TOP", 0, -20)
        c.need = text(c, 14, 1, 1, 1, "LEFT")
        c.need:SetPoint("TOPLEFT", 4, -46)
        c.owed = text(c, 14, 0.8, 0.8, 0.8, "RIGHT")
        c.owed:SetPoint("TOPRIGHT", -4, -46)
        m.cards[i] = c
    end

    m.tipHead = text(m, 16, 1, 0.82, 0, "LEFT")
    m.tipHead:SetText("Tips")
    m.tips = {}
    for i = 1, 2 do
        local t = text(m, 14, 1, 1, 1, "LEFT")
        t:SetWidth(W - 54)
        m.tips[i] = t
    end

    local bw, gap = 80, 6
    local x = (W - (bw * 4 + gap * 3)) / 2
    local function bottom(label, f)
        local b = button(m, label, bw, 26, 14, f)
        b:SetPoint("BOTTOMLEFT", x, 18)
        x = x + bw + gap
        return b
    end
    m.goalBtn = bottom("Goals", function() GG.Show("setup") end)
    m.listBtn = bottom("List", function() GG.listPage = 1; GG.Show("list") end)
    m.miniBtn = bottom("Overlay", function() GG.ToggleMini() end)
    m.tipBtn = bottom("Tip", function() GG.tipStep = GG.tipStep + 1; GG.Refresh() end)
end

------------------------------------------------------------ list view (every gain and every save)
local ROWS = 12
local function BuildList(l)
    l.head = text(l, 19, 1, 0.82, 0)
    l.head:SetPoint("TOP", 0, -36)
    l.head:SetText("Gold list")

    l.owed = text(l, 17)
    l.owed:SetPoint("TOP", 0, -62)
    l.saveBtn = button(l, "I saved it", 140, 28, 15, function() GG.ConfirmSaved(); GG.Refresh() end)
    l.saveBtn:SetPoint("TOP", 0, -88)

    l.colA = text(l, 13, 1, 0.82, 0, "LEFT");  l.colA:SetPoint("TOPLEFT", 22, -126);  l.colA:SetText("When")
    l.colB = text(l, 13, 1, 0.82, 0, "RIGHT"); l.colB:SetPoint("TOPRIGHT", -130, -126); l.colB:SetText("Gained")
    l.colC = text(l, 13, 1, 0.82, 0, "RIGHT"); l.colC:SetPoint("TOPRIGHT", -22, -126); l.colC:SetText("Put away")

    l.rows = {}
    for i = 1, ROWS do
        local y = -126 - i * 21
        local r = {}
        r.a = text(l, 13, 0.75, 0.75, 0.75, "LEFT");  r.a:SetPoint("TOPLEFT", 22, y)
        r.b = text(l, 14, 1, 1, 1, "RIGHT");          r.b:SetPoint("TOPRIGHT", -130, y)
        r.c = text(l, 14, 1, 1, 1, "RIGHT");          r.c:SetPoint("TOPRIGHT", -22, y)
        l.rows[i] = r
    end
    l.empty = text(l, 15, 0.8, 0.8, 0.8)
    l.empty:SetPoint("TOP", 0, -170)
    l.empty:SetText("No gold gained yet")

    l.page = text(l, 13, 0.8, 0.8, 0.8)
    l.page:SetPoint("BOTTOM", 0, 56)
    l.newer = button(l, "Newer", 80, 24, 13, function() GG.listPage = max((GG.listPage or 1) - 1, 1); GG.Refresh() end)
    l.newer:SetPoint("BOTTOMLEFT", 22, 50)
    l.older = button(l, "Older", 80, 24, 13, function() GG.listPage = (GG.listPage or 1) + 1; GG.Refresh() end)
    l.older:SetPoint("BOTTOMRIGHT", -22, 50)
    l.back = button(l, "Back", 90, 26, 14, function() GG.Show("main") end)
    l.back:SetPoint("BOTTOM", 0, 18)
end

------------------------------------------------------------ goals screen (add, remove, set %)
local ROW_H = 36
local function BuildSetup(s)
    s.head = text(s, 19, 1, 0.82, 0)
    s.head:SetPoint("TOP", 0, -36)
    s.head:SetText("Your goals")
    s.none = text(s, 15, 0.8, 0.8, 0.8)
    s.none:SetPoint("TOP", 0, -70)
    s.none:SetText("No goals yet. Add one below.")

    s.rows = {}
    for i = 1, GG.MAX_GOALS do
        local r = CreateFrame("Frame", nil, s)
        r:SetSize(W - 40, ROW_H - 2)
        r:SetPoint("TOPLEFT", 20, -60 - (i - 1) * ROW_H)
        r.name = text(r, 14, 1, 0.82, 0, "LEFT")
        r.name:SetPoint("TOPLEFT", 2, -2)
        r.name:SetWidth(170)
        r.name:SetWordWrap(false)
        r.amt = text(r, 13, 0.85, 0.85, 0.85, "LEFT")
        r.amt:SetPoint("TOPLEFT", 2, -19)
        r.minus = button(r, "-", 26, 24, 16, function()
            local g = r.goal; if g then g.pct = max(g.pct - 5, 5); GG.Refresh() end
        end)
        r.minus:SetPoint("LEFT", r, "LEFT", 178, 0)
        r.pct = text(r, 15)
        r.pct:SetPoint("LEFT", r.minus, "RIGHT", 2, 0)
        r.pct:SetWidth(42)
        r.plus = button(r, "+", 26, 24, 16, function()
            local g = r.goal; if g then g.pct = min(g.pct + 5, 100); GG.Refresh() end
        end)
        r.plus:SetPoint("LEFT", r.pct, "RIGHT", 2, 0)
        -- two clicks to remove, so a stray click can't delete a goal
        r.del = button(r, "Remove", 66, 24, 12, function(self)
            local g = r.goal
            if not g then return end
            if confirm.id == g.id then
                GG.RemoveGoal(g.id); confirm.id = nil; s.msg:SetText("")
            else
                confirm.id, confirm.at = g.id, GetTime()
            end
            GG.Refresh()
        end)
        r.del:SetPoint("LEFT", r.plus, "RIGHT", 8, 0)
        s.rows[i] = r
    end

    local y = -60 - GG.MAX_GOALS * ROW_H - 6
    s.add = text(s, 17, 1, 0.82, 0)
    s.add:SetPoint("TOP", 0, y)
    s.add:SetText("Add a goal")
    s.presets = {}
    for i, p in ipairs(GG.PRESETS) do
        local b = button(s, p.name, 280, 28, 14, function()
            local ok, why = GG.PickPreset(p.key)
            s.msg:SetText(ok and "" or why)
            GG.Refresh()
        end)
        b:SetPoint("TOP", 0, y - 22 - (i - 1) * 32)
        b.preset = p
        s.presets[i] = b
    end
    y = y - 22 - #GG.PRESETS * 32
    s.note = text(s, 12, 0.8, 0.8, 0.8)
    s.note:SetPoint("TOP", 0, y)

    local nl = text(s, 14, 1, 1, 1, "RIGHT")
    nl:SetPoint("TOPRIGHT", s, "TOPLEFT", 82, y - 24)
    nl:SetText("Name:")
    s.name = editBox(s, 150, false, 30)
    s.name:SetPoint("TOPLEFT", 92, y - 18)
    local gl = text(s, 14, 1, 1, 1, "RIGHT")
    gl:SetPoint("TOPRIGHT", s, "TOPLEFT", 82, y - 56)
    gl:SetText("Gold:")
    s.gold = editBox(s, 80, true, 6)
    s.gold:SetPoint("TOPLEFT", 92, y - 50)
    s.addBtn = button(s, "Add", 80, 28, 15, function()
        local gold = tonumber(s.gold:GetText() or "")
        local name = (s.name:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if not gold or gold <= 0 then s.msg:SetText("Type how much gold.") return end
        if name == "" then name = "Save " .. GG.Commas(gold) .. "g" end
        local ok, why = GG.AddGoal(name, gold)
        if not ok then s.msg:SetText(why) return end
        s.msg:SetText("")
        s.name:SetText(""); s.gold:SetText("")
        GG.Refresh()
    end)
    s.addBtn:SetPoint("LEFT", s.gold, "RIGHT", 14, 0)

    s.msg = text(s, 14, 1, 0.3, 0.3)
    s.msg:SetPoint("TOP", 0, y - 86)
    s.countNote = text(s, 13, 0.8, 0.8, 0.8)
    s.countNote:SetPoint("TOP", 0, y - 106)
    s.countNote:SetText("Gold you have now is not counted.")

    s.back = button(s, "Done", 90, 26, 14, function() GG.Show("main") end)
    s.back:SetPoint("BOTTOM", 0, 18)
end

------------------------------------------------------------ window
function GG.BuildUI()
    if F then return end
    local db = GG.db
    F = CreateFrame("Frame", "DragsHedgeFundFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    GG.frame = F
    F:SetSize(W, 480)
    F:SetFrameStrata("MEDIUM")
    F:SetClampedToScreen(true)
    F:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    local p = db.pos
    if p then F:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else F:SetPoint("RIGHT", -80, 40) end
    F:EnableMouse(true)
    F:SetMovable(true)
    F:RegisterForDrag("LeftButton")
    F:SetScript("OnDragStart", F.StartMoving)
    F:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local a, _, b, x, y = self:GetPoint()
        db.pos = { a, b, x, y }
    end)

    local header = F:CreateTexture(nil, "ARTWORK")
    header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    header:SetSize(280, 64)
    header:SetPoint("TOP", 0, 12)
    local title = text(F, 15, 1, 0.82, 0)
    title:SetPoint("TOP", header, "TOP", 0, -14)
    title:SetText("Drags Hedge Fund")

    local close = CreateFrame("Button", nil, F, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() GG.Hide() end)

    F.main = CreateFrame("Frame", nil, F)
    F.main:SetAllPoints()
    BuildMain(F.main)
    F.setup = CreateFrame("Frame", nil, F)
    F.setup:SetAllPoints()
    BuildSetup(F.setup)
    F.list = CreateFrame("Frame", nil, F)
    F.list:SetAllPoints()
    BuildList(F.list)

    local acc = 0
    F:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc >= 1 then acc = 0; GG.Refresh() end
    end)
    tinsert(UISpecialFrames, "DragsHedgeFundFrame")

    GG.Show(#db.goals > 0 and "main" or "setup")
    if not db.shown then F:Hide() end
end

function GG.Show(view)
    if not F then return end
    view = view or F.view or "main"
    F.view = view
    F.main:SetShown(view == "main")
    F.setup:SetShown(view == "setup")
    F.list:SetShown(view == "list")
    confirm.id = nil
    F.setup.msg:SetText("")
    F:Show()
    GG.db.shown = true
    GG.Refresh()
end

function GG.Hide()
    if not F then return end
    F:Hide()
    GG.db.shown = false
end

function GG.Toggle()
    if F and F:IsShown() then GG.Hide() else GG.Show() end
end

------------------------------------------------------------ fill in the numbers
local function RefreshSetup(s)
    local goals = GG.db.goals
    if confirm.id and GetTime() - confirm.at > 5 then confirm.id = nil end
    s.none:SetShown(#goals == 0)
    for i, r in ipairs(s.rows) do
        local g = goals[i]
        r.goal = g
        r:SetShown(g ~= nil)
        if g then
            r.name:SetText(g.name)
            r.amt:SetText(GG.Money(g.amount) .. (GG.GoalStatus(g).done and "  |cff20ff20MET|r" or ""))
            r.pct:SetText(g.pct .. "%")
            r.del:SetText(confirm.id == g.id and "|cffff3030Sure?|r" or "Remove")
        end
    end
    local _, class = GG.safe(UnitClass, "player")
    for _, b in ipairs(s.presets) do
        local p = b.preset
        b:SetText(p.name .. "  (" .. GG.Commas(GG.PresetGold(p)) .. "g)")
    end
    s.note:SetText(GG.CLASS_MOUNT[class] and "Class quest mount: riding only." or "Riding + mount")
    F:SetHeight(560)
end

local function RefreshMain(m)
    local db = GG.db
    local goals = db.goals
    local owed = GG.TotalOwed()

    if owed > 0 then
        local n = GG.OwedCount()
        m.owedLabel:SetText("To put away  |cffaaaaaa(" .. n .. " gain" .. (n == 1 and "" or "s") .. ")|r")
        m.owed:SetText(GG.Money(owed))
        m.saveBtn:Show()
    else
        m.owedLabel:SetText("To put away")
        m.owed:SetText("|cffaaaaaaNothing right now|r")
        m.saveBtn:Hide()
    end

    local now = GetTime()
    if GG.lastAt and now - GG.lastAt < 20 and (GG.lastPut or 0) > 0 then
        m.gain:SetText("|cff20ff20+|r" .. GG.Money(GG.lastGain) .. "  |cffffd100put away|r " .. GG.Money(GG.lastPut))
    else
        m.gain:SetText("|cffffd100Total saved:|r " .. GG.Money(GG.TotalSaved()))
    end

    m.none:SetShown(#goals == 0)
    for i, c in ipairs(m.cards) do
        local g = goals[i]
        c:SetShown(g ~= nil)
        if g then
            local st = GG.GoalStatus(g)
            c.name:SetText(g.name)
            c.pct:SetText(g.pct .. "%")
            c.bar.top:SetValue(st.frac)
            c.bar:SetValue(st.frac2)
            c.bar.label:SetText(GG.Money(g.saved) .. "  |cffccccccof|r " .. GG.Money(g.amount) .. "  |cffcccccc(" .. GG.PctText(st.frac) .. ")|r")
            if st.done then
                c.need:SetText("|cff20ff20GOAL MET! Go buy it.|r")
            elseif st.allIn then
                c.need:SetText("|cffffd100Put away the rest!|r")
            else
                c.need:SetText("|cffffd100Still need:|r " .. GG.Money(st.need))
            end
            c.owed:SetText(g.owed > 0 and ("owed " .. GG.Money(g.owed)) or "")
        end
    end

    -- tips go under the last card
    local y = -142 - max(#goals, 1) * CARD - 4
    m.tipHead:ClearAllPoints(); m.tipHead:SetPoint("TOPLEFT", 24, y)
    local tips = GG.Tips()
    for i = 1, 2 do
        m.tips[i]:ClearAllPoints()
        m.tips[i]:SetPoint("TOPLEFT", 30, y - i * 21)
        m.tips[i]:SetText(tips[i] or "")
    end
    F:SetHeight(-y + 2 * 21 + 30 + 56)
end

local function RefreshList(l)
    local db = GG.db
    local owed = GG.TotalOwed()
    if owed > 0 then
        l.owed:SetText("To put away: " .. GG.Money(owed))
        l.saveBtn:Show()
    else
        l.owed:SetText("Saved so far: " .. GG.Money(GG.TotalSaved()))
        l.saveBtn:Hide()
    end

    local log = db.log
    local pages = max(math.ceil(#log / ROWS), 1)
    local page = min(GG.listPage or 1, pages)
    GG.listPage = page
    local first = #log - (page - 1) * ROWS   -- newest first
    for i = 1, ROWS do
        local r, e = l.rows[i], log[first - i + 1]
        if e then
            r.a:SetText(date("%b %d  %I:%M %p", e.t))
            if e.saved then
                r.b:SetText(e.to and "|cff20ff20MAILED|r" or "|cff20ff20SAVED|r")
                r.c:SetText(GG.Money(e.saved))
            else
                r.b:SetText(GG.Money(e.gain))
                r.c:SetText(GG.Money(e.cut) .. (e.done and " |cff20ff20ok|r" or " |cffffd100owed|r"))
            end
        else
            r.a:SetText(""); r.b:SetText(""); r.c:SetText("")
        end
    end
    l.empty:SetShown(#log == 0)
    l.page:SetText(#log > ROWS and ("Page " .. page .. " of " .. pages) or "")
    l.newer:SetShown(page > 1)
    l.older:SetShown(page < pages)
    F:SetHeight(480)
end

function GG.Refresh()
    if not F or not F:IsShown() then return end
    if F.view == "setup" then RefreshSetup(F.setup)
    elseif F.view == "list" then RefreshList(F.list)
    else RefreshMain(F.main) end
end
