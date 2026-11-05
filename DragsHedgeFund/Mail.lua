local _, GG = ...

-- Mailbox helper: fills in a mail to your savings alt with the right gold and a note.
-- It only fills the boxes. YOU press Blizzard's Send button.
local FONT = "Fonts\\FRIZQT__.TTF"
local min = math.min
local P            -- the panel next to the mail window
local pending      -- what we filled in: { to, amount }
local sending      -- snapshot taken when Send was pressed

local function text(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size, "OUTLINE")
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:SetShadowOffset(1, -1)
    return fs
end

local function trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end

local function sendMoneyNow()
    if SendMailMoney and MoneyInputFrame_GetCopper then
        local ok, c = pcall(MoneyInputFrame_GetCopper, SendMailMoney)
        if ok and GG.isNum(c) then return c end
    end
    if GetSendMailMoney then
        local ok, c = pcall(GetSendMailMoney)
        if ok and GG.isNum(c) then return c end
    end
    return 0
end

function GG.FillMail()
    local db = GG.db
    local to = trim(P.name:GetText())
    if to == "" then P.msg:SetText("|cffff3030Type your alt's name.|r") return end
    local me = GG.safe(UnitName, "player")
    if type(me) == "string" and to:lower() == me:lower() then
        P.msg:SetText("|cffff3030You can't mail yourself.|r") return
    end
    local amt = GG.TotalOwed()
    if amt <= 0 then P.msg:SetText("Nothing to put away.") return end
    local money = GG.safe(GetMoney) or 0
    if GG.isNum(money) and amt + 30 > money then   -- 30c postage
        P.msg:SetText("|cffff3030Not enough gold in your bags.|r") return
    end
    db.mailTo = to

    -- open the Send Mail tab
    if MailFrameTab2 and MailFrameTab_OnClick then
        pcall(MailFrameTab_OnClick, MailFrameTab2, 2)
    elseif MailFrameTab2 and MailFrameTab2.Click then
        pcall(MailFrameTab2.Click, MailFrameTab2)
    end

    -- one line per goal that has gold waiting
    local lines, names = {}, {}
    for _, g in ipairs(db.goals) do
        if g.owed > 0 then
            names[#names + 1] = g.name
            lines[#lines + 1] = "- " .. g.name .. ": " .. GG.MoneyPlain(g.owed) ..
                " (saved " .. GG.MoneyPlain(g.saved + g.owed) .. " of " .. GG.MoneyPlain(g.amount) .. ")"
        end
    end
    local subject = #names == 1 and ("Savings: " .. names[1]) or ("Savings: " .. #names .. " goals")
    local body = "Savings sent: " .. date("%b %d, %Y") ..
        "\nAmount: " .. GG.MoneyPlain(amt) ..
        "\n" .. table.concat(lines, "\n")
    if #body > 480 then body = body:sub(1, 480) end

    if SendMailNameEditBox then SendMailNameEditBox:SetText(to) end
    if SendMailSubjectEditBox then SendMailSubjectEditBox:SetText(subject) end
    if SendMailBodyEditBox then SendMailBodyEditBox:SetText(body) end
    -- "Send Money", not C.O.D.
    if SendMailSendMoneyButton and SendMailSendMoneyButton.SetChecked then SendMailSendMoneyButton:SetChecked(true) end
    if SendMailCODButton and SendMailCODButton.SetChecked then SendMailCODButton:SetChecked(false) end
    if SendMailMoney and MoneyInputFrame_SetCopper then pcall(MoneyInputFrame_SetCopper, SendMailMoney, amt) end
    if SendMailFrame_CanSend then pcall(SendMailFrame_CanSend) end

    pending = { to = to, amount = amt }
    P.msg:SetText("|cff20ff20Filled in. Now press Send.|r")
end

local function Refresh()
    if not P or not P:IsShown() then return end
    local owed = GG.TotalOwed()
    if owed > 0 then
        P.owed:SetText(GG.Money(owed))
        P.fill:Show()
    else
        P.owed:SetText("|cffaaaaaaNothing right now|r")
        P.fill:Hide()
    end
end

local function Build()
    if P or not MailFrame then return end
    P = CreateFrame("Frame", "DragsHedgeFundMail", MailFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    P:SetSize(230, 210)
    P:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 4, 0)
    P:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    local t = text(P, 16, 1, 0.82, 0); t:SetPoint("TOP", 0, -18); t:SetText("Drags Hedge Fund")
    local l = text(P, 14, 1, 0.82, 0); l:SetPoint("TOP", 0, -44); l:SetText("To put away")
    P.owed = text(P, 20); P.owed:SetPoint("TOP", 0, -62)

    local n = text(P, 14); n:SetPoint("TOPLEFT", 22, -100); n:SetText("Send to:")
    P.name = CreateFrame("EditBox", nil, P, "InputBoxTemplate")
    P.name:SetSize(110, 26)
    P.name:SetPoint("LEFT", n, "RIGHT", 10, 0)
    P.name:SetAutoFocus(false)
    P.name:SetMaxLetters(48)
    P.name:SetFont(FONT, 14, "")
    P.name:SetScript("OnEnterPressed", P.name.ClearFocus)
    P.name:SetScript("OnEscapePressed", P.name.ClearFocus)

    P.fill = CreateFrame("Button", nil, P, "UIPanelButtonTemplate")
    P.fill:SetSize(150, 28)
    P.fill:SetPoint("TOP", 0, -132)
    P.fill:SetText("Fill in mail")
    local fs = P.fill:GetFontString()
    if fs then fs:SetFont(FONT, 15, "") end
    P.fill:SetScript("OnClick", GG.FillMail)

    P.msg = text(P, 13); P.msg:SetPoint("TOP", 0, -166); P.msg:SetWidth(200)
    P.msg:SetText("Then press Send.")

    P:SetScript("OnShow", function()
        P.name:SetText(GG.db.mailTo or "")
        P.msg:SetText("Then press Send.")
        Refresh()
    end)
end

-- When the mail really goes out, count it as saved.
local function OnSendPressed()
    local to = SendMailNameEditBox and SendMailNameEditBox:GetText()
    sending = { to = trim(to), money = sendMoneyNow() }
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("MAIL_SHOW")
ev:RegisterEvent("MAIL_CLOSED")
ev:RegisterEvent("MAIL_SEND_SUCCESS")
ev:RegisterEvent("MAIL_FAILED")
ev:RegisterEvent("PLAYER_MONEY")
ev:SetScript("OnEvent", function(_, e)
    if not GG.db then return end
    if e == "MAIL_SHOW" then
        if not P then
            Build()
            if SendMailFrame_SendMail and hooksecurefunc then hooksecurefunc("SendMailFrame_SendMail", OnSendPressed) end
            if SendMailMailButton and SendMailMailButton.HookScript then SendMailMailButton:HookScript("PreClick", OnSendPressed) end
        end
        if P then P:Show(); Refresh() end
    elseif e == "MAIL_CLOSED" then
        pending, sending = nil, nil
    elseif e == "MAIL_SEND_SUCCESS" then
        local s, p = sending, pending
        sending = nil
        if s and p and s.to:lower() == p.to:lower() and s.money > 0 then
            pending = nil
            GG.ConfirmSaved(min(s.money, p.amount), p.to)
            if P then P.msg:SetText("|cff20ff20Sent and saved!|r") end
            if GG.Refresh then GG.Refresh() end
        end
    elseif e == "MAIL_FAILED" then
        sending = nil
    end
    Refresh()
end)
