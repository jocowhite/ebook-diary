local Model=dofile('koreader/ebookdiary.koplugin/model.lua')
local Sync=dofile('koreader/ebookdiary.koplugin/sync.lua')
local blobs={}
local json={encode=function(value)blobs[#blobs+1]=Model.copy(value);return tostring(#blobs)end,decode=function(body)return Model.copy(assert(blobs[tonumber(body)]))end}
local date='2026-10-16'
local local_entries={[date]=Model.entry(date,{text='Legacy Kindle ♥',habits={true,false,true}})}
local files,writes={},0
local store={read=function()return Model.copy(local_entries)end,readConfig=Model.defaultConfig,
 writeFile=function(_,name,value)
  writes=writes+1
  if name=='2026-10.json' then local_entries=Model.copy(value) else files[name]=Model.copy(value) end
 end}
local remote={},last_payload
local lost=false
local function transport(url,method,body,token)
 assert(url=='http://192.168.178.98:8477/api/kindle/journal?month=2026-10' and method=='POST' and token=='fixture-key')
 local payload=json.decode(body);last_payload=payload
 local conflicts={}
 for _,item in ipairs(payload.entries) do
  local current=remote[item.date]
  if current and current.entry.text==item.entry.text then
  elseif (current and current.revision or 0)~=item.base_revision then conflicts[#conflicts+1]=item.date
  else remote[item.date]={date=item.date,revision=item.base_revision+1,entry=Model.copy(item.entry)} end
 end
 if lost then lost=false;error('response lost after accepted upload') end
 local records={};for _,record in pairs(remote)do records[#records+1]=Model.copy(record)end
 return json.encode({month='2026-10',entries=records,conflicts=conflicts})
end
assert(Sync.journal(store,Sync.default_url,'2026-10',json,'fixture-key',transport)==0)
assert(remote[date].entry.text=='Legacy Kindle ♥' and local_entries[date]._sync_revision==1 and local_entries[date]._sync_dirty==false)
assert(last_payload.columns.outside=='Draußen' and last_payload.entries[1].entry._sync_revision==nil)
remote[date].entry.text='Edited in dashboard';remote[date].revision=2
Sync.journal(store,Sync.default_url,'2026-10',json,'fixture-key',transport)
assert(#last_payload.entries==0 and local_entries[date].text=='Edited in dashboard' and local_entries[date]._sync_revision==2)
local_entries[date].text='Offline Kindle';local_entries[date]._sync_dirty=true
remote[date].entry.text='Parallel dashboard';remote[date].revision=3
local_entries['2026-10-17']=Model.entry('2026-10-17');local_entries['2026-10-17'].text='Another day'
assert(Sync.journal(store,Sync.default_url,'2026-10',json,'fixture-key',transport)==1)
assert(local_entries[date].text=='Offline Kindle' and local_entries[date]._sync_dirty)
assert(files['conflicts-2026-10.json'][date].entry.text=='Parallel dashboard')
assert(local_entries['2026-10-17']._sync_dirty==false)
-- Explicitly choosing the Kindle version uses the remote revision as a base.
local_entries[date]._sync_revision=3
assert(Sync.journal(store,Sync.default_url,'2026-10',json,'fixture-key',transport)==0)
assert(remote[date].entry.text=='Offline Kindle' and local_entries[date]._sync_revision==4)
local_entries[date].text='Retry me';local_entries[date]._sync_dirty=true;lost=true
assert(not pcall(Sync.journal,store,Sync.default_url,'2026-10',json,'fixture-key',transport))
assert(local_entries[date]._sync_dirty and local_entries[date]._sync_revision==4)
Sync.journal(store,Sync.default_url,'2026-10',json,'fixture-key',transport)
assert(local_entries[date]._sync_revision==5 and not local_entries[date]._sync_dirty)
local before=writes
assert(not pcall(Sync.journal,store,Sync.default_url,'2026-10',json,'fixture-key',function()return json.encode({month='2026-09',entries={},conflicts={}})end))
assert(writes==before)
assert(not pcall(Sync.journal,store,Sync.default_url,'2026-10',json,'fixture-key',function()return json.encode({month='2026-10',entries={{date=date,revision=6,entry={text='invalid'}}},conflicts={}})end))
assert(writes==before and local_entries[date].text=='Retry me')
print('PASS: legacy upload, dashboard download, revisions, conflicts preserve both copies, independent day accepted, lost-response retry and malformed response safety')
