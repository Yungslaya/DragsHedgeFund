-- Savings Pal look: the shared style of the addon family, where every window is a big WoW tooltip
-- (blue-black panel, the tooltip border from the game, gold labels, white values, red buttons with
-- gold words). Kept here so Savings Pal never needs any other addon.
local _, GG = ...

GG.FONT = "Fonts\\ARIALN.TTF"          -- body text
GG.TITLE_FONT = "Fonts\\FRIZQT__.TTF"  -- titles and big numbers
GG.C = {
    gold  = { 1, 0.820, 0 },
    white = { 1, 1, 1 },
    gray  = { 0.640, 0.660, 0.740 },
    green = { 0.250, 0.880, 0.250 },
    red   = { 1, 0.290, 0.240 },
}
GG.THEME = {
    bg        = { 0.030, 0.040, 0.090, 0.94 },
    band      = { 0.030, 0.040, 0.090, 0 },
    border    = { 0.730, 0.740, 0.780, 1.00 },
    line      = { 0.200, 0.230, 0.330, 1.00 },
    inset     = { 0.070, 0.085, 0.160, 0.92 },
    btn       = { 0.420, 0.070, 0.040, 1.00 },
    btnHover  = { 0.580, 0.110, 0.070, 1.00 },
    btnBorder = { 0.850, 0.710, 0.420, 1.00 },
    barSaved  = { 1.00, 0.82, 0.00, 1.00 },   -- gold you put away
    barAside  = { 0.55, 0.45, 0.10, 1.00 },   -- gold set aside, not put away yet
    barBack   = { 0.00, 0.00, 0.00, 0.90 },
}
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- Windows (anything with a header strip) wear the tooltip border from the game; buttons and
-- small boxes keep a thin flat edge.
function GG.Skin(f, bandHeight, bg)
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
    fs:SetFont(size >= 18 and GG.TITLE_FONT or GG.FONT, size, "")
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
    GG.Skin(b, nil, T.btn)
    b:SetBackdropBorderColor(unpack(T.btnBorder))
    local fs = b:CreateFontString(nil, "OVERLAY")
    fs:SetFont(GG.FONT, size or 15, "")
    fs:SetShadowOffset(1, -1)
    fs:SetTextColor(unpack(GG.C.gold))
    fs:SetPoint("LEFT", b, "LEFT", 4, 0)
    fs:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    b:SetFontString(fs)
    b:SetText(label)
    b:SetScript("OnEnter", function(self) if self:IsEnabled() then self:SetBackdropColor(unpack(T.btnHover)) end end)
    b:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(T.btn)) end)
    b:SetScript("OnDisable", function() fs:SetTextColor(0.45, 0.43, 0.40) end)
    b:SetScript("OnEnable", function() fs:SetTextColor(unpack(GG.C.gold)) end)
    b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then fs:SetPoint("LEFT", self, "LEFT", 5, -1) end end)
    b:SetScript("OnMouseUp", function(self) fs:SetPoint("LEFT", self, "LEFT", 4, 0) end)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end
