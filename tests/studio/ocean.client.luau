-- Owned temporary runtime fixture. Exercises native input and actual character motion.
local Players=game:GetService("Players")
local Rep=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local Log=game:GetService("LogService")
local player=Players.LocalPlayer
local probe=Rep:WaitForChild("__RollboxOceanProbe",20)
if not probe then return end
local remotes=Rep:WaitForChild("Remotes",20)
local latest,crateEvents,fireEvents,swimFrames=nil,0,0,0
remotes.Snapshot.OnClientEvent:Connect(function(data) latest=data end)
UIS.InputBegan:Connect(function(input) if input.KeyCode==Enum.KeyCode.F then fireEvents+=1 end end)
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
	if prompt.Name=="OpenOrangeMushroomCrate" then crateEvents+=1 end
end)
Run.Heartbeat:Connect(function()
	local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if h and h:GetState()==Enum.HumanoidStateType.Swimming then swimFrames+=1 end
end)
local virtual=UIS:CreateVirtualInput()
local function key(code)
	assert(virtual,"VirtualInput unavailable");virtual:SendKey(true,code,false);task.wait(0.04);virtual:SendKey(false,code,false)
end
local function vector(array) return Vector3.new(table.unpack(array)) end
probe.OnClientEvent:Connect(function(stage,command)
	task.spawn(function()
		local ok,data=pcall(function()
			local char=player.Character
			local root,h=char.HumanoidRootPart,char:FindFirstChildOfClass("Humanoid")
			local start=root.Position
			local aim
			if command.kind=="e" then key(Enum.KeyCode.E);task.wait(0.6)
			elseif command.kind=="q" then key(Enum.KeyCode.Q);task.wait(0.6)
			elseif command.kind=="r" then key(Enum.KeyCode.R);task.wait(0.7)
			elseif command.kind=="invalid" then
				for _,payload in {"bad",Vector3.new(0/0,0,0),Vector3.zero,Vector3.new(1000,0,0)} do remotes.CannonFire:FireServer(payload);task.wait(0.08) end
				remotes.CannonFire:FireServer(Vector3.new(1,0,0),"extra");task.wait(0.6)
			elseif command.kind=="shoot" or command.kind=="burst" or command.kind=="focus" then
				local target=vector(command.target)
				if command.kind=="shoot" or command.kind=="focus" then
					local camera=workspace.CurrentCamera
					camera.CameraType=Enum.CameraType.Scriptable
					local horizontal=Vector3.new(target.X-start.X,0,target.Z-start.Z).Unit
					camera.CFrame=CFrame.lookAt(start-horizontal*15+Vector3.new(0,8,0),target)
					task.wait(0.15)
					local screen=camera:WorldToScreenPoint(target)
					local inset=game:GetService("GuiService"):GetGuiInset()
                    virtual:SendMousePosition(Vector2.new(screen.X,screen.Y)+inset)
					task.wait(0.1)
					local pointer=UIS:GetMouseLocation()
					local ray=camera:ScreenPointToRay(pointer.X-inset.X,pointer.Y-inset.Y)
					aim={wanted={screen.X+inset.X,screen.Y+inset.Y},pointer={pointer.X,pointer.Y},
						origin={ray.Origin.X,ray.Origin.Y,ray.Origin.Z},direction={ray.Direction.X,ray.Direction.Y,ray.Direction.Z}}
					if command.kind=="focus" then
						local box=Instance.new("TextBox");box.Size=UDim2.fromOffset(100,40);box.Parent=player.PlayerGui.CourierHUD
						box:CaptureFocus();key(Enum.KeyCode.F);box:ReleaseFocus();box:Destroy()
					else key(Enum.KeyCode.F) end
					camera.CameraType=Enum.CameraType.Custom
				else
					local direction=(target-(root.Position+Vector3.new(0,1,0))).Unit
					for _=1,20 do remotes.CannonFire:FireServer(direction) end
				end
				task.wait(1)
			elseif command.kind=="walk" then
				local target=vector(command.target)
				Run:BindToRenderStep("__OceanWalk",Enum.RenderPriority.Input.Value+1,function()
                    local delta=target-root.Position
                    local horizontal=Vector3.new(delta.X,0,delta.Z)
                    h:Move(if horizontal.Magnitude>0.4 then horizontal.Unit else Vector3.zero,false)
                end)
                local deadline=os.clock()+(command.seconds or 12)
				repeat task.wait(0.05) until (root.Position-target).Magnitude<4 or os.clock()>deadline
				Run:UnbindFromRenderStep("__OceanWalk");h:Move(Vector3.zero);task.wait(0.2)
			elseif command.kind=="swim" then
				virtual:SendKey(true,Enum.KeyCode.W,false);task.wait(1.2);virtual:SendKey(false,Enum.KeyCode.W,false);task.wait(0.3)
			else task.wait(0.4) end
			local errors={}
			for _,row in Log:GetLogHistory() do if row.messageType==Enum.MessageType.MessageError and #errors<12 then table.insert(errors,row.message) end end
			local panel=player.PlayerGui.CourierHUD.StatusPanel
			return {snapshot=latest,position={root.Position.X,root.Position.Y,root.Position.Z},
				distance=(root.Position-start).Magnitude,state=h:GetState().Name,swimFrames=swimFrames,
				crateEvents=crateEvents,fireEvents=fireEvents,cannon=char:FindFirstChild("PracticeCannon")~=nil,
				weapon=panel.Weapon.Text,errors=errors,aim=aim}
		end)
		probe:FireServer({stage=stage,ok=ok,data=if ok then data else {problem=tostring(data)}})
	end)
end)
task.wait(1)
probe:FireServer({stage="ready",ok=true,data={}})
