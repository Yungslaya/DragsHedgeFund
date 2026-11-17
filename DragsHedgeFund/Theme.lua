-- Savings Pal look: the same style as ProfessionPal (dark leather panels, thin bronze edge, gold titles,
-- flat buttons), kept here so Savings Pal never needs any other addon.
local _, GG = ...

GG.FONT = "Fonts\\ARIALN.TTF"          -- body text
GG.TITLE_FONT = "Fonts\\FRIZQT__.TTF"  -- titles and big numbers
GG.C = {
    gold  = { 0.94, 0.78, 0.47 },
    white = { 0.93, 0.94, 0.96 },
    gray  = { 0.69, 0.74, 0.81 },
    green = { 0.45, 0.87, 0.60 },
    red   = { 1.00, 0.35, 0.35 },
}
GG.THEME = {
    bg        = { 0.083, 0.063, 0.045, 0.97 },
    band      = { 0.148, 0.109, 0.073, 1.00 },
    border    = { 0.382, 0.286, 0.161, 1.00 },
    inset     = { 0.120, 0.093, 0.064, 0.96 },
    btn       = { 0.157, 0.116, 0.077, 1.00 },
    btnHover  = { 0.235, 0.175, 0.104, 1.00 },
    btnBorder = { 0.390, 0.288, 0.157, 1.00 },
    barSaved  = { 0.94, 0.74, 0.30, 1.00 },   -- gold you put away
    barAside  = { 0.52, 0.40, 0.20, 1.00 },   -- gold set aside, not put away yet
    barBack   = { 0.05, 0.04, 0.03, 0.90 },
}
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- Flat panel with a 1-pixel bronze edge; bandHeight adds the lighter header strip.
function GG.Skin(f, bandHeight, bg)
    local T = GG.THEME
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
                        insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        f:SetBackdropColor(unpack(bg or T.bg))
        f:SetBackdropBorderColor(unpack(T.border))
    end
    if bandHeight and not f.band then
        local band = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        band:SetTexture(WHITE)
        band:SetVertexColor(unpack(T.band))
        band:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        band:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
        band:SetHeight(bandHeight)
        local line = f:CreateTexture(nil, "BACKGROUND", nil, 2)
        line:SetTexture(WHITE)
        line:SetVertexColor(unpack(T.border))
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
