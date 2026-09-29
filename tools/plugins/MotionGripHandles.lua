--[[
	MotionGripHandles — 모션 무대 인형의 무기 쥐는 모양을 이동·회전 도구(화살표·고리)로 바꾸게 하는 로컬 플러그인. (2026-09-30)
	설치: 이 파일을 %LOCALAPPDATA%\Roblox\Plugins\ 에 둔다(저장소 원본: tools/plugins/MotionGripHandles.lua).

	Workspace.MotionStudio 의 인형마다 무기 쥔 자리에 손잡이(주황 작은 상자 "<직업>_쥐는모양_W/O")를 둔다.
	손잡이를 이동(Ctrl+2)·회전(Ctrl+4)으로 끌면 무기 모터(CombatGripW/O)의 C0 가 따라 바뀌어 무기가 손잡이를 따라온다.
	애니메이션 편집기로 모션을 보는 중에도 손잡이가 손을 따라가고, 끌면 그 자세 그대로 쥐는 모양(C0)만 바뀐다.
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
	end
	do
		-- 팔(1×2×1) 끝보다 조금 크게(팔 옆·아래로 삐져나와 클릭이 맞게), 2026-09-30 크다는 말에 2.4→1.3
		h.Size = Vector3.new(1.3, 1.3, 1.3)
		h.Color = if slot == "W" then Color3.fromRGB(255, 140, 30) else Color3.fromRGB(40, 170, 255)
		h.Material = Enum.Material.Neon
		h.Transparency = 0.35
		h.Anchored = true
		h.CanCollide = false
		h.CanQuery = true
		h.CanTouch = false
		h.CastShadow = false
		h.Parent = studio
	end
	return h
end

-- 지금 무기 쥔 자리(편집기가 자세를 잡으면 Transform 까지 포함 — 모션을 보는 중에도 손을 따라간다)
local function gripCFrame(motor)
	return motor.Part0.CFrame * motor.C0 * motor.Transform * motor.C1:Inverse()
end

local function moved(a, b)
	return (a.Position - b.Position).Magnitude > 1e-3 or (a.LookVector - b.LookVector).Magnitude > 1e-4
		or (a.UpVector - b.UpVector).Magnitude > 1e-4
end

--[[
	손잡이 하나를 매 프레임 맞춘다.
	  사용자가 손잡이를 끌었으면(내가 마지막에 둔 자리와 다르면): C0 = 팔⁻¹ · 손잡이 · C1 · Transform⁻¹
	    — 편집기가 잡은 자세(Transform)는 그대로 두고 기본 쥐는 모양(C0)만 바꾼다
	  아니면: 손잡이를 지금 쥔 자리로(편집기가 모션을 틀면 손을 따라 움직인다)
]]
local function link(studio, rig, slot, motor)
	if links[motor] then
		return
	end
	local h = handleFor(studio, rig, slot, motor)
	local last = gripCFrame(motor)
	h.CFrame = last
	links[motor] = { Handle = h, Last = last }
end

local function step()
	for motor, l in links do
		local h = l.Handle
		if not motor:IsDescendantOf(workspace) or not motor.Part0 or not h.Parent then
			if h.Parent then
				h:Destroy()
			end
			links[motor] = nil
			continue
		end
		if moved(h.CFrame, l.Last) then
			motor.C0 = motor.Part0.CFrame:Inverse() * h.CFrame * motor.C1 * motor.Transform:Inverse()
			l.Last = h.CFrame
		else
			local now = gripCFrame(motor)
			if moved(now, l.Last) then
				h.CFrame = now
				l.Last = now
			end
		end
	end
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
	local t = 0
	while true do
		if os.clock() - t > 2 then
			t = os.clock()
			pcall(scan)
		end
		pcall(step)
		task.wait()
	end
end)
print("[MotionGripHandles] 켜짐 — MotionStudio 인형 무기 손잡이")
