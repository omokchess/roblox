--!nocheck
--[[
	Fix_Coplanar.luau — 2026-10-04. 같은 평면에 같은 쪽을 보는 면이 겹친 블록(깜박임)을 찾아 한쪽 면을 0.04 안으로 당긴다.
	사용자: "절화 건물쪽, 투명벽이랑 아직 겹쳐서 반짝거리는 블록들이 좀 보여".
	대상: Workspace.Jeolhwa 의 모든 BasePart(투명벽 포함) + 옛 평원 지형 윗판(_풀)·사막·평원 채움은 짓기에서 따로 막았다.
	방법: 부품 A 와 닿는 부품 B(GetPartsInPart)가 A 와 축이 맞으면(90° 배수) A 의 좌표계에서 두 상자의 같은 쪽 면(최대·최소)이
	  0.02 안으로 겹치고 다른 두 축으로 넓이가 겹치면, B 의 그 면을 0.04 안으로(크기 −0.04, 가운데 0.02 이동). 메시 부품은 크기를 건드리지 않고 건너뜀.
	  고친 부품엔 속성 CoplanarFix 를 붙여 두 번 고치지 않는다. 보고: /coplanar
]]
local HS = game:GetService("HttpService")
local TOL, PULL = 0.02, 0.04
local roots = { workspace:FindFirstChild("Jeolhwa") }
local parts = {}
for _, r in roots do
	for _, d in r:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
end
local over = OverlapParams.new()
over.FilterType = Enum.RaycastFilterType.Include
over.FilterDescendantsInstances = roots
local fixed, checked = 0, 0
local done = {}
for i, a in parts do
	if i % 300 == 0 then
		task.wait()
	end
	if not a.Parent then
		continue
	end
	local a0 = a
	for _, b in workspace:GetPartsInPart(a0, over) do
		local a = a0
		local ha
		-- 둘 중 하나는 고칠 수 있는 Part 여야(메시는 크기를 바꾸면 모양이 늘어나므로 안 건드림). 고치는 쪽 = Part 인 B, 아니면 A
		if b == a or done[b] or not (b:IsA("Part") or a:IsA("Part")) then
			continue
		end
		if not b:IsA("Part") then
			a, b = b, a -- B 를 고칠 Part 로(아래 셈은 A 기준 — 짝을 바꿔도 같은 셈)
		end
		ha = a.Size / 2
		checked += 1
		local rel = a.CFrame:ToObjectSpace(b.CFrame)
		local R = { rel.RightVector, rel.UpVector, -rel.LookVector } -- B 의 축을 A 좌표로
		-- 90° 배수인지 + B 의 각 축이 A 의 어느 축인지
		local map, ok = {}, true
		for j, v in R do
			local comps = { v.X, v.Y, v.Z }
			local found = false
			for ax = 1, 3 do
				if math.abs(math.abs(comps[ax]) - 1) < 1e-3 then
					map[ax] = j
					found = true
				end
			end
			if not found then
				ok = false
			end
		end
		if not ok then
			continue
		end
		local bs = { b.Size.X / 2, b.Size.Y / 2, b.Size.Z / 2 }
		local hb = { bs[map[1]], bs[map[2]], bs[map[3]] } -- A 축 기준 B 반크기
		local c = { rel.X, rel.Y, rel.Z }
		local h = { ha.X, ha.Y, ha.Z }
		for ax = 1, 3 do
			local o1, o2 = ax % 3 + 1, (ax + 1) % 3 + 1
			local overlap1 = math.abs(c[o1]) < h[o1] + hb[o1] - 0.01
			local overlap2 = math.abs(c[o2]) < h[o2] + hb[o2] - 0.01
			if overlap1 and overlap2 then
				for _, sgn in { 1, -1 } do
					local fa = sgn * h[ax]
					local fb = c[ax] + sgn * hb[ax]
					if math.abs(fa - fb) < TOL then
						-- B 의 이 면을 안으로: B 의 축 j 크기 −PULL, 가운데를 A 축 ax 방향으로 −sgn·PULL/2
						local j = map[ax]
						local sz = { b.Size.X, b.Size.Y, b.Size.Z }
						if sz[j] > PULL * 3 then
							sz[j] -= PULL
							local dirA = ({ a.CFrame.RightVector, a.CFrame.UpVector, -a.CFrame.LookVector })[ax]
							local cf = b.CFrame
							b.Size = Vector3.new(sz[1], sz[2], sz[3])
							b.CFrame = cf - dirA * (sgn * PULL / 2)
							b:SetAttribute("CoplanarFix", (b:GetAttribute("CoplanarFix") or 0) + 1)
							fixed += 1
							hb[ax] -= PULL / 2
							c[ax] -= sgn * PULL / 2
						end
					end
				end
			end
		end
	end
	done[a0] = true
end
HS:PostAsync("http://127.0.0.1:34999/coplanar", string.format("부품 %d · 닿은 짝 %d · 고친 면 %d", #parts, checked, fixed))
