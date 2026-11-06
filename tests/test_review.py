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
assert(DragsHedgeFundFrame.main.spendLabel._text=="CAN SPEND")
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
