--!nocheck
--[[
	Islands_Fireflies.luau — 숲에 반딧불이를 놓는다.

	숲이 어둡다는 문제를 파트 수를 늘리지 않고 푼다.

	왜 파트를 수백 개 뿌리지 않았나
	  - 반딧불이 한 마리를 파트 하나로 만들면 수천 개가 필요하고 전부 정지해 있다
	  - ParticleEmitter 하나가 떠다니는 알갱이 수십 개를 대신한다. 파트는 하나다
	  - 그래서 **보이지 않는 기둥**을 숲에 흩어 놓고 거기에 방출기를 단다

	PointLight 는 전부에 달지 않는다. 로블록스는 화면에 보이는 광원 수에 한계가 있고
	넘기면 먼 것부터 그냥 꺼진다. 넷 중 하나만 실제로 빛을 낸다.
	나머지는 네온 알갱이라 밝게 보이기만 하고 주변을 비추지는 않는다.

	Islands_Ground.luau 와 Islands_LiftForest.luau 뒤에 실행한다.
	되돌리기: workspace.Surface["R_숲"].Fireflies:Destroy()
]]

local RGB = Color3.fromRGB
local COUNT = 90 -- 방출기 개수
local LIGHT_EVERY = 4 -- 이 간격마다 하나씩만 실제 광원을 단다
local SPAN = 220 -- 한 방출기가 덮는 범위
local LOW, HIGH = 26, 150 -- 지면에서 이 높이 사이를 떠다닌다

local R = workspace.Surface["R_숲"]
local old = R:FindFirstChild("Fireflies")
if old then
	old:Destroy()
end
local fold = Instance.new("Folder")
fold.Name = "Fireflies"
fold.Parent = R

-- 숲 지반 위에만 놓는다. 바다나 다른 섬에 뜨면 안 된다
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Surface.World["G_숲"] }

-- 숲 섬의 범위를 실측한다. 좌표를 손으로 적어두면 섬을 옮길 때마다 틀어진다
local minx, maxx, minz, maxz = 1e9, -1e9, 1e9, -1e9
for _, p in ipairs(workspace.Surface.World["G_숲"]:GetChildren()) do
	if p:IsA("BasePart") then
		minx = math.min(minx, p.Position.X)
		maxx = math.max(maxx, p.Position.X)
		minz = math.min(minz, p.Position.Z)
		maxz = math.max(maxz, p.Position.Z)
	end
end
assert(minx < maxx, "G_숲 이 비었다. 지반을 먼저 깔아라")

local rng = Random.new(77431)
local placed, lights, tries = 0, 0, 0

while placed < COUNT and tries < COUNT * 40 do
	tries += 1
	local x = rng:NextNumber(minx, maxx)
	local z = rng:NextNumber(minz, maxz)
	local hit = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1400, 0), rp)
	if hit then
		placed += 1
		local y = hit.Position.Y + rng:NextNumber(LOW, HIGH)

		local a = Instance.new("Part")
		a.Name = string.format("Ffl_%d_%d", math.floor(x), math.floor(z))
		a.Anchored = true
		a.CanCollide = false
		a.CanQuery = false
		a.CanTouch = false
		a.Transparency = 1
		a.Size = Vector3.new(SPAN, SPAN * 0.55, SPAN) -- 이 부피 안에서 알갱이가 생긴다
		a.Position = Vector3.new(x, y, z)
		a.Parent = fold

		local e = Instance.new("ParticleEmitter")
		e.Name = "Glow"
		-- 노랑에서 연둣빛까지 섞는다. 한 색이면 전구처럼 보인다
		local warm = rng:NextNumber()
		e.Color = ColorSequence.new(RGB(255, 236, 150):Lerp(RGB(176, 255, 142), warm))
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Brightness = 2.4
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.25, rng:NextNumber(0.8, 1.8)),
			NumberSequenceKeypoint.new(0.75, rng:NextNumber(0.8, 1.8)),
			NumberSequenceKeypoint.new(1, 0),
		})
		-- 켜졌다 꺼지는 느낌. 일정하게 빛나면 먼지처럼 보인다
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, 0.05),
			NumberSequenceKeypoint.new(0.45, 0.7),
			NumberSequenceKeypoint.new(0.7, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Rate = rng:NextNumber(3, 7)
		e.Lifetime = NumberRange.new(7, 14)
		e.Speed = NumberRange.new(0.6, 2.4)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, rng:NextNumber(-0.3, 0.4), 0)
		e.Drag = 1.2
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-30, 30)
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Parent = a

		if placed % LIGHT_EVERY == 0 then
			local l = Instance.new("PointLight")
			l.Name = "Lamp"
			l.Color = RGB(196, 255, 160)
			l.Range = rng:NextNumber(34, 54)
			l.Brightness = rng:NextNumber(0.9, 1.6)
			l.Shadows = false -- 그림자를 켜면 수십 개가 곧바로 프레임을 잡아먹는다
			l.Parent = a
			lights += 1
		end
	end
end

assert(placed >= COUNT * 0.7, "반딧불이를 " .. placed .. "개밖에 못 놓았다. 숲 지반을 확인해라")
print(string.format("[Fireflies] 방출기 %d개 / 그중 광원 %d개 (시도 %d)", placed, lights, tries))
