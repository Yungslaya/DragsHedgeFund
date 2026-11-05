local _, GG = ...

local FONT = "Fonts\\FRIZQT__.TTF"
local W, H = 340, 480
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

local function editBox(parent, w)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(w, 28)
    e:SetAutoFocus(false)
    e:SetNumeric(true)
    e:SetMaxLetters(6)
    e:SetFont(FONT, 16, "")
    e:SetJustifyH("CENTER")
    e:SetScript("OnEnterPressed", e.ClearFocus)
    e:SetScript("OnEscapePressed", e.ClearFocus)
    return e
end

local F -- the window

------------------------------------------------------------ main view
local function BuildMain(m)
    m.goal = text(m, 17, 1, 0.82, 0)
    m.goal:SetPoint("TOP", 0, -34)
    m.goal:SetWidth(W - 40)

    m.savedL = text(m, 14, 1, 0.82, 0)
    m.savedL:SetPoint("TOP", 0, -58)
    m.savedL:SetText("Saved so far")
    m.saved = text(m, 30)
    m.saved:SetPoint("TOP", 0, -76)

    -- two bars: bright = saved, dim = waiting to be put away
    local back = CreateFrame("StatusBar", nil, m, BackdropTemplateMixin and "BackdropTemplate" or nil)
    back:SetSize(W - 60, 24)
    back:SetPoint("TOP", 0, -112)
    back:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    back:SetStatusBarColor(0.55, 0.42, 0.1)
    back:SetMinMaxValues(0, 1)
    local bg = back:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)
    if back.SetBackdrop then
        back:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
                           insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    end
    local bar = CreateFrame("StatusBar", nil, back)
    bar:SetAllPoints()
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(1, 0.75, 0)
    bar:SetMinMaxValues(0, 1)
    bar.pct = text(bar, 15)
    bar.pct:SetPoint("CENTER")
    m.bar, m.back = bar, back

    m.of = text(m, 16)
    m.of:SetPoint("TOP", 0, -146)
    m.need = text(m, 16)
    m.need:SetPoint("TOP", 0, -168)
    m.status = text(m, 20)
    m.status:SetPoint("TOP", 0, -194)

    m.owedLabel = text(m, 15, 1, 0.82, 0)
    m.owedLabel:SetPoint("TOP", 0, -226)
    m.owed = text(m, 24)
    m.owed:SetPoint("TOP", 0, -244)
    m.saveBtn = button(m, "I saved it", 140, 28, 15, function() GG.ConfirmSaved(); GG.Refresh() end)
    m.saveBtn:SetPoint("TOP", 0, -274)

    m.minus = button(m, "-", 32, 28, 20, function() GG.db.pct = max(GG.db.pct - 5, 5); GG.Refresh() end)
    m.pct = text(m, 18)
    m.pct:SetPoint("TOP", 0, -318)
    m.minus:SetPoint("RIGHT", m.pct, "LEFT", -12, 0)
    m.plus = button(m, "+", 32, 28, 20, function() GG.db.pct = min(GG.db.pct + 5, 100); GG.Refresh() end)
    m.plus:SetPoint("LEFT", m.pct, "RIGHT", 12, 0)

    m.gain = text(m, 15)
    m.gain:SetPoint("TOP", 0, -350)
    m.gain:SetWidth(W - 40)

    m.tipHead = text(m, 16, 1, 0.82, 0, "LEFT")
    m.tipHead:SetPoint("TOPLEFT", 24, -378)
    m.tipHead:SetText("Tips")
    m.tips = {}
    for i = 1, 2 do
        local t = text(m, 14, 1, 1, 1, "LEFT")
        t:SetPoint("TOPLEFT", 30, -378 - i * 21)
        t:SetWidth(W - 54)
        m.tips[i] = t
    end

    local bw, gap = 72, 5
    local x = (W - (bw * 4 + gap * 3)) / 2
    local function bottom(label, f)
        local b = button(m, label, bw, 26, 14, f)
        b:SetPoint("BOTTOMLEFT", x, 18)
        x = x + bw + gap
        return b
    end
    m.goalBtn = bottom("Goal", function() GG.Show("setup") end)
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
    l.colB = text(l, 13, 1, 0.82, 0, "RIGHT"); l.colB:SetPoint("TOPRIGHT", -120, -126); l.colB:SetText("Gained")
    l.colC = text(l, 13, 1, 0.82, 0, "RIGHT"); l.colC:SetPoint("TOPRIGHT", -22, -126); l.colC:SetText("Put away")

    l.rows = {}
    for i = 1, ROWS do
        local y = -126 - i * 21
        local r = {}
        r.a = text(l, 13, 0.75, 0.75, 0.75, "LEFT");  r.a:SetPoint("TOPLEFT", 22, y)
        r.b = text(l, 14, 1, 1, 1, "RIGHT");          r.b:SetPoint("TOPRIGHT", -120, y)
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

------------------------------------------------------------ goal setup view
local function BuildSetup(s)
    s.head = text(s, 19, 1, 0.82, 0)
    s.head:SetPoint("TOP", 0, -36)
    s.head:SetText("Pick a goal")

    local y = -64
    s.presets = {}
    for i, p in ipairs(GG.PRESETS) do
        local b = button(s, p.name, 270, 32, 15, function()
            GG.PickPreset(p.key)
            GG.Show("main")
        end)
        b:SetPoint("TOP", 0, y)
        b.preset = p
        s.presets[i] = b
        y = y - 38
    end
    s.note = text(s, 13, 0.8, 0.8, 0.8)
    s.note:SetPoint("TOP", 0, y + 2)
    s.note:SetWidth(W - 40)

    s.own = text(s, 17, 1, 0.82, 0)
    s.own:SetPoint("TOP", 0, -168)
    s.own:SetText("Your own goal")

    local function row(label, yy, w)
        local l = text(s, 15, 1, 1, 1, "RIGHT")
        l:SetPoint("TOPRIGHT", s, "TOP", -10, yy - 6)
        l:SetText(label)
        local e = editBox(s, w)
        e:SetPoint("TOPLEFT", s, "TOP", 4, yy)
        return e
    end
    s.gold = row("Gold:", -196, 90)

    s.msg = text(s, 14, 1, 0.3, 0.3)
    s.msg:SetPoint("TOP", 0, -232)

    s.start = button(s, "Start", 120, 30, 15, function()
        local gold = tonumber(s.gold:GetText() or "")
        if not gold or gold <= 0 then s.msg:SetText("Type how much gold.") return end
        GG.SetGoal("Save " .. GG.Commas(gold) .. "g", gold)
        s.msg:SetText("")
        GG.Show("main")
    end)
    s.start:SetPoint("TOP", 0, -252)

    s.countNote = text(s, 14, 0.8, 0.8, 0.8)
    s.countNote:SetPoint("TOP", 0, -306)
    s.countNote:SetText("Gold you have now is not counted.")
    s.countNote:SetWidth(W - 40)

    s.back = button(s, "Back", 90, 26, 14, function() GG.Show("main") end)
    s.back:SetPoint("BOTTOM", 0, 18)
end

------------------------------------------------------------ window
function GG.BuildUI()
    if F then return end
    local db = GG.db
    F = CreateFrame("Frame", "DragsHedgeFundFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    GG.frame = F
    F:SetSize(W, H)
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

    GG.Show(db.goal and "main" or "setup")
    if not db.shown then F:Hide() end
end

function GG.Show(view)
    if not F then return end
    view = view or F.view or "main"
    if view == "main" and not GG.db.goal then view = "setup" end
    F.view = view
    F.main:SetShown(view == "main")
    F.setup:SetShown(view == "setup")
    F.list:SetShown(view == "list")
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
    local _, class = GG.safe(UnitClass, "player")
    local classMount = GG.CLASS_MOUNT[class]
    for _, b in ipairs(s.presets) do
        local p = b.preset
        local gold = GG.PresetGold(p)
        b:SetText(p.name .. "  (" .. GG.Commas(gold) .. "g)")
    end
    s.note:SetText(classMount and "Class quest mount. Riding only."
        or "Riding + mount")
end

local function RefreshMain(m)
    local st = GG.Status()
    local g = st.goal
    if not g then return end
    local db = GG.db

    m.goal:SetText(g.name)
    m.saved:SetText(GG.Money(st.saved))
    m.bar:SetValue(st.frac)
    m.back:SetValue(st.frac2)
    m.bar.pct:SetText(floor(st.frac * 100) .. "%")
    m.of:SetText("|cffffd100Goal:|r " .. GG.Money(st.amount))
    m.need:SetText("|cffffd100Still need:|r " .. GG.Money(st.need))

    if st.done then
        m.status:SetText("|cff20ff20GOAL MET! Go buy it.|r")
    elseif st.allIn then
        m.status:SetText("|cffffd100Put away the rest!|r")
    else
        m.status:SetText("")
    end

    if st.owed > 0 then
        local n = GG.OwedCount()
        m.owedLabel:SetText("To put away  |cffaaaaaa(" .. n .. " gain" .. (n == 1 and "" or "s") .. ")|r")
        m.owed:SetText(GG.Money(st.owed))
        m.saveBtn:Show()
    else
        m.owedLabel:SetText("To put away")
        m.owed:SetText("|cffaaaaaaNothing right now|r")
        m.saveBtn:Hide()
    end
    m.pct:SetText("Save " .. db.pct .. "%")

    local now = GetTime()
    if GG.lastAt and now - GG.lastAt < 20 and (GG.lastPut or 0) > 0 then
        m.gain:SetText("|cff20ff20+|r" .. GG.Money(GG.lastGain) .. "  |cffffd100put away|r " .. GG.Money(GG.lastPut))
    elseif not st.allIn then
        m.gain:SetText("|cffaaaaaa" .. db.pct .. "% of every gold gain|r")
    else
        m.gain:SetText("")
    end

    local tips = GG.Tips()
    for i = 1, 2 do m.tips[i]:SetText(tips[i] or "") end
end

local function RefreshList(l)
    local db = GG.db
    local owed = db.owed or 0
    if owed > 0 then
        l.owed:SetText("To put away: " .. GG.Money(owed))
        l.saveBtn:Show()
    else
        l.owed:SetText("Saved so far: " .. GG.Money(db.saved))
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
end

function GG.Refresh()
    if not F or not F:IsShown() then return end
    if F.view == "setup" then RefreshSetup(F.setup)
    elseif F.view == "list" then RefreshList(F.list)
    else RefreshMain(F.main) end
end
