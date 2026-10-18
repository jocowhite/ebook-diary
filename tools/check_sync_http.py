"""Real LuaSocket journal roundtrip against the dashboard with fixture InfluxDB rows.
Requires the sibling my-umbrel-apps checkout, Python and texlua.
The test codec is not KOReader's RapidJSON. No real user data or credentials are used.
"""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
from http.server import ThreadingHTTPServer

root=Path(__file__).resolve().parents[1]
app_dir=root.parent/'my-umbrel-apps/my-store-triathlon-hq/app'
if not app_dir.exists(): raise SystemExit('Optional test requires sibling my-umbrel-apps checkout.')
sys.path.insert(0,str(app_dir))
spec=importlib.util.spec_from_file_location('dashboard_sync',app_dir/'server.py')
app=importlib.util.module_from_spec(spec);spec.loader.exec_module(app)
app.rows=lambda q: ([{'time':'2026-10-16T06:00:00Z','sleepScore':87}] if 'SleepSummary' in q else [{'time':'2026-10-16T15:00:00Z','activityType':'soccer','movingDuration':3600}])
with tempfile.TemporaryDirectory() as temporary:
    temp=Path(temporary)
    app.KINDLE_TOKEN_FILE=temp/'key'
    app.JOURNAL_DB_FILE=temp/'journal.sqlite3'
    token=app.kindle_token(create=True)
    (temp/'local').mkdir()
    (temp/'decode.py').write_text('''import json,sys
p=json.load(open(sys.argv[1]))
def lua(v):
 if v is None: return "nil"
 if isinstance(v,bool): return "true" if v else "false"
 if isinstance(v,(int,float)): return str(v)
 if isinstance(v,str): return json.dumps(v,ensure_ascii=False)
 if isinstance(v,list): return "{"+",".join(lua(x) for x in v)+"}"
 return "{"+",".join("["+lua(k)+"]="+lua(x) for k,x in v.items())+"}"
print("return "+lua(p))
''')
    lua=r'''
local Sync=dofile('koreader/ebookdiary.koplugin/sync.lua')
local Storage=dofile('koreader/ebookdiary.koplugin/storage.lua')
local Model=dofile('koreader/ebookdiary.koplugin/model.lua')
local http=require('socket.http')
package.loaded['socketutil']={set_timeout=function() http.TIMEOUT=2 end,reset_timeout=function() http.TIMEOUT=60 end}
local temp=os.getenv('DIARY_TEST_DIR')
local base=os.getenv('DIARY_TEST_URL')
local token=os.getenv('DIARY_TEST_KEY')
local json={}
function json.encode(v)
 local t=type(v)
 if t=='string' then return '"'..v:gsub('[%z\1-\31\\"]',function(c)
  if c=='"' then return '\\"' elseif c=='\\' then return '\\\\' end
  return string.format('\\u%04x',c:byte())
 end)..'"' end
 if t=='nil' then return 'null' end
 if t=='boolean' or t=='number' then return tostring(v) end
 local parts={}
 if #v>0 then for _,value in ipairs(v)do parts[#parts+1]=json.encode(value)end;return '['..table.concat(parts,',')..']' end
 for key,value in pairs(v)do parts[#parts+1]=json.encode(key)..':'..json.encode(value)end
 return '{'..table.concat(parts,',')..'}'
end
function json.decode(body)
 local file=assert(io.open(temp..'/body.json','w'));file:write(body);file:close()
 local process=assert(io.popen('python3 '..temp..'/decode.py '..temp..'/body.json'))
 local result=process:read('*a');assert(process:close());return assert(load(result))()
end
local store=Storage:new(temp..'/local',json)
local date='2026-10-16'
local entry=Model.entry(date);entry.text='Kindle journal'
store:save(date,entry)
assert(Sync.journal(store,base,'2026-10',json,token)==0)
assert(store:read('2026-10')[date]._sync_revision==1)
local url=base..'/api/kindle/journal?month=2026-10'
local snapshot=Sync.request(url,json,'GET',nil,token,nil,2000000)
local remote=snapshot.entries[1]
assert(remote.entry.text=='Kindle journal')
remote.entry.text='Edited on dashboard'
Sync.request(url,json,'POST',{month='2026-10',entries={{date=date,entry=remote.entry,base_revision=remote.revision}}},token,nil,2000000)
Sync.journal(store,base,'2026-10',json,token)
assert(store:read('2026-10')[date].text=='Edited on dashboard')
entry=store:read('2026-10')[date];entry.text='Offline Kindle draft';store:save(date,entry)
remote.entry.text='Concurrent dashboard draft'
Sync.request(url,json,'POST',{month='2026-10',entries={{date=date,entry=remote.entry,base_revision=2}}},token,nil,2000000)
assert(Sync.journal(store,base,'2026-10',json,token)==1)
assert(store:read('2026-10')[date].text=='Offline Kindle draft')
assert(store:readFile('conflicts-2026-10.json',{})[date].entry.text=='Concurrent dashboard draft')
local metrics=Sync.fetch(base,'2026-10',json,nil,token)
assert(metrics[date].sleep_score==87 and metrics[date].sports.football)
assert(not pcall(Sync.fetch,base,'2026-10',json,nil,'incorrect-key'))
print('PASS: real authenticated LuaSocket upload, SQLite persistence, dashboard edit download, concurrent-edit conflict, metrics and 401 rejection')
'''
    (temp/'test.lua').write_text(lua)
    server=ThreadingHTTPServer(('127.0.0.1',0),app.Handler)
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    environment=dict(os.environ,DIARY_TEST_DIR=str(temp),DIARY_TEST_URL=f'http://127.0.0.1:{server.server_port}',DIARY_TEST_KEY=token)
    try: subprocess.run(['texlua',str(temp/'test.lua')],cwd=root,env=environment,check=True)
    finally: server.shutdown();server.server_close();thread.join()
