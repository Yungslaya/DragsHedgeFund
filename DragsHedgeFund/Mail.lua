local _, GG = ...

-- Mailbox helper: fills in a mail to your savings alt with the right gold and a note.
-- It only fills the boxes. YOU press Send.
--
-- Normally the panel sits beside Blizzard's mail window and you press Blizzard's Send button.
-- Addons such as TradeSkillMaster replace that window with their own, which hides Blizzard's
-- boxes and Send button. Then the panel stands on its own (drag it where you like) and shows
-- its own "Send mail" button: one click from you sends that one mail.
local FONT = "Fonts\\FRIZQT__.TTF"
local min = math.min
local POSTAGE = 30
local P            -- the panel next to the mail window
local pending      -- what we filled in: { to, amount }
local sending      -- snapshot taken when Send was pressed
local SendNow      -- defined below
local panelAlone   -- the panel is standing on its own right now (nil = not placed yet)
local sinceCheck = 0

local closedFor = 0   -- seconds in a row that no mail window was open

-- Is a mail window really open? true / false, or nil when the game gives no way to tell.
local function mailboxOpen()
    if MailFrame and MailFrame:IsVisible() then return true end
    local tsm = _G.TSM_API
    if type(tsm) == "table" and type(tsm.IsUIVisible) == "function" then
        local ok, shown = pcall(tsm.IsUIVisible, "MAILING")
        if ok and shown == true then return true end
    end
    local manager, kinds = C_PlayerInteractionManager, Enum and Enum.PlayerInteractionType
    if manager and type(manager.IsInteractingWithNpcOfType) == "function" and kinds and kinds.MailInfo then
        local ok, yes = pcall(manager.IsInteractingWithNpcOfType, kinds.MailInfo)
        if ok then return yes == true end
    end
    if type(tsm) == "table" and type(tsm.IsUIVisible) == "function" then return false end
    return nil
end

-- True when Blizzard's mail window is not on screen (another addon's mail window is in its place).
local function standsAlone() return not (MailFrame and MailFrame:IsVisible()) end

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

local function mailNote(credit, mailed, limits)
    local lines,names,left={},{},credit
    for _,g in ipairs(GG.db.goals) do
        local owed=GG.MyGoalOwed and GG.MyGoalOwed(g) or g.owed
        local part=min(owed,left,limits and (limits[g.id] or 0) or owed)
        if part>0 then
            names[#names+1]=g.name
            lines[#lines+1]="- "..g.name..": "..GG.MoneyPlain(part)..
                " (saved "..GG.MoneyPlain(g.saved+part).." of "..GG.MoneyPlain(g.amount)..")"
            left=left-part
        end
    end
    local subject=#names==1 and ("Savings: "..names[1]) or ("Savings: "..#names.." goals")
    local body="Savings sent: "..date("%b %d, %Y")..
        "\nGold mailed: "..GG.MoneyPlain(mailed)..
        "\nSaved toward goals: "..GG.MoneyPlain(credit-left)..
        "\nPostage: "..GG.MoneyPlain(POSTAGE).." (not saved)"..
        "\nTotal spent: "..GG.MoneyPlain(mailed+POSTAGE)..
        "\n"..table.concat(lines,"\n")
    return subject,body:sub(1,480)
end

function GG.FillMail()
    pending, sending, GG.mailInFlight = nil, nil, nil
    local db = GG.db
    local to = trim(P.name:GetText())
    if to == "" then P.msg:SetText("|cffff3030Type your alt's name.|r") return end
    local me = GG.safe(UnitName, "player")
    if type(me) == "string" and to:lower() == me:lower() then
        P.msg:SetText("|cffff3030You can't mail yourself.|r") return
    end
    local budget = GG.TotalOwed()
    if budget <= 0 then P.msg:SetText("Nothing to put away.") return end
    local amt = budget - POSTAGE
    if amt <= 0 then P.msg:SetText("Save more than 30 copper before mailing.") return end
    local money = GG.safe(GetMoney) or 0
    if GG.isNum(money) and amt + POSTAGE > money then   -- postage comes from the set-aside budget
        P.msg:SetText("|cffff3030Not enough gold in your bags.|r") return
    end
    db.mailTo = to

    -- open the Send Mail tab (only when Blizzard's mail window is the one showing)
    local alone = standsAlone()
    if alone then
        -- nothing to open: the mail is sent from this panel's own button
    elseif MailFrameTab2 and MailFrameTab_OnClick then
        pcall(MailFrameTab_OnClick, MailFrameTab2, 2)
    elseif MailFrameTab2 and MailFrameTab2.Click then
        pcall(MailFrameTab2.Click, MailFrameTab2)
    end

    local subject,body=mailNote(amt,amt)

    if SendMailNameEditBox then SendMailNameEditBox:SetText(to) end
    if SendMailSubjectEditBox then SendMailSubjectEditBox:SetText(subject) end
    if SendMailBodyEditBox then SendMailBodyEditBox:SetText(body) end
    -- "Send Money", not C.O.D.
    if SendMailSendMoneyButton and SendMailSendMoneyButton.SetChecked then SendMailSendMoneyButton:SetChecked(true) end
    if SendMailCODButton and SendMailCODButton.SetChecked then SendMailCODButton:SetChecked(false) end
    if SendMailMoney and MoneyInputFrame_SetCopper then pcall(MoneyInputFrame_SetCopper, SendMailMoney, amt) end
    if SendMailFrame_CanSend then pcall(SendMailFrame_CanSend) end

    local entries = {}
    for _, e in ipairs(db.log) do
        if e.cut and not e.done and GG.EntryIsMine(e) then
            local parts = {}
            for id, c in pairs(e.remaining or {}) do parts[id] = c end
            entries[#entries + 1] = { entry = e, parts = parts }
        end
    end
    pending = { to = to, amount = amt, entries = entries, ledger = db.goals }
    P.msg:SetText(alone and "|cff20ff20Filled in. Now press Send mail.|r" or "|cff20ff20Filled in. Now press Send.|r")
    P.send:Enable()
    P.refresh()
end

function GG.CancelMailDraft()
    pending, sending, GG.mailInFlight = nil, nil, nil
    if P then P.msg:SetText("Goals changed. Fill the mail again.") end
end

local function Refresh()
    if not P or not P:IsShown() then return end
    local owed = GG.TotalOwed()
    -- Standing alone with a filled mail: the panel's own Send button takes the Fill button's place.
    local canSend = pending ~= nil and panelAlone == true
    P.send:SetShown(canSend and true or false)
    if owed > 0 then
        P.owed:SetText(GG.Money(owed))
        P.fill:SetShown(not canSend)
    else
        P.owed:SetText("|cffaaaaaaNothing right now|r")
        P.fill:Hide()
    end
end

-- Beside Blizzard's mail window when it is showing; otherwise on its own, where the player left it.
local function Place()
    if not P then return end
    local alone = standsAlone()
    if alone == panelAlone then return end
    panelAlone = alone
    P:ClearAllPoints()
    if alone then
        local spot = GG.db.mailPanelSpot
        if type(spot) == "table" and spot[1] then
            P:SetPoint(spot[1], UIParent, spot[1], spot[2] or 0, spot[3] or 0)
        else
            P:SetPoint("LEFT", UIParent, "CENTER", 270, 130)
        end
        P.hint:SetText("Drag to move")
    else
        P:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 4, 0)
        P.hint:SetText("")
    end
    Refresh()
end

local function Build()
    if P or not MailFrame then return end
    -- Parented to the screen, not the mail window, so it survives another addon hiding that window.
    P = CreateFrame("Frame", "DragsHedgeFundMail", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    P:SetSize(230, 224)
    P:SetFrameStrata("HIGH")
    P:SetClampedToScreen(true)
    P:EnableMouse(true)
    P:SetMovable(true)
    P:RegisterForDrag("LeftButton")
    P:SetScript("OnDragStart", function(self) if panelAlone then self:StartMoving() end end)
    P:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        if point then GG.db.mailPanelSpot = { point, x, y } end
    end)
    -- The other addon's window can be swapped for Blizzard's (and back) while the mailbox is open.
    -- The same check closes the panel once no mail window is open any more: the game's "mail closed"
    -- message does not always arrive when another addon runs the mail window.
    P:SetScript("OnUpdate", function(self, elapsed)
        sinceCheck = sinceCheck + (elapsed or 0)
        if sinceCheck < 0.3 then return end
        local waited = sinceCheck
        sinceCheck = 0
        if mailboxOpen() == false then
            closedFor = closedFor + waited
            if closedFor >= 1 then
                closedFor = 0
                pending, sending, GG.mailInFlight = nil, nil, nil
                self:Hide()
                return
            end
        else
            closedFor = 0
        end
        Place()
    end)
    local close = CreateFrame("Button", nil, P, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() P:Hide() end)
    P.refresh = Refresh
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

    -- Only shown when the panel stands alone: Blizzard's own Send button is hidden then.
    P.send = CreateFrame("Button", nil, P, "UIPanelButtonTemplate")
    P.send:SetSize(150, 28)
    P.send:SetPoint("TOP", 0, -132)
    P.send:SetText("Send mail")
    local sendText = P.send:GetFontString()
    if sendText then sendText:SetFont(FONT, 15, "") end
    P.send:SetScript("OnClick", function() SendNow() end)
    P.send:Hide()

    P.msg = text(P, 13); P.msg:SetPoint("TOP", 0, -166); P.msg:SetWidth(200)
    P.msg:SetText("Then press Send.")
    P.hint = text(P, 11, 0.6, 0.6, 0.6); P.hint:SetPoint("BOTTOM", 0, 14)

    P:SetScript("OnShow", function()
        P.name:SetText(GG.db.mailTo or "")
        P.msg:SetText("Then press Send.")
        Refresh()
    end)
end

-- When the mail really goes out, count it as saved.
local function OnSendPressed()
    local to = SendMailNameEditBox and SendMailNameEditBox:GetText()
    sending, GG.mailInFlight = nil, nil
    if not pending or pending.ledger ~= GG.db.goals or trim(to):lower() ~= pending.to:lower() then return end
    if SendMailCODButton and SendMailCODButton.GetChecked and SendMailCODButton:GetChecked() then return end
    if GetSendMailCOD and (GG.safe(GetSendMailCOD) or 0) > 0 then return end
    local limits = {}
    for _, item in ipairs(pending.entries) do
        for id, c in pairs(item.parts) do
            local remaining = item.entry.remaining and item.entry.remaining[id] or 0
            limits[id] = (limits[id] or 0) + min(c, remaining)
        end
    end
    sending = { to = trim(to), money = sendMoneyNow(), limits = limits }
    if sending.money>0 then
        local subject,body=mailNote(min(sending.money,pending.amount),sending.money,limits)
        if SendMailSubjectEditBox then SendMailSubjectEditBox:SetText(subject) end
        if SendMailBodyEditBox then SendMailBodyEditBox:SetText(body) end
    end
    GG.mailInFlight = sending.money > 0
end

-- The panel's own Send button (standing alone). One click sends the one mail that was filled in.
SendNow = function()
    if not pending then return end
    OnSendPressed()
    if not sending or sending.money <= 0 then
        P.msg:SetText("|cffff3030Fill the mail again.|r")
        return
    end
    if not (SetSendMailMoney and SendMail) then
        P.msg:SetText("|cffff3030Switch to the WoW mail window, then press Send.|r")
        return
    end
    local subject = SendMailSubjectEditBox and SendMailSubjectEditBox:GetText() or "Savings"
    local body = SendMailBodyEditBox and SendMailBodyEditBox:GetText() or ""
    if SetSendMailCOD then pcall(SetSendMailCOD, 0) end
    local ok = pcall(SetSendMailMoney, sending.money) and pcall(SendMail, sending.to, subject, body)
    if ok then
        P.send:Disable()   -- until the game answers, so a second click cannot send it twice
        P.msg:SetText("Sending...")
    else
        sending, GG.mailInFlight = nil, nil
        P.msg:SetText("|cffff3030Could not send. Try the WoW mail window.|r")
    end
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
            if SendMailMailButton and SendMailMailButton.HookScript then SendMailMailButton:HookScript("PreClick", OnSendPressed) end
        end
        if P then
            panelAlone = nil   -- place it afresh for whichever mail window opened
            closedFor = 0
            P:Show()
            Place()
        end
    elseif e == "MAIL_CLOSED" then
        pending, sending, GG.mailInFlight = nil, nil, nil
        if P then P:Hide() end
    elseif e == "MAIL_SEND_SUCCESS" then
        if P then P.send:Enable() end
        local s, p = sending, pending
        pending, sending, GG.mailInFlight = nil, nil, nil
        if s and p and p.ledger == GG.db.goals and s.to:lower() == p.to:lower() and s.money > 0 then
            pending = nil
            local saved = GG.ConfirmSaved(min(s.money, p.amount), p.to, s.limits, POSTAGE)
            if P then P.msg:SetText(saved and "|cff20ff20Sent and saved!|r" or "Nothing left to mark saved.") end
            if GG.Refresh then GG.Refresh() end
        end
    elseif e == "MAIL_FAILED" then
        sending, GG.mailInFlight = nil, nil
        if P then
            P.send:Enable()
            if panelAlone and pending then P.msg:SetText("|cffff3030Mail failed. Press Send mail again.|r") end
        end
    end
    Refresh()
end)
