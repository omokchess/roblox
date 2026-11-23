--!nocheck
-- Snow_HQClock_Restore.luau — 2026-11-23. 기물군 본부(Figuren_HQ) 시계 바늘 되살리기.
-- 사용자(2026-11-23): "기물군 본부 시계바늘이었어?! 그거 복구해줘." — 본부를 옮기자 바늘이 옛 자리에 떠 있어 지워졌던 것.
-- Snow_City2.luau(3b 톱니 절, Figuren_HQ)와 같은 식으로 본부 피벗 기준 시계 판 앞에 다시 만든다(배율 1.0).
-- 마을.톱니 폴더에 넣고 SnowGear 태그(SnowGearSpin 이 Speed 로 돌림). 이미 있으면 지우고 다시. → 보고 /hqclock
local CS = game:GetService("CollectionService")
local HS = game:GetService("HttpService")
local RGB = Color3.fromRGB
local out = {}
local ok, err = pcall(function()
	local town = workspace.Schneereich["마을"]
	local hq = assert(town:FindFirstChild("Figuren_HQ", true), "Figuren_HQ 가 없다")
	local f = town:FindFirstChild("톱니")
	if not f then
		f = Instance.new("Folder")
		f.Name = "톱니"
		f.Parent = town
	end
	for _, c in f:GetChildren() do
		if c.Name:match("^ClockHand_") or c.Name == "ClockPin" then
			c:Destroy()
		end
	end
	local IRON = { RGB(58, 60, 66), Enum.Material.Metal }
	local BRASS = { RGB(184, 145, 63), Enum.Material.Metal }
	local function part(name, cf, size, col, parent, shape)
		local p = Instance.new("Part")
		p.Name = name
		if shape then
			p.Shape = shape
		end
		p.Anchored = true
		p.CanCollide = false
		p.Size = size
		p.CFrame = cf
		p.Color, p.Material = col[1], col[2]
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = parent
		return p
	end
	local sc = 1.0
	local k = sc * 1.25
	local c = hq:GetPivot() * CFrame.new(0, 41.0 * sc, (-34.9 - 0.15) * sc)
	for _, hd in ipairs({ { "Hour", 0.55, 2.3, 0.25, 125 }, { "Minute", 0.38, 3.3, 3.0, 10 } }) do
		local m = Instance.new("Model")
		m.Name = "ClockHand_" .. hd[1]
		local zoff = (hd[1] == "Hour" and 0 or -0.25) * k
		part(hd[1], c * CFrame.new(0, (hd[3] / 2 - 0.35) * k, zoff), Vector3.new(hd[2] * k, hd[3] * k, 0.22), IRON, m)
		m.WorldPivot = c
		m:PivotTo(c * CFrame.Angles(0, 0, math.rad(hd[5])))
		m:SetAttribute("Speed", hd[4])
		CS:AddTag(m, "SnowGear")
		m.Parent = f
	end
	part("ClockPin", c * CFrame.new(0, 0, -0.45 * k) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.3, 0.7 * k, 0.7 * k), BRASS, f, Enum.PartType.Cylinder)
	-- 시계 판 앞면이 정말 거기 있는지: 판 가운데에서 본부 쪽(+Z 로컬)으로 광선
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { hq }
	local hit = workspace:Raycast(c.Position + c.LookVector * 2, -c.LookVector * 4, rp)
	table.insert(out, string.format("바늘 둘 + 핀: 시계 가운데 %.1f, %.1f, %.1f · 판 앞면 확인 %s", c.X, c.Y, c.Z,
		hit and string.format("맞음(%s, 거리 %.2f)", hit.Instance.Name, hit.Distance) or "못 맞음 — 자리 확인 필요"))
end)
if not ok then
	table.insert(out, "오류: " .. tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/hqclock", table.concat(out, "\n"))
