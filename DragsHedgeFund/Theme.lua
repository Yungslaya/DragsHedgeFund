-- Savings Pal look: the shared style of the addon family (EmporiumTheme.lua, a copy ships in this
-- addon): ornate stone frame with gold corners, steel cards, gold labels, red buttons.
local _, GG = ...

GG.FONT = DragbagEmporiumTheme.body          -- body text
GG.TITLE_FONT = DragbagEmporiumTheme.title  -- titles and big numbers
GG.C = {
    gold  = { 0.85, 0.71, 0.42 },   -- the family's gold, white and gray (same in every addon)
    white = { 0.94, 0.93, 0.90 },
    gray  = { 0.71, 0.71, 0.74 },
    green = { 0.250, 0.880, 0.250 },
    red   = { 1, 0.290, 0.240 },
}
GG.THEME = {
    bg        = { 0.030, 0.040, 0.090, 0.94 },
    band      = { 0.030, 0.040, 0.090, 0 },
    border    = { 0.620, 0.480, 0.270, 1.00 },
    line      = { 0.200, 0.230, 0.330, 1.00 },
    inset     = { 0.070, 0.085, 0.160, 0.92 },
    btn       = { 0.420, 0.070, 0.040, 1.00 },
    btnHover  = { 0.580, 0.110, 0.070, 1.00 },
    btnBorder = { 0.850, 0.710, 0.420, 1.00 },
    barSaved  = { 0.88, 0.73, 0.38, 1.00 },   -- gold you put away
    barAside  = { 0.55, 0.45, 0.10, 1.00 },   -- gold set aside, not put away yet
    barBack   = { 0.00, 0.00, 0.00, 0.90 },
}
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- Windows (anything with a header strip) wear the tooltip border from the game; buttons and
-- small boxes keep a thin flat edge.
-- opts: { compact = true } for the small overlay, title = the title text, close = the close button
function GG.Skin(f, bandHeight, bg, opts)
    local E = DragbagEmporiumTheme
    if E then
        if bandHeight or opts then return E.Window(f, bandHeight, opts) end
        if bg == GG.THEME.btn then return end      -- buttons: FlatButton styles them when built
        return E.Card(f)
    end
    local T = GG.THEME
    if bandHeight and f.SetBackdrop then
        f:SetBackdrop({ bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
                        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        f:SetBackdropColor(unpack(bg or T.bg))
        f:SetBackdropBorderColor(unpack(T.border))
    elseif f.SetBackdrop then
        f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
                        insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        f:SetBackdropColor(unpack(bg or T.bg))
        f:SetBackdropBorderColor(unpack(T.border))
    end
    if bandHeight and not f.band then
        local band = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        band:SetTexture(WHITE)
        band:SetVertexColor(unpack(T.band))
        band:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -5)
        band:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
        band:SetHeight(bandHeight)
        local line = f:CreateTexture(nil, "BACKGROUND", nil, 2)
        line:SetTexture(WHITE)
        line:SetVertexColor(unpack(T.line))
        line:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 0, 0)
        line:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT", 0, 0)
        line:SetHeight(1)
        f.band, f.bandLine = band, line
    end
end

-- Text in the house style: titles (18+) in the WoW title font, the rest in a clean, easy-to-read font.
function GG.Text(parent, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    size = math.max(12, size or 14)
    -- big text is bold; the title font is for window titles only
    DragbagEmporiumTheme.Font(fs, size, size >= 18 and "bold" or "body")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetTextColor(unpack(color or GG.C.white))
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

-- Flat button with gold text; lighter when you point at it.
function GG.FlatButton(parent, label, w, h, size, onClick)
    local T = GG.THEME
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h or 28)
    local fs = b:CreateFontString(nil, "OVERLAY")
    DragbagEmporiumTheme.Font(fs, size or 15, "bold")
    fs:SetShadowOffset(1, -1)
    fs:SetTextColor(unpack(GG.C.gold))
    fs:SetPoint("LEFT", b, "LEFT", 4, 0)
    fs:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    b:SetFontString(fs)
    b:SetText(label)
    b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then fs:SetPoint("LEFT", self, "LEFT", 5, -1) end end)
    b:SetScript("OnMouseUp", function(self) fs:SetPoint("LEFT", self, "LEFT", 4, 0) end)
    if onClick then b:SetScript("OnClick", onClick) end
    DragbagEmporiumTheme.Button(b, "ruby")   -- red button with the gold edge; hover, disabled and fit handled there
    return b
end
