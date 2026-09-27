--!strict
-- 지연 보상: 각 전투원의 위치 이력을 저장하고 과거 시점 위치를 보간해 돌려준다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage:WaitForChild("Shared").Combat.CombatConfig)

local LagCompensation = {}

type Sample = { t: number, p: Vector3 }
local history: { [any]: { Sample } } = {}
local RATE = 1 / 30

local lastRecord = 0

function LagCompensation.Record(list: { [any]: any }, now: number)
	if now - lastRecord < RATE then
		return
	end
	lastRecord = now
	local keep = CombatConfig.LagComp.History
	for key, c in list do
		local root = c.Root :: BasePart
		if root and root.Parent then
			local h = history[key]
			if not h then
				h = {}
				history[key] = h
			end
			table.insert(h, { t = now, p = root.Position })
			while #h > 2 and now - h[1].t > keep do
				table.remove(h, 1)
			end
		end
	end
end

function LagCompensation.Forget(key: any)
	history[key] = nil
end

-- t 시점 위치 (범위를 벗어나면 가장 가까운 샘플)
function LagCompensation.PositionAt(key: any, t: number, fallback: Vector3): Vector3
	local h = history[key]
	if not h or #h == 0 then
		return fallback
	end
	if t >= h[#h].t then
		return fallback
	end
	if t <= h[1].t then
		return h[1].p
	end
	for i = #h - 1, 1, -1 do
		local a = h[i]
		if a.t <= t then
			local b = h[i + 1]
			local f = (t - a.t) / math.max(1e-6, b.t - a.t)
			return a.p:Lerp(b.p, f)
		end
	end
	return fallback
end

return LagCompensation
