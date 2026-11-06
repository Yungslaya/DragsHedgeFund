ERRORS, LOG, FRAMES = {}, {}, {}
local realpcall = pcall
function pcall(f, ...)
    local r = { realpcall(f, ...) }
    if not r[1] then local m = tostring(r[2]); ERRORS[m] = (ERRORS[m] or 0) + 1 end
    return unpack(r)
end
local function newObj()
    local o = { _shown = true }
    return setmetatable(o, { __index = function(t, k)
        if k == "CreateTexture" or k == "CreateFontString" then
            return function() local x = newObj(); FRAMES[#FRAMES + 1] = x; return x end end
        if k == "SetText" then return function(self, s) assert(s == nil or type(s) == "string" or type(s) == "number", "SetText bad type " .. type(s)); self._text = s end end
        if k == "GetText" then return function(self) return self._text end end
        if k == "SetFont" then return function(self, f, sz) assert(type(sz) == "number"); end end
        if k == "Show" then return function(self) self._shown = true end end
        if k == "Hide" then return function(self) self._shown = false end end
        if k == "SetShown" then return function(self, v) self._shown = v and true or false end end
        if k == "IsShown" then return function(self) return self._shown end end
        if k == "SetScript" then return function(self, n, f) self["_" .. n] = f end end
        if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 5, 6 end end
        if k == "SetHeight" then return function(self, h) assert(type(h) == "number", "SetHeight bad"); self._h = h end end
        if k == "SetValue" then return function(self, v) assert(type(v) == "number"); self._value = v end end
        return function() end
    end })
end
UIParent = newObj()
UISpecialFrames = {}
SlashCmdList = {}
SOUNDKIT = { LEVEL_UP = 888 }
function CreateFrame(kind, name)
    local o = newObj(); o._kind = kind; FRAMES[#FRAMES + 1] = o
    if name then _G[name] = o end
    return o
end
function FIRE(e, ...) for _, f in ipairs(FRAMES) do if rawget(f, "_OnEvent") then f._OnEvent(f, e, ...) end end end
function TICK() for _, f in ipairs(FRAMES) do if rawget(f, "_OnUpdate") then f._OnUpdate(f, 1.1) end end end
function CLICK(label)
    for _, f in ipairs(FRAMES) do if f._kind == "Button" and rawget(f, "_text") == label and rawget(f, "_OnClick") then f._OnClick(f); return true end end
    error("no button " .. label)
end
function FINDTEXT(pat)
    local out = {}
    for _, f in ipairs(FRAMES) do local t = rawget(f, "_text"); if type(t) == "string" and t:find(pat) then out[#out+1] = t end end
    return out
end
function tinsert(t, v) table.insert(t, v) end
function print(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring(select(i, ...)) end LOG[#LOG+1] = table.concat(t, " ") end
CLOCK = 1793900000
function time() return CLOCK end
function date(fmt, t) return os.date(fmt, t or CLOCK) end
local gt = 1000
function GetTime() return gt end
function ADVANCE(s) gt = gt + s; CLOCK = CLOCK + s end
MONEY = 50000
function GetMoney() return MONEY end
LEVEL, XP, XPMAX = 20, 1000, 23200
function UnitLevel() return LEVEL end
function UnitXP() return XP end
function UnitXPMax() return XPMAX end
CLASS = "WARRIOR"
function UnitClass() return "Warrior", CLASS end
function GetProfessions() return 1, 2, nil, 3 end
local PROF = { { "Mining", 186 }, { "Skinning", 393 }, { "Cooking", 185 } }
function GetProfessionInfo(i) local p = PROF[i]; return p[1], 1, 75, 150, 0, 0, p[2] end
C_Timer = { After = function(s, f) f() end }
BAG = { { quality = 0, itemID = 1, stackCount = 2 }, { quality = 1, itemID = 2 }, { quality = 0, itemID = 3, hasNoValue = true } }
C_Container = { GetContainerNumSlots = function(b) return b == 0 and #BAG or 0 end,
                GetContainerItemInfo = function(b, s) return BAG[s] end }
C_Item = { GetItemInfo = function(id) return "x", nil, 0, 1, 1, "", "", 1, "", 1, 125 end }
function PlaySound() LOG[#LOG+1] = "SOUND" end
-- mailbox mocks
function UnitName() return "Drag" end
MailFrame = CreateFrame("Frame")
MailFrameTab2 = CreateFrame("Button")
TAB = nil
function MailFrameTab_OnClick(self, id) TAB = id end
SendMailNameEditBox = CreateFrame("EditBox")
SendMailSubjectEditBox = CreateFrame("EditBox")
SendMailBodyEditBox = CreateFrame("EditBox")
SendMailSendMoneyButton = CreateFrame("CheckButton"); SendMailCODButton = CreateFrame("CheckButton")
SendMailSendMoneyButton.SetChecked = function(self, v) self._checked = v end
SendMailCODButton.SetChecked = function(self, v) self._checked = v end
SendMailMoney = CreateFrame("Frame")
function MoneyInputFrame_SetCopper(f, c) f._copper = c end
function MoneyInputFrame_GetCopper(f) return f._copper or 0 end
function SendMailFrame_CanSend() end
function SendMailFrame_SendMail() end
function hooksecurefunc(name, f) local old = _G[name]; _G[name] = function(...) local r = { old(...) }; f(...); return unpack(r) end end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
