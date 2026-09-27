--!strict
-- 대상 고정(록온): 가장 조준에 가까운 적을 고정하고 카메라/캐릭터가 대상을 향하도록 보조.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LockOnController = {}

local player = Players.LocalPlayer
local target: Model? = nil
local reticle: BillboardGui? = nil
local MAX_RANGE = 70

local function rootOf(m: Model?): BasePart?
	return m and m:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function alive(m: Model?): boolean
	if not m or not m.Parent then
		return false
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function makeReticle(m: Model)
	if reticle then
		reticle:Destroy()
	end
	local root = rootOf(m)
	if not root then
		return
	end
	local g = Instance.new("BillboardGui")
	g.Name = "LockReticle"
	g.Size = UDim2.fromOffset(46, 46)
	g.AlwaysOnTop = true
	g.LightInfluence = 0
	g.Adornee = root
	local img = Instance.new("TextLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Text = "◎"
	img.TextScaled = true
	img.TextColor3 = Color3.fromRGB(255, 214, 120)
	img.Font = Enum.Font.GothamBold
	img.Parent = g
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = img
	g.Parent = player:WaitForChild("PlayerGui")
	reticle = g
end

function LockOnController.Target(): Model?
	if target and not alive(target) then
		LockOnController.Clear()
	end
	return target
end

function LockOnController.Clear()
	target = nil
	if reticle then
		reticle:Destroy()
		reticle = nil
	end
end

function LockOnController.FindBest(): Model?
	local cam = workspace.CurrentCamera
	local char = player.Character
	local myRoot = rootOf(char)
	if not myRoot then
		return nil
	end
	local best, bestScore = nil, -math.huge
	local candidates: { Instance } = CollectionService:GetTagged("SwampEnemy")
	for _, m in candidates do
		if not m:IsA("Model") or not alive(m) then
			continue
		end
		local r = rootOf(m)
		if not r then
			continue
		end
		local to = r.Position - myRoot.Position
		local dist = to.Magnitude
		if dist > MAX_RANGE then
			continue
		end
		local dot = cam.CFrame.LookVector:Dot(to.Unit)
		if dot < 0.35 then
			continue
		end
		local score = dot * 2 - dist / MAX_RANGE
		if score > bestScore then
			best, bestScore = m, score
		end
	end
	return best
end

function LockOnController.Toggle()
	if target then
		LockOnController.Clear()
		return
	end
	local best = LockOnController.FindBest()
	if best then
		target = best
		makeReticle(best)
	end
end

function LockOnController.Start()
	RunService:BindToRenderStep("SwampLockOn", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local t = LockOnController.Target()
		if not t then
			return
		end
		local char = player.Character
		local myRoot = rootOf(char)
		local tr = rootOf(t)
		if not myRoot or not tr then
			LockOnController.Clear()
			return
		end
		if (tr.Position - myRoot.Position).Magnitude > MAX_RANGE * 1.3 then
			LockOnController.Clear()
			return
		end
		-- 카메라를 대상 쪽으로 부드럽게 회전 (수평만)
		local cam = workspace.CurrentCamera
		local focus = myRoot.Position + Vector3.new(0, 2, 0)
		local camPos = cam.CFrame.Position
		local offset = camPos - focus
		local dist = offset.Magnitude
		local want = (tr.Position - focus)
		want = Vector3.new(want.X, 0, want.Z)
		if want.Magnitude > 1 and dist > 1 then
			local curFlat = Vector3.new(-offset.X, 0, -offset.Z)
			if curFlat.Magnitude > 0.1 then
				local a1 = math.atan2(-curFlat.X, -curFlat.Z)
				local a2 = math.atan2(-want.X, -want.Z)
				local d = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
				local rot = CFrame.Angles(0, d * math.min(1, dt * 6), 0)
				local newOffset = rot:VectorToWorldSpace(offset)
				local newPos = focus + newOffset
				cam.CFrame = CFrame.lookAt(newPos, newPos + rot:VectorToWorldSpace(cam.CFrame.LookVector))
			end
		end
	end)
end

return LockOnController
