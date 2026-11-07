from pathlib import Path
import sys
here=Path(__file__).parent
from lupa import lua51
root=here.parent/"DragsHedgeFund"
harness=(here/"harness.lua").read_text()
extra=r"""
function HookTest(self, n, f) self["_"..n] = f end
SendMailMailButton=CreateFrame("Button")
SendMailMailButton.HookScript=HookTest
SendMailCODButton.GetChecked=function(self) return rawget(self,"_checked") or false end
SendMailSendMoneyButton.GetChecked=SendMailCODButton.GetChecked
function GetSendMailCOD() return 0 end
function GetStringHeight() return 16 end
"""
cases = {
"zero-gold login and zoning":r"""
MONEY=0; FIRE("PLAYER_LOGIN"); FIRE("PLAYER_ENTERING_WORLD")
assert(DragsHedgeFund.AddGoal("Mount",200,20))
MONEY=10000; FIRE("PLAYER_MONEY")
assert(DragsHedgeFund.TotalOwed()==2000)
MONEY=20000; FIRE("PLAYER_ENTERING_WORLD"); FIRE("PLAYER_MONEY")
assert(DragsHedgeFund.TotalOwed()==4000)
assert(DragsHedgeFund.TotalSaved()==0)
""",
"red to black includes the new cut":r"""
FIRE("PLAYER_LOGIN")
local G=DragsHedgeFund
assert(G.AddGoal("Mount",200,20))
MONEY=MONEY+500000; FIRE("PLAYER_MONEY")
MONEY=90000; FIRE("PLAYER_MONEY")
assert(G.TotalOwed()==100000 and G.CanSpend()==-10000)
MONEY=MONEY+50000; FIRE("PLAYER_MONEY")
assert(G.TotalOwed()==110000 and G.CanSpend()==30000 and G.TotalSaved()==0)
""",
"percent limit and tiny-gain rounding":r"""
FIRE("PLAYER_LOGIN")
local G=DragsHedgeFund
assert(G.AddGoal("One",100,50))
assert(G.AddGoal("Two",100,50))
assert(not G.AddGoal("Too much",100,1))
assert(not G.AddGoal("Bad",-10,20))
assert(not G.AddGoal("Bad",0/0,20))
G.SetGoalPct(G.db.goals[1],90); assert(G.db.goals[1].pct==50)
G.SetGoalPct(G.db.goals[1],0); assert(G.db.goals[1].pct==0)
G.SetGoalPct(G.db.goals[1],50)
for i=1,200 do
 local before=G.TotalOwed(); MONEY=MONEY+1; FIRE("PLAYER_MONEY")
 assert(G.TotalOwed()-before==1,"Cannot reserve 2 copper from a 1 copper gain")
end
""",
"partial payments agree with per-goal transactions":r"""
FIRE("PLAYER_LOGIN"); local G=DragsHedgeFund
G.AddGoal("Mount",200,20); G.AddGoal("Bags",40,10)
MONEY=MONEY+10000; FIRE("PLAYER_MONEY")
MONEY=MONEY+10000; FIRE("PLAYER_MONEY")
assert(G.TotalOwed()==6000)
assert(G.ConfirmSaved(2500)==2500)
assert(G.TotalOwed()==3500 and G.TotalSaved()==2500)
local totals={}
for _,e in ipairs(G.db.log) do
 if e.cut then
  local sum=0; for id,c in pairs(e.remaining) do totals[id]=(totals[id] or 0)+c; sum=sum+c end
  assert(sum==e.unpaid and e.done==(sum==0))
 end
end
for _,g in ipairs(G.db.goals) do assert((totals[g.id] or 0)==g.owed) end
G.InitDB()
assert(G.TotalOwed()==3500 and G.TotalSaved()==2500)
G.ConfirmSaved()
assert(G.TotalOwed()==0 and G.TotalSaved()==6000 and G.OwedCount()==0)
""",
"removing a goal releases its pending cuts":r"""
FIRE("PLAYER_LOGIN"); local G=DragsHedgeFund
G.AddGoal("Mount",200,20); G.AddGoal("Bags",40,10)
MONEY=MONEY+10000; FIRE("PLAYER_MONEY")
G.RemoveGoal(G.db.goals[1].id)
assert(G.TotalOwed()==1000)
local e=G.db.log[1]; assert(e.unpaid==1000)
G.ConfirmSaved(); assert(G.OwedCount()==0 and G.TotalSaved()==1000)
""",
"retain more than 300 unpaid gains":r"""
FIRE("PLAYER_LOGIN"); local G=DragsHedgeFund
G.AddGoal("Mount",200,20)
for i=1,405 do MONEY=MONEY+100; FIRE("PLAYER_MONEY") end
assert(G.TotalOwed()==8100 and G.OwedCount()==405)
G.ConfirmSaved(30)
assert(G.db.log[1].done and G.db.log[2].unpaid==10)
G.InitDB()
assert(G.TotalOwed()==8070 and G.OwedCount()==404)
""",
"legacy data preserves saved and reconstructs missing history":r"""
DragsHedgeFundDB={version=2,pct=20,saved=537,owed=130,goal={name="Save 100g by level 40",amount=1000000},
log={{t=CLOCK,gain=100,cut=20}}}
FIRE("PLAYER_LOGIN"); local G=DragsHedgeFund
assert(#G.db.goals==1 and G.TotalSaved()==537 and G.TotalOwed()==130)
local total=0; for _,e in ipairs(G.db.log) do total=total+(e.unpaid or 0) end
assert(total==130)
G.ConfirmSaved(); assert(G.TotalSaved()==667 and G.OwedCount()==0)
""",
"exact copper in spendable and owed amounts":r"""
FIRE("PLAYER_LOGIN"); local G=DragsHedgeFund
assert(G.Money(12345678):find("78|r"))
assert(G.Money(10000009):find("9|r"))
G.AddGoal("Mount",200,20)
MONEY=MONEY+10005; FIRE("PLAYER_MONEY")
assert(G.SpendText(true):find("4|r"),G.SpendText(true))
""",
"mail success, COD, failure, changed goal and partial send":r"""
FIRE("PLAYER_LOGIN"); local G=DragsHedgeFund
G.AddGoal("Mount",200,20); G.AddGoal("Bags",40,10)
MONEY=MONEY+10000; FIRE("PLAYER_MONEY")
FIRE("MAIL_SHOW"); local P=DragsHedgeFundMail; P.name._text="Bankalt"
G.FillMail(); assert(SendMailMoney._copper==3000)
SendMailCODButton._checked=true
SendMailMailButton._PreClick(); FIRE("MAIL_SEND_SUCCESS")
assert(G.TotalSaved()==0 and G.TotalOwed()==3000,"COD is not sent savings")
G.FillMail(); SendMailMailButton._PreClick(); FIRE("MAIL_FAILED")
assert(G.TotalSaved()==0)
G.FillMail(); SendMailNameEditBox._text="Friend"
SendMailMailButton._PreClick(); FIRE("MAIL_SEND_SUCCESS")
assert(G.TotalSaved()==0)
G.FillMail(); SendMailMoney._copper=500
SendMailMailButton._PreClick()
-- Simulate Blizzard clearing the form immediately after Send.
SendMailNameEditBox._text=""; SendMailMoney._copper=0
FIRE("MAIL_SEND_SUCCESS")
assert(G.TotalSaved()==500 and G.TotalOwed()==2500)
FIRE("MAIL_SEND_SUCCESS"); assert(G.TotalSaved()==500,"No double credit")
G.FillMail()
G.ConfirmSaved()
MONEY=MONEY+10000; FIRE("PLAYER_MONEY")
SendMailMailButton._PreClick(); FIRE("MAIL_SEND_SUCCESS")
assert(G.TotalSaved()==3000 and G.TotalOwed()==3000,"Old draft must not credit newer cuts")
""",
"UI, overlay, mail panel load with secret combat values":r"""
FIRE("PLAYER_LOGIN"); local G=DragsHedgeFund
for i=1,5 do assert(G.AddGoal("Goal "..i,100,i*5)) end
G.Show("setup"); TICK(); G.Show("main"); TICK()
G.Show("list"); TICK(); G.ToggleMini(); G.ToggleMini()
FIRE("MAIL_SHOW"); FIRE("MAIL_CLOSED"); TICK()
assert(#G.db.goals==5)
"""
}

cases["sparse API returns and hidden window survive reload"]=r'''
DragsHedgeFundDB={version=3,pct=20,goals={},log={},nextId=1,shown=false}
FIRE("PLAYER_LOGIN"); local G=DragsHedgeFund
assert(not DragsHedgeFundFrame:IsShown() and not G.db.shown)
local a,b,c,d=G.safe(function() return "first",nil,nil,"last" end)
assert(a=="first" and b==nil and c==nil and d=="last")
G.AddGoal("Mount",200,20)
G.Show("main")
assert(DragsHedgeFundFrame.main.spendLabel._text=="CAN SPEND (HERE)")
assert(DragsHedgeFundFrame.main.stored._text~=nil)
'''
cases["mail postage does not produce a false savings alarm"]=r'''
FIRE("PLAYER_LOGIN"); local G=DragsHedgeFund
G.AddGoal("Mount",200,100)
MONEY=MONEY+10000; FIRE("PLAYER_MONEY")
MONEY=10030; FIRE("PLAYER_MONEY")
FIRE("MAIL_SHOW"); DragsHedgeFundMail.name._text="Bankalt"
G.FillMail(); SendMailMailButton._PreClick()
local n=#LOG; MONEY=0; FIRE("PLAYER_MONEY")
for i=n+1,#LOG do assert(not LOG[i]:find("You spent into"),LOG[i]) end
FIRE("MAIL_SEND_SUCCESS")
assert(G.TotalSaved()==10000 and G.TotalOwed()==0)
'''
cases["allocation remains bounded across changing goals"]=r'''
FIRE("PLAYER_LOGIN"); local G=DragsHedgeFund
for i=1,5 do assert(G.AddGoal("Goal "..i,500,20)) end
math.randomseed(6219)
for i=1,1200 do
 local gain=math.random(1,5000); local before=G.TotalOwed()
 MONEY=MONEY+gain; FIRE("PLAYER_MONEY")
 local reserved=G.TotalOwed()-before
 assert(reserved>=0 and reserved<=gain)
 if i%37==0 then G.ConfirmSaved(math.random(1,1000)) end
end
local totals={}
for _,e in ipairs(G.db.log) do
 for id,c in pairs(e.remaining or {}) do totals[id]=(totals[id] or 0)+c end
end
for _,g in ipairs(G.db.goals) do assert(g.owed==(totals[g.id] or 0)) end
'''


extra += r'''
CHARACTER_DATA={}
function SwitchCharacter(name, copper, realm)
    realm=realm or "Forever"
    local G=DragsHedgeFund
    if G.personal then
        G.RecordWallet()
        CHARACTER_DATA[G.characterRealm..":"..G.characterName]=DragsHedgeFundDB
    end
    TEST_NAME,TEST_REALM=name,realm
    UnitFullName=function() return TEST_NAME,TEST_REALM end
    UnitName=function() return TEST_NAME end
    GetRealmName=function() return TEST_REALM end
    UnitGUID=function() return TEST_REALM..":"..TEST_NAME end
    DragsHedgeFundDB=CHARACTER_DATA[realm..":"..name] or {}
    CHARACTER_DATA[realm..":"..name]=DragsHedgeFundDB
    MONEY=copper
    G.InitDB(); G.OnMoney(true)
    if not G.frame then G.BuildUI() end
end
function AccountTotals()
    local rows,total=DragsHedgeFund.CharacterRows()
    return total,#rows
end
'''
cases["all-character gold remembers each wallet without counting login as earnings"]=r'''
SwitchCharacter("Alice",600000)
local G=DragsHedgeFund
G.AddGoal("Mount",200,20)
SwitchCharacter("Bob",400000)
local total,n=AccountTotals()
assert(total==1000000 and n==2)
assert(G.TotalOwed()==0 and G.TotalSaved()==0)
MONEY=MONEY+10000; FIRE("PLAYER_MONEY")
assert(AccountTotals()==1010000)
SwitchCharacter("Alice",600000)
assert(G.TotalOwed()==0,"Existing gold or alt earnings became personal earnings")
assert(AccountTotals()==1010000)
G.Show("characters"); TICK()
assert(DragsHedgeFundFrame.characters.total._text~=nil)
'''
cases["combined balance can be reserved once and confirmed only by its owner"]=r'''
SwitchCharacter("Alice",600000); local G=DragsHedgeFund
SwitchCharacter("Bob",400000)
G.SetScope(true); assert(G.AddGoal("Shared mount",200,20))
local plan=G.PoolPlan()
assert(plan.total==200000 and plan.available==1000000 and plan.characters==2)
assert(G.TotalOwed()==0 and G.TotalSaved()==0,"Preview changed savings")
assert(G.ApplyPool(plan))
assert(G.db.goals[1].owed==200000)
assert(G.TotalOwed()==80000 and G.CanSpend()==320000)
assert(G.PoolPlan().total==0,"Repeated reserve counted the same gold twice")
assert(G.TotalSaved()==0)
MONEY=MONEY-80000; FIRE("PLAYER_MONEY"); assert(G.ConfirmSaved()==80000)
SwitchCharacter("Alice",600000)
assert(G.IsShared() and G.TotalOwed()==120000 and G.CanSpend()==480000)
MONEY=MONEY-120000; FIRE("PLAYER_MONEY"); assert(G.ConfirmSaved()==120000)
assert(G.TotalSaved()==200000 and G.TotalOwed()==0)
'''
cases["future shared earnings and partial deposits stay on the right character"]=r'''
SwitchCharacter("Alice",600000); local G=DragsHedgeFund
G.SetScope(true); G.AddGoal("Shared mount",200,20)
MONEY=MONEY+50000; FIRE("PLAYER_MONEY")
assert(G.TotalOwed()==10000)
SwitchCharacter("Bob",400000)
assert(G.IsShared() and G.TotalOwed()==0 and G.TotalSaved()==0)
MONEY=MONEY+100000; FIRE("PLAYER_MONEY")
assert(G.TotalOwed()==20000 and G.db.goals[1].owed==30000)
assert(G.ConfirmSaved(5000)==5000)
assert(G.TotalOwed()==15000 and G.TotalSaved()==5000)
G.InitDB(); G.OnMoney(true)
assert(G.TotalOwed()==15000,"Shared ledger changed on reload")
SwitchCharacter("Alice",650000)
assert(G.TotalOwed()==10000)
assert(G.ConfirmSaved()==10000)
assert(G.db.goals[1].owed==15000 and G.TotalSaved()==15000)
assert(not G.ConfirmSaved(),"Alice confirmed Bob's money")
'''
cases["sharing an existing goal preserves its stored and owed amounts"]=r'''
SwitchCharacter("Alice",600000); local G=DragsHedgeFund
G.AddGoal("Mount",200,20)
MONEY=MONEY+10000; FIRE("PLAYER_MONEY")
G.ConfirmSaved(537)
local owed=G.TotalOwed()
assert(G.ShareGoal(G.db.goals[1].id))
assert(G.IsShared() and #G.personal.goals==0)
assert(G.TotalSaved()==537 and G.TotalOwed()==owed)
SwitchCharacter("Bob",400000)
assert(G.TotalSaved()==537 and G.TotalOwed()==0)
MONEY=MONEY+50000; FIRE("PLAYER_MONEY")
assert(G.TotalOwed()==10000)
G.ConfirmSaved()
assert(G.TotalSaved()==10537 and G.db.goals[1].owed==owed)
'''
cases["personal reservations stay protected while viewing shared goals"]=r'''
SwitchCharacter("Alice",600000); local G=DragsHedgeFund
G.AddGoal("Private",200,20)
MONEY=MONEY+100000; FIRE("PLAYER_MONEY")
assert(G.TotalOwed()==20000)
G.SetScope(true)
assert(G.TotalOwed()==0 and G.CanSpend()==680000)
G.AddGoal("Shared",100,20)
MONEY=MONEY+100000; FIRE("PLAYER_MONEY")
assert(G.TotalOwed()==20000 and G.CanSpend()==760000)
G.ConfirmSaved()
assert(G.CanSpend()==780000 and G.personal.goals[1].owed==20000)
G.SetScope(false)
assert(G.TotalOwed()==20000 and G.TotalSaved()==0)
'''
cases["pool confirmation rejects changed balances and excludes stored savings"]=r'''
SwitchCharacter("Alice",1000000); local G=DragsHedgeFund
G.SetScope(true); G.AddGoal("Shared",200,20)
local plan=G.PoolPlan()
MONEY=MONEY+10000; FIRE("PLAYER_MONEY")
assert(not G.ApplyPool(plan),"Stale snapshot accepted")
local current=G.PoolPlan()
assert(current.available==1008000)
G.ConfirmSaved()
local nextPlan=G.PoolPlan()
assert(nextPlan.available==1008000,"Stored gold was available to reserve again")
'''
cases["realm totals are separate for shared goals"]=r'''
SwitchCharacter("Alice",600000,"One"); local G=DragsHedgeFund
G.SetScope(true); G.AddGoal("One mount",200,20)
SwitchCharacter("Alice",400000,"Two")
assert(not G.IsShared() and #G.db.goals==0)
assert(AccountTotals()==1000000)
G.SetScope(true); G.AddGoal("Two mount",200,20)
assert(G.PoolPlan().total==80000 and G.PoolPlan().characters==1)
SwitchCharacter("Alice",600000,"One")
assert(G.IsShared() and G.db.goals[1].name=="One mount")
assert(G.PoolPlan().total==120000)
'''
cases["own-transfer skip applies to exactly one increase"]=r'''
SwitchCharacter("Alice",600000); local G=DragsHedgeFund
G.SetScope(true); G.AddGoal("Mount",200,20)
G.SkipOwnTransfer()
MONEY=MONEY+100000; FIRE("PLAYER_MONEY")
assert(G.TotalOwed()==0)
MONEY=MONEY+100000; FIRE("PLAYER_MONEY")
assert(G.TotalOwed()==20000)
G.SkipOwnTransfer(); ADVANCE(1801)
MONEY=MONEY+100000; FIRE("PLAYER_MONEY")
assert(G.TotalOwed()==40000,"Expired skip ate a normal gain")
'''
cases["shared mail cannot confirm contributions from offline alts"]=r'''
SwitchCharacter("Alice",600000); local G=DragsHedgeFund
G.SetScope(true); G.AddGoal("Mount",200,20)
MONEY=MONEY+50000; FIRE("PLAYER_MONEY")
SwitchCharacter("Bob",400000)
MONEY=MONEY+100000; FIRE("PLAYER_MONEY")
FIRE("MAIL_SHOW"); DragsHedgeFundMail.name._text="Bankalt"
G.FillMail()
assert(SendMailMoney._copper==20000,"Mail included Alice's contribution")
SendMailMailButton._PreClick(); FIRE("MAIL_SEND_SUCCESS")
assert(G.TotalSaved()==20000 and G.db.goals[1].owed==10000 and G.TotalOwed()==0)
SwitchCharacter("Alice",650000)
assert(G.TotalOwed()==10000)
'''
cases["switching scopes invalidates a prepared savings mail"]=r'''
SwitchCharacter("Alice",600000); local G=DragsHedgeFund
G.AddGoal("Private",200,20)
MONEY=MONEY+10000; FIRE("PLAYER_MONEY")
FIRE("MAIL_SHOW"); DragsHedgeFundMail.name._text="Bankalt"; G.FillMail()
G.SetScope(true); G.AddGoal("Shared",200,20)
SendMailMailButton._PreClick(); FIRE("MAIL_SEND_SUCCESS")
assert(G.TotalSaved()==0 and G.personal.goals[1].saved==0)
assert(G.personal.goals[1].owed==2000)
'''


cases["character screen previews, confirms and pages through cached wallets"]=r'''
local G=DragsHedgeFund
for i=1,7 do SwitchCharacter("Alt"..i,100000) end
G.SetScope(true); G.AddGoal("Shared mount",200,20)
G.Show("characters")
local P=DragsHedgeFundFrame.characters
assert(P.older:IsShown())
P.older._OnClick(); assert(G.characterPage==2)
P.newer._OnClick(); assert(G.characterPage==1)
P.use._OnClick()
assert(G.db.goals[1].owed==0 and P.confirm:IsShown())
P.confirm._OnClick()
assert(G.db.goals[1].owed==140000 and G.TotalSaved()==0)
assert(G.TotalOwed()==20000 and G.CanSpend()==80000)
P.use._OnClick()
assert(not P.confirm:IsShown(),"Same current balance could be reserved twice")
'''


cases["each character remembers its own choice without changing other alts"]=r'''
SwitchCharacter("Alice",600000); local G=DragsHedgeFund
G.SetScope(true); G.AddGoal("Shared mount",200,20)
SwitchCharacter("Bob",400000)
assert(G.IsShared(),"New alt did not start with shared goals")
G.SetScope(false); G.AddGoal("Private bags",40,20)
SwitchCharacter("Alice",600000)
assert(G.IsShared() and G.db.goals[1].name=="Shared mount")
SwitchCharacter("Bob",400000)
assert(not G.IsShared() and G.db.goals[1].name=="Private bags")
'''

failures=0
for name,body in cases.items():
 try:
  L=lua51.LuaRuntime(unpack_returned_tuples=True)
  L.execute(harness); L.execute(extra)
  L.execute(r"""
  local mt={}; local function boom() error("secret combat value used") end
  for _,k in ipairs({"__add","__sub","__lt","__le","__eq","__mul","__div"}) do mt[k]=boom end
  function UnitLevel() return setmetatable({},mt) end
  function UnitXP() return setmetatable({},mt) end
  """)
  ns=L.table()
  for file in (root/"DragsHedgeFund.toc").read_text().splitlines():
   if file.strip().endswith(".lua"):
    chunk=L.eval("function(s,n) return assert(loadstring(s,n)) end")((root/file.strip()).read_text(),file.strip())
    chunk("DragsHedgeFund",ns)
  L.execute(body)
  errors=list(L.globals().ERRORS.items())
  assert not errors,errors
  print("PASS",name)
 except Exception as e:
  failures+=1; print("FAIL",name,str(e))
print(f"{len(cases)-failures}/{len(cases)} checks passed")
sys.exit(bool(failures))
