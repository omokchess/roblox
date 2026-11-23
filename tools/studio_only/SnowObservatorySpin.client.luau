-- SnowObservatorySpin (Workspace.Schneereich.마을, Script · RunContext Client) — 원본 파일. Studio 에 넣기: tools/swamp/_obs_spin_set.luau
-- 2026-11-23 사용자: "천문대 망원경이 해 따라가는 건 그냥 지붕 따라서 움직이는 것처럼 바꾸고"
-- → 별(해)을 띄워 극축으로 따라가던 것을 없애고, 돔이 천천히 돌면 망원경이 돔 틈을 따라 같이 돈다(같은 수직축, 경통 기울기는 그대로).
local CS = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local APERTURE = Vector3.new(3.6, 34.922, -7.752) -- 처음 자세의 경통 끝(차양) — 돔 틈이 이쪽을 보게 맞춘다
local YAW0 = math.atan2(-APERTURE.X, -APERTURE.Z)
local PERIOD = 1200 -- 한 바퀴 20분(서버 시간에 맞춰 모두 같은 각)
local list = {}
local function add(m)
	local dome, scope = m:FindFirstChild("Observatory_Dome"), m:FindFirstChild("Observatory_Scope")
	if dome and scope and not list[m] then
		list[m] = { base = m:GetPivot(), dome = dome, scope = scope }
	end
end
for _, m in CS:GetTagged("SnowObservatory") do
	add(m)
end
CS:GetInstanceAddedSignal("SnowObservatory"):Connect(add)
CS:GetInstanceRemovedSignal("SnowObservatory"):Connect(function(m)
	list[m] = nil
end)
RunService.RenderStepped:Connect(function()
	local yaw = (workspace:GetServerTimeNow() % PERIOD) / PERIOD * 2 * math.pi
	for m, o in list do
		if m.Parent then
			local r = CFrame.Angles(0, yaw, 0)
			o.scope:PivotTo(o.base * r)
			o.dome:PivotTo(o.base * CFrame.Angles(0, YAW0, 0) * r)
		end
	end
end)
