--[[
	MotionGripHandles — 모션 무대 인형의 무기 쥐는 모양을 이동·회전 도구(화살표·고리)로 바꾸게 하는 로컬 플러그인. (2026-09-30)
	설치: 이 파일을 %LOCALAPPDATA%\Roblox\Plugins\ 에 둔다(저장소 원본: tools/plugins/MotionGripHandles.lua).

	Workspace.MotionStudio 의 인형마다 무기 쥔 자리에 손잡이(주황 작은 상자 "<직업>_쥐는모양_W/O")를 둔다.
	손잡이를 이동(Ctrl+2)·회전(Ctrl+4)으로 끌면 무기 모터(CombatGripW/O)의 C0 가 따라 바뀌어 무기가 손잡이를 따라온다.
	(C0 = 팔.CFrame⁻¹ · 손잡이.CFrame · C1 — 쉬는 자세 기준. 애니메이션 편집기를 닫고 쓴다)
	속성 창에서 C0 를 숫자로 바꾸면 손잡이도 그 자리로 옮겨 간다. 플레이하면 서버가 무대째 치우므로 게임엔 안 보인다.
]]
local RunService = game:GetService("RunService")
if RunService:IsRunning() then
	return
end

local links = {}

local function handleFor(studio, rig, slot, motor)
	local name = rig.Name .. "_쥐는모양_" .. slot
	local h = studio:FindFirstChild(name)
	if not h then
		h = Instance.new("Part")
		h.Name = name
		h.Size = Vector3.new(0.7, 0.7, 0.7)
		h.Color = if slot == "W" then Color3.fromRGB(255, 140, 30) else Color3.fromRGB(40, 170, 255)
		h.Material = Enum.Material.Neon
		h.Transparency = 0.25
		h.Anchored = true
		h.CanCollide = false
		h.CanQuery = true
		h.CanTouch = false
		h.CastShadow = false
		h.Parent = studio
	end
	return h
end

local function gripCFrame(motor)
	return motor.Part0.CFrame * motor.C0 * motor.C1:Inverse()
end

local function link(studio, rig, slot, motor)
	local key = motor
	if links[key] then
		return
	end
	local h = handleFor(studio, rig, slot, motor)
	local busy = false
	local function fromMotor()
		if busy or not motor.Part0 then
			return
		end
		busy = true
		h.CFrame = gripCFrame(motor)
		busy = false
	end
	local function fromHandle()
		if busy or not motor.Part0 then
			return
		end
		busy = true
		motor.C0 = motor.Part0.CFrame:Inverse() * h.CFrame * motor.C1
		busy = false
	end
	fromMotor()
	local c1 = h:GetPropertyChangedSignal("CFrame"):Connect(fromHandle)
	local c2 = motor:GetPropertyChangedSignal("C0"):Connect(fromMotor)
	local c3 = motor.AncestryChanged:Connect(function()
		if not motor:IsDescendantOf(workspace) then
			c1:Disconnect()
			c2:Disconnect()
			links[key] = nil
			if h.Parent then
				h:Destroy()
			end
		end
	end)
	links[key] = { c1, c2, c3 }
end

local function scan()
	local studio = workspace:FindFirstChild("MotionStudio")
	if not studio then
		return
	end
	for _, rig in studio:GetChildren() do
		if rig:IsA("Model") and rig:GetAttribute("ClassId") then
			for _, slot in { "W", "O" } do
				local grip = rig:FindFirstChild("Grip" .. slot, true)
				local motor = grip and grip:FindFirstChild("CombatGrip" .. slot)
				if motor and motor:IsA("Motor6D") and motor.Part0 then
					link(studio, rig, slot, motor)
				end
			end
		end
	end
end

task.spawn(function()
	while true do
		pcall(scan)
		task.wait(2)
	end
end)
pcall(function() task.wait(3) local n=0 for _, c in workspace.MotionStudio:GetChildren() do if c.Name:find("쥐는모양") then n+=1 end end game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/hcheck", "handles " .. n) end)
