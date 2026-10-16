"""Local contract test: real LuaSocket client against the dashboard with fixture InfluxDB data.
Run from the ebook-diary root with sibling my-umbrel-apps, Python and texlua present.
"""
import importlib.util,json,threading,subprocess,tempfile,pathlib
from http.server import ThreadingHTTPServer
root=pathlib.Path(__file__).resolve().parents[1]
p=root.parent/'my-umbrel-apps/my-store-triathlon-hq/app/server.py'
if not p.exists(): raise SystemExit('This optional test requires the sibling my-umbrel-apps checkout.')
s=importlib.util.spec_from_file_location('dashboard',p);app=importlib.util.module_from_spec(s);s.loader.exec_module(app)
app.rows=lambda q: ([{'time':'2026-10-16T06:00:00Z','sleepScore':87}] if 'SleepSummary' in q else [{'time':'2026-10-16T15:00:00Z','activityType':'soccer','movingDuration':3600}])
server=ThreadingHTTPServer(('127.0.0.1',0),app.Handler);thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
# Actual LuaSocket -> actual dashboard HTTP handler. JSON is decoded with Python
# solely as a test bridge because the cloud Lua runtime lacks KOReader RapidJSON.
with tempfile.TemporaryDirectory() as d:
 d=pathlib.Path(d)
 (d/'decode.py').write_text('''import json,sys
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
 (d/'test.lua').write_text(f'''local Sync=dofile('koreader/ebookdiary.koplugin/sync.lua')
local http=require('socket.http')
package.loaded['socketutil']={{set_timeout=function() http.TIMEOUT=2 end,reset_timeout=function() http.TIMEOUT=60 end}}
local json={{decode=function(body)
 local f=assert(io.open('{d}/body.json','w'));f:write(body);f:close()
 local process=assert(io.popen('python3 {d}/decode.py {d}/body.json'));local result=process:read('*a');assert(process:close());return assert(load(result))()
end}}
local days=Sync.fetch('http://127.0.0.1:{server.server_port}','2026-10',json)
assert(days['2026-10-16'].sleep_score==87 and days['2026-10-16'].sports.football)
print('PASS: actual LuaSocket client fetched and validated data from the real dashboard HTTP handler (fixture InfluxDB rows, test JSON bridge)')
''')
 try: subprocess.run(['texlua',str(d/'test.lua')],cwd=root,check=True)
 finally:server.shutdown();server.server_close();thread.join()
