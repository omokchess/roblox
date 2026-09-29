--!nocheck
--[[
	Swamp_Build.luau — 2026-09-28. 늪지대 배치(수상 마을·마녀 오두막·사당·유적·나무·소품)를 세운다.

	자료: tools/swamp_plan.py 가 만든 tools/swamp/place.txt, fx.txt 를 로컬 서버(127.0.0.1:35000)에서 받는다.
	틀: ServerStorage.SwampKit (Swamp_Kit.luau). 먼저 Swamp_Terrain.luau 로 지형을 깔아야 "g" 높이가 맞는다.
	결과: Workspace.Surface.Swamp_늪지대 (다시 돌리면 통째로 새로 짓는다)
	- 높이 "g" / "g-7" : 지형(물 무시)에 광선을 쏴 그 높이 + 더한 값
	- fx.txt 표지: Fire/Flame(초록)/Smoke/Cauldron 은 입자, Sign*/Board 는 글씨판
	보고: /swampbuild
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local report = {}

local TEX = {
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
}
local function NS(...)
	local k = {}
	local a = { ... }
	for i = 1, #a, 2 do
		k[#k + 1] = NumberSequenceKeypoint.new(a[i], a[i + 1])
	end
	return NumberSequence.new(k)
end
local function holder(name, cf, parent, size)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = size or Vector3.new(1, 1, 1)
	p.CFrame = cf
	p.Parent = parent
	return p
end
local function fire(p, green)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Flames"
	e.Texture = TEX.Fire
	e.LightEmission, e.LightInfluence = 1, 0
	e.Rate = 26
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Acceleration = Vector3.new(0, 3, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Size = NS(0, 1.3, 0.5, 1.0, 1, 0.1)
	e.Transparency = NS(0, 0.3, 0.7, 0.5, 1, 1)
	e.Color = green and ColorSequence.new(Color3.fromRGB(150, 255, 170), Color3.fromRGB(40, 200, 140))
		or ColorSequence.new(Color3.fromRGB(255, 200, 110), Color3.fromRGB(255, 90, 30))
	e.Parent = p
end
local function smoke(p, green, rate)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Smoke"
	e.Texture = TEX.Smoke
	e.Rate = rate or 3
	e.Lifetime = NumberRange.new(4, 7)
	e.Speed = NumberRange.new(2, 3.5)
	e.SpreadAngle = Vector2.new(8, 8)
	e.Acceleration = Vector3.new(1.2, 0.6, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-20, 20)
	e.Size = NS(0, 1.2, 1, 6)
	e.Transparency = NS(0, 0.6, 1, 1)
	e.Color = ColorSequence.new(green and Color3.fromRGB(150, 200, 150) or Color3.fromRGB(170, 170, 170))
	e.LightInfluence = 1
	e.Parent = p
end
local function bubbles(p)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Bubbles"
	e.Texture = TEX.Sparkle
	e.Rate = 10
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(1, 2)
	e.SpreadAngle = Vector2.new(40, 40)
	e.LightEmission = 0.8
	e.Size = NS(0, 0.35, 1, 0.1)
	e.Color = ColorSequence.new(Color3.fromRGB(150, 255, 110))
	e.Parent = p
end
local function sign(p, text, board)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.6
	gui.Parent = p
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = board and Enum.Font.Gotham or Enum.Font.Fantasy
	t.TextScaled, t.TextWrapped = true, true
	t.TextColor3 = board and Color3.fromRGB(46, 34, 24) or Color3.fromRGB(58, 40, 26)
	t.TextXAlignment = board and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
	t.Text = text
	t.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.04, 0), UDim.new(0.04, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.06, 0), UDim.new(0.06, 0)
	pad.Parent = t
end

local ok, err = pcall(function()
	local kit = assert(SS:FindFirstChild("SwampKit"), "ServerStorage.SwampKit 이 없다")
	local place = HS:GetAsync("http://127.0.0.1:35000/place.txt", true)
	local fxt = HS:GetAsync("http://127.0.0.1:35000/fx.txt", true)
	local FX = {}
	for _, line in ipairs(string.split(fxt, "\n")) do
		if line ~= "" then
			local f = string.split(line, "\t")
			local pos = string.split(f[3], " ")
			local r = string.split(f[4], " ")
			local list = FX[f[1]] or {}
			FX[f[1]] = list
			list[#list + 1] = {
				name = f[2],
				cf = CFrame.new(
					tonumber(pos[1]), tonumber(pos[2]), tonumber(pos[3]),
					tonumber(r[1]), tonumber(r[2]), tonumber(r[3]), tonumber(r[4]), tonumber(r[5]),
					tonumber(r[6]), tonumber(r[7]), tonumber(r[8]), tonumber(r[9])
				),
				w = tonumber(f[5]), h = tonumber(f[6]), color = f[7], text = (f[8] or ""):gsub("\\n", "\n"),
			}
		end
	end

	local surf = workspace.Surface
	local old = surf:FindFirstChild("Swamp_늪지대")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Swamp_늪지대"
	local groups = {}
	local function group(name)
		local g = groups[name]
		if not g then
			g = Instance.new("Folder")
			g.Name = name
			g.Parent = root
			groups[name] = g
		end
		return g
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	rp.IgnoreWater = true
	local n, nfx, missing, noground = 0, 0, {}, 0
	for _, line in ipairs(string.split(place, "\n")) do
		if line ~= "" then
			local f = string.split(line, "\t")
			local a, x, z, ys, yaw, s, cat = f[1], tonumber(f[2]), tonumber(f[3]), f[4], tonumber(f[5]), tonumber(f[6]), f[7]
			local t = kit:FindFirstChild(a)
			if not t then
				missing[a] = (missing[a] or 0) + 1
				continue
			end
			local y = tonumber(ys)
			if not y then
				local off = tonumber(ys:sub(2)) or 0
				local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -200, 0), rp)
				if hit then
					y = hit.Position.Y + off
				else
					y = off
					noground += 1
				end
			end
			local m = t:Clone()
			if math.abs(s - 1) > 1e-3 then
				m:ScaleTo(s)
			end
			local cf = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0)
			m:PivotTo(cf)
			m:SetAttribute("Asset", a)
			m.Parent = group(cat)
			n += 1
			for _, mk in ipairs(FX[a] or {}) do
				local lc = mk.cf.Rotation + mk.cf.Position * s
				local wcf = cf * lc
				local nm = mk.name
				if nm == "Fire" then
					local p = holder("Fire", wcf, m)
					fire(p)
					smoke(p, false, 2)
				elseif nm == "Flame" then
					fire(holder("Flame", wcf, m), true)
				elseif nm == "Smoke" then
					smoke(holder("Smoke", wcf, m), mk.color == "green")
				elseif nm == "Cauldron" then
					local p = holder("Cauldron", wcf, m, Vector3.new(2, 0.2, 2))
					bubbles(p)
					smoke(p, true)
				elseif mk.text ~= "" then
					local p = holder(nm .. "Face", wcf * CFrame.new(0, 0, -0.06), m, Vector3.new(mk.w * s, mk.h * s, 0.05))
					sign(p, mk.text, nm == "Board")
				end
				nfx += 1
			end
			if n % 60 == 0 then
				task.wait()
			end
		end
	end
	root.Parent = surf
	local miss = {}
	for k, v in pairs(missing) do
		miss[#miss + 1] = k .. " " .. v
	end
	report[#report + 1] = string.format("배치 %d, 연출 %d, 땅 못 찾음 %d, 틀 없음 [%s]", n, nfx, noground, table.concat(miss, ", "))
end)
if not ok then
	report[#report + 1] = "ERR " .. tostring(err)
end
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/swampbuild", table.concat(report, "\n"))
end)
print("swampbuild", table.concat(report, " / "))
