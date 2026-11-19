--[[ Savings Pal - other languages

  English is written in the code. When the game runs in another language, text and buttons made
  with the window kit pass through GG.T() on their way to the screen: a whole line that has a
  translation is swapped for it, a line built from parts is matched by a pattern and rebuilt,
  and anything else stays in English. The note written into your savings mail stays in English.

  A language file adds its lines with GG.AddLocale("deDE", { lines }, { patterns }).
]]
local _, GG = ...

local locale = (GetLocale and GetLocale()) or "enUS"
if locale == "esMX" then locale = "esES" end
GG.locale = locale
GG.LOCALES = {}

local lines, patterns

function GG.AddLocale(code, exact, shaped)
    GG.LOCALES[code] = { exact = exact or {}, patterns = shaped or {} }
    if code == GG.locale then lines, patterns = GG.LOCALES[code].exact, GG.LOCALES[code].patterns end
end

-- For tests: switch language after loading.
function GG.UseLocale(code)
    GG.locale = code
    local l = GG.LOCALES[code]
    lines, patterns = l and l.exact or nil, l and l.patterns or nil
    GG.tCache = {}
end

GG.tCache = {}
local function translate(text)
    local hit = lines[text]
    if hit then return hit end
    local lead, core, tail = text:match("^(%s*)(.-)([%s:]*)$")
    if core ~= "" and core ~= text and lines[core] then return lead .. lines[core] .. tail end
    for i = 1, #patterns do
        local rule = patterns[i]
        if text:find(rule[1]) then return (text:gsub(rule[1], rule[2])) end
    end
    return nil
end

function GG.T(text)
    if not lines or type(text) ~= "string" or text == "" then return text end
    if issecretvalue and issecretvalue(text) then return text end
    local cached = GG.tCache[text]
    if cached ~= nil then return cached or text end
    local out = translate(text)
    GG.tCache[text] = out or false
    return out or text
end

local function localize(fs)
    if not fs or rawget(fs, "ggLocalized") then return fs end
    rawset(fs, "ggLocalized", true)
    local set, setf = fs.SetText, fs.SetFormattedText
    if set then
        fs.SetText = function(self, text, ...) return set(self, GG.T(text), ...) end
    end
    if set and setf then
        fs.SetFormattedText = function(self, format, ...)
            local ok, text = pcall(string.format, format, ...)
            if ok then return set(self, GG.T(text)) end
            return setf(self, format, ...)
        end
    end
    return fs
end

-- Every text and button made with the kit from here on is translated by itself.
local baseText, baseButton = GG.Text, GG.FlatButton
GG.Text = function(...) return localize(baseText(...)) end
GG.FlatButton = function(parent, label, ...)
    local button = baseButton(parent, GG.T(label), ...)
    local set = button and button.SetText
    if set then button.SetText = function(self, text) return set(self, GG.T(text)) end end
    return button
end

-- Languages the Latin fonts cannot draw use the game's own font.
if (locale == "ruRU" or locale == "zhCN" or locale == "zhTW" or locale == "koKR") and type(STANDARD_TEXT_FONT) == "string" then
    GG.FONT, GG.TITLE_FONT = STANDARD_TEXT_FONT, STANDARD_TEXT_FONT
end
