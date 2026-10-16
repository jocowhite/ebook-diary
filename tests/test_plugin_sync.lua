local Model=dofile('koreader/ebookdiary.koplugin/model.lua')
local Sync=dofile('koreader/ebookdiary.koplugin/sync.lua')
local json={null=function()end}
local payload={month='2026-10',days={{date='2026-10-16',sleep_score=0,activities={{type='swimming',duration_minutes=42},{type='padel',duration_minutes=60}}}}}
json.decode=function() return Model.copy(payload) end
local cached={days={['2026-10-15']={sleep_score=80,sports={cycling=true}}}}
local writes=0
local store={readMetrics=function()return Model.copy(cached)end,writeFile=function(_,name,value)assert(name=='metrics-2026-10.json');writes=writes+1;cached=Model.copy(value)end}
local function transport(url) assert(url=='http://192.168.178.98:8477/api/kindle/days?month=2026-10');return 'test response' end
Sync.run(store,Sync.default_url,'2026-10',json,transport)
assert(writes==1 and cached.days['2026-10-16'].sleep_score==0 and cached.days['2026-10-16'].sports.swimming and cached.days['2026-10-15'].sleep_score==80)
local day=Model.withMetrics('2026-10-16',nil,cached.days['2026-10-16']);assert(day.sleep_score==0 and day.sports.padel)
local manual=Model.entry('2026-10-16');manual.sleep_score=99;manual.sports={football=true}
assert(Model.withMetrics('2026-10-16',manual,cached.days['2026-10-16']).sleep_score==99)
assert(Model.withMetrics('2026-10-16',manual,cached.days['2026-10-16']).sports.football)
manual.sleep_score=nil;manual.sleep_manual=true;manual.sports={};manual.sports_manual=true
local explicit=Model.withMetrics('2026-10-16',manual,cached.days['2026-10-16']);assert(explicit.sleep_score==nil and next(explicit.sports)==nil)
manual.sleep_manual=false;manual.sports_manual=false
assert(Model.withMetrics('2026-10-16',manual,cached.days['2026-10-16']).sleep_score==0)
for _,bad in ipairs({101,-1,1.5,'80'}) do
 payload.days[1].sleep_score=bad
 assert(not pcall(Sync.run,store,Sync.default_url,'2026-10',json,transport));assert(writes==1 and cached.days['2026-10-16'].sleep_score==0)
end
payload.days[1].sleep_score=70
payload.days[2]=Model.copy(payload.days[1]);assert(not pcall(Sync.run,store,Sync.default_url,'2026-10',json,transport));payload.days[2]=nil
payload.month='2026-09';assert(not pcall(Sync.run,store,Sync.default_url,'2026-10',json,transport));payload.month='2026-10'
assert(not pcall(Sync.run,store,Sync.default_url,'2026-10',json,function()error('offline')end));assert(writes==1)
assert(not pcall(Sync.url,'http://example.com/path','2026-10'))
assert(not pcall(Sync.url,'http://user:password@example.com','2026-10'))
-- Actual HTTP wrapper: redirects/errors are rejected, bounds applied, timeouts restored.
local reset,mode=0,'ok'
package.loaded['socket']=nil;package.loaded['socket.http']=nil;package.loaded['socketutil']=nil
package.preload['socket']=function()return{gettime=function()return 1 end}end
package.preload['socketutil']=function()return{set_timeout=function()end,reset_timeout=function()reset=reset+1 end}end
package.preload['socket.http']=function()return{request=function(request)
 assert(request.redirect==false and request.method=='GET' and request.headers.Accept=='application/json')
 if mode=='throw' then error('offline') end
 if mode=='redirect' then return 1,302 end
 if mode=='large' then assert(not request.sink(string.rep('x',500001)));return nil,'sink failed' end
 request.sink('test response');request.sink(nil);return 1,200
end}end
Sync.run(store,Sync.default_url,'2026-10',json);assert(reset==1 and writes==2)
for _,failure in ipairs({'redirect','large','throw'})do mode=failure;assert(not pcall(Sync.run,store,Sync.default_url,'2026-10',json));assert(writes==2)end
assert(reset==4)
mode='ok';payload.days[1].sleep_score=json.null;payload.days[1].activities=json.null
Sync.run(store,Sync.default_url,'2026-10',json)
assert(cached.days['2026-10-16'].sleep_score==nil and cached.days['2026-10-16'].sports==nil)
assert(cached.days['2026-10-15'].sleep_score==80)
print('PASS: monthly sync, zero, all-or-nothing validation, cache retention, offline/redirect/size failures, timeout cleanup and manual overrides')
