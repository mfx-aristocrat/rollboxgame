import importlib.util
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
s=importlib.util.spec_from_file_location('driver',root/'scripts/studio-pickup-check.py')
d=importlib.util.module_from_spec(s);s.loader.exec_module(d)
original=d.Bridge.call
def call(self,name,args,timeout=15):
    if name=='start_playtest':
        self.execute('''local T=game:GetService("StudioTestService"); assert(T.EditModeActive)
local S=game:GetService("ServerStorage");assert(not S:FindFirstChild("__MushroomMultiplayerResult"))
local m=Instance.new("Folder");m.Name="__MushroomMultiplayerResult";m:SetAttribute("OwnedMushroomTest",true);m:SetAttribute("Running",true);m.Parent=S
task.spawn(function() local ok,r=pcall(function()return T:ExecuteMultiplayerTestAsync(2,{players=2})end)
m:SetAttribute("Result",if ok then tostring(r) else game:GetService("HttpService"):JSONEncode({problem=tostring(r)}));m:SetAttribute("Running",false) end)
return game:GetService("HttpService"):JSONEncode({started=true})''')
        return {'success':True}
    if name=='get_playtest_output':
        return self.execute('''local m=game:GetService("ServerStorage"):FindFirstChild("__MushroomMultiplayerResult");assert(m and m:GetAttribute("OwnedMushroomTest")); return game:GetService("HttpService"):JSONEncode({isRunning=m:GetAttribute("Running"),testResult=m:GetAttribute("Result")})''')
    return original(self,name,args,timeout)
d.Bridge.call=call
status=d.main()
b=d.Bridge('http://127.0.0.1:58741',{'calls':[]})
b.require_idle()
b.execute('''local m=game:GetService("ServerStorage"):FindFirstChild("__MushroomMultiplayerResult");if m then assert(m:GetAttribute("OwnedMushroomTest") and not m:GetAttribute("Running"));m:Destroy()end; return game:GetService("HttpService"):JSONEncode({cleaned=true})''')
sys.exit(status)
