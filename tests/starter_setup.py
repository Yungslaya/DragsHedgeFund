ADDON="DragsHedgeFund"
from pathlib import Path
from lupa import lua51
r=Path(__file__).resolve().parents[1]
def load(seed=""):
 L=lua51.LuaRuntime(unpack_returned_tuples=True)
 L.execute((r/'tests/harness.lua').read_text(encoding='utf-8-sig'))
 L.execute(seed)
 ns=L.table()
 for name in (r/ADDON/(ADDON+'.toc')).read_text().splitlines():
  if name.endswith('.lua'):
   L.eval('function(s,n) return assert(loadstring(s,n)) end')((r/ADDON/name).read_text(encoding='utf-8-sig'),name)(ADDON,ns)
 L.execute('FIRE("PLAYER_LOGIN")')
 return L
L=load()
L.execute("""local g=DragsHedgeFund
assert(#g.db.goals==0 and g.TotalOwed()==0 and g.TotalSaved()==0)
assert(g.db.mini and g.db.miniLock and g.db.miniHideCombat and not g.db.miniTips and not g.db.sound)
assert(not g.db.shown and not g.mini:IsShown(),"blank overlay or main window on login")
assert(g.AddGoal("Mount",200,20));g.Refresh()
assert(g.mini:IsShown(),"overlay did not appear after setting a goal")
local combat=false;function InCombatLockdown() return combat end
combat=true;FIRE("PLAYER_REGEN_DISABLED");assert(not g.mini:IsShown(),"overlay visible during combat")
combat=false;FIRE("PLAYER_REGEN_ENABLED");assert(g.mini:IsShown(),"overlay did not return after combat")

MONEY=MONEY+10000;FIRE("PLAYER_MONEY")
local owed=g.TotalOwed();local amount=g.db.goals[1].amount
assert(owed==2000)
g.db.miniTips=true;g.db.sound=true;g.db.miniLock=false
assert(g.StarterSetup());assert(g.TotalOwed()==owed and g.db.goals[1].amount==amount,"preset altered savings")
assert(not g.db.sound and not g.db.miniTips and g.db.miniLock)
assert(g.StarterSetup(true));assert(g.db.sound and g.db.miniTips and not g.db.miniLock)
""")
print('Drags Hedge Fund fresh defaults, goal overlay, real gain tracking and non-destructive preset PASS')

L=load('DragsHedgeFundDB={version=3,goals={},log={},pct=35,nextId=1,mini=false,shown=false}')
L.execute("""local d=DragsHedgeFund.db
assert(not d.mini and not d.shown and d.pct==35,"existing preference lost")
assert(d.sound and d.miniTips and not d.miniLock and not d.miniHideCombat,"legacy implicit choices overwritten")
""")
print('Drags Hedge Fund legacy display preferences PASS')
