--!nocheck
--[[
	Jeolhwa_GateLift.luau — 2026-09-27. 땅 단 가장자리에 묻힌 북촌 대문 하나를 살린다.

	북촌 대문(-21, 614)은 높이 4.43 짜리 땅 조각(Gs_평원_1_1705)의 북쪽 가장자리(z 613.9)에 섰다.
	앞(남, 로컬 -Z)은 땅이 4.43 높고 뒤(북)는 낮아, 어느 쪽에서도 지나갈 수 없었다(Jeolhwa_GateProbe).
	땅은 사용자 것이라 두고, 대문을 높은 쪽 높이로 올린다. 밑은 돌 기단으로 채우고 낮은 북쪽으로 돌계단 여섯.
	다시 돌려도 두 번 올리지 않는다(속성 Lifted).
]]

local LIFT = 4.43
local STONE = { Color3.fromRGB(193, 190, 176), Enum.Material.Limestone }
local STEP = { Color3.fromRGB(197, 194, 179), Enum.Material.Limestone }

local done = "없음"
for _, m in ipairs(workspace.Jeolhwa:GetDescendants()) do
	if m:IsA("Model") and m.Name == "Wall_GateTile" and not m:GetAttribute("Lifted")
		and (Vector2.new(m:GetPivot().X, m:GetPivot().Z) - Vector2.new(-21, 614)).Magnitude < 3 then
		local pv = m:GetPivot()
		local low = pv.Y
		m:PivotTo(pv + Vector3.new(0, LIFT, 0))
		m:SetAttribute("Lifted", true)
		local function part(name, cf, size, skin)
			local p = Instance.new("Part")
			p.Name = name
			p.Anchored = true
			p.Size = size
			p.CFrame = cf
			p.Color, p.Material = skin[1], skin[2]
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.Parent = m
			return p
		end
		-- 기단. 대문 발자국(x ±10, z -1..4.1)을 낮은 땅부터 새 바닥까지 채운다(남쪽 반은 땅 속)
		part("GateBase", pv * CFrame.new(0, LIFT / 2 - 0.2, 1.3), Vector3.new(20.4, LIFT + 0.4, 5.4), STONE)
		-- 북쪽(+Z) 돌계단. 한 단 0.74 올라가고 0.8 나간다. 문 폭(8)보다 조금 넓게
		for k = 1, 6 do
			local top = LIFT - 0.74 * k
			local z = 4.0 + 0.8 * k - 0.4
			part("GateStep_" .. k, pv * CFrame.new(0, (top - 0.3) / 2, z), Vector3.new(9, math.max(0.2, top + 0.3), 0.8), STEP)
		end
		done = string.format("올림: 바닥 %.2f → %.2f", low, low + LIFT)
	end
end
print("gatelift", done)
