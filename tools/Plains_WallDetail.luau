--!nocheck
--[[
	Plains_WallDetail.luau — 2026-10-04. 평원 높은 덩어리(돌산·언덕) 맨 바위 벽에 꾸밈(편집 모드, StudioJobs).
	사용자(사막 협곡): "협곡 벽면이 너무 휑하니까 이것도 손보고 … 이건 평원도 마찬가지야"
	Surface.R_평원*/Masses 와 R_평원채움/Masses 의 바위 상자(이름에 _풀 없는 것) 중 보이는 높이 12 이상인 것의 네 벽에
	  지층 띠 둘(높이 35%·68%, 1 튀어나옴, 어둡고 밝은 회색) · 기둥 버팀(26 마다, 폭·높이 엇갈림) · 밑동 돌무더기(18 마다).
	윗켜에 가려 안 보이는 벽(다른 덩어리 안으로 들어간 부분)은 광선으로 걸러 짓지 않는다.
	Surface.R_평원벽 만 지우고 새로 짓는다. 다시 지을 때 순서: Plains_Build … Plains_RampSteps → Plains_Fill → 이것(단 높이로 올라간 뒤의 자리로 짓는다).
	보고: /plainswall
]]
local HS = game:GetService("HttpService")
local RGB = Color3.fromRGB
local ROCK, ROCK2 = RGB(132, 130, 124), RGB(118, 116, 111)
local BAND1, BAND2 = RGB(104, 102, 97), RGB(156, 153, 145)
local COLW = { 7, 10, 6, 9, 8 }
local COLH = { 0.62, 0.9, 0.48, 0.78, 0.7, 0.55 }
local RUB = { 4.5, 3, 5.5, 3.5, 6, 4 }

local lines = {}
local ok, err = pcall(function()
	local surface = workspace.Surface
	local old = surface:FindFirstChild("R_평원벽")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "R_평원벽"
	root.Parent = surface
	-- 땅(덩어리·단·땅 판·절벽)
	local ground = {}
	local blocks = {}
	for _, f in surface:GetChildren() do
		if f.Name:match("^R_평원") and f ~= root then
			for _, sub in { "Land", "Masses", "Cliffs", "Plateaus", "Ramps" } do
				local x = f:FindFirstChild(sub)
				if x then
					table.insert(ground, x)
					if sub == "Masses" then
						for _, p in x:GetChildren() do
							if p:IsA("BasePart") and not p.Name:match("_풀$") then
								table.insert(blocks, p)
							end
						end
					end
				end
			end
		end
	end
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = ground
	local function groundAt(x, z, below)
		local hit = workspace:Raycast(Vector3.new(x, below, z), Vector3.new(0, -below - 60, 0), ray)
		return if hit then hit.Position.Y else nil
	end
	local function part(name, size, cf, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = Enum.Material.Slate
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = root
		return p
	end
	local count, walls = 0, 0
	for bi, b in blocks do
		local pos, size = b.Position, b.Size
		local x0, x1, z0, z1 = pos.X - size.X / 2, pos.X + size.X / 2, pos.Z - size.Z / 2, pos.Z + size.Z / 2
		local top = pos.Y + size.Y / 2 + 1.2 -- 풀 윗판까지
		for f, face in { { z0, x0, x1, -1, true }, { z1, x0, x1, 1, true }, { x0, z0, z1, -1, false }, { x1, z0, z1, 1, false } } do
			local at, a0, a1, out, alongX = face[1], face[2], face[3], face[4], face[5]
			local mid = (a0 + a1) / 2
			local px, pz = if alongX then mid else at + out * 1.5, if alongX then at + out * 1.5 else mid
			-- 이 벽 앞 땅 높이(벽 바로 바깥, 벽 윗면 아래에서 잰다). 보이는 높이 12 안 되면 건너뜀
			local gy = groundAt(px, pz, top - 0.5)
			if not gy or top - gy < 12 then
				continue
			end
			walls += 1
			local h = top - gy
			local function box(name, along0, along1, off0, off1, y0, y1, color)
				local o0, o1 = at + out * off0, at + out * off1
				local bx0, bx1 = if alongX then along0 else math.min(o0, o1), if alongX then along1 else math.max(o0, o1)
				local bz0, bz1 = if alongX then math.min(o0, o1) else along0, if alongX then math.max(o0, o1) else along1
				part(name, Vector3.new(bx1 - bx0, y1 - y0, bz1 - bz0), CFrame.new((bx0 + bx1) / 2, (y0 + y1) / 2, (bz0 + bz1) / 2), color)
				count += 1
			end
			box(string.format("Band%d_%d_a", bi, f), a0, a1, -0.5, 1.0, gy + h * 0.35 - 0.7, gy + h * 0.35 + 0.7, BAND1)
			box(string.format("Band%d_%d_b", bi, f), a0, a1, -0.5, 0.8, gy + h * 0.68 - 0.5, gy + h * 0.68 + 0.5, BAND2)
			local k, s = 0, a0 + 8 + (bi * 7) % 11
			while s < a1 - 6 do
				k += 1
				local w = COLW[(bi + k) % #COLW + 1]
				local hh = COLH[(bi * 3 + k) % #COLH + 1]
				box(string.format("Col%d_%d_%d", bi, f, k), s - w / 2, math.min(a1, s + w / 2), -0.5, 2.5, gy - 1, gy + h * hh, if k % 2 == 0 then ROCK else ROCK2)
				s += 26
			end
			local r, q = 0, a0 + 5 + (bi * 5) % 9
			while q < a1 - 4 do
				r += 1
				local sz = RUB[(bi + r * 2) % #RUB + 1]
				local cx = if alongX then q else at + out * (sz / 2 + 0.5)
				local cz = if alongX then at + out * (sz / 2 + 0.5) else q
				local y = groundAt(cx, cz, top - 0.5) or gy
				part(string.format("Rubble%d_%d_%d", bi, f, r), Vector3.new(sz, sz * 0.7, sz * 0.85), CFrame.new(cx, y + sz * 0.3, cz) * CFrame.Angles(0, math.rad(r * 37), 0), if r % 2 == 0 then ROCK else ROCK2)
				count += 1
				q += 18
			end
		end
	end
	table.insert(lines, string.format("벽 %d · 부품 %d (덩어리 %d)", walls, count, #blocks))
end)
HS:PostAsync("http://127.0.0.1:34999/plainswall", tostring(ok) .. " " .. tostring(err) .. "\n" .. table.concat(lines, "\n"))
