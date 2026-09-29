--!nocheck
--[[
	Swamp2_Build.luau — 2026-09-28. 늪지대 2판(맵 양식)을 짓는다.

	자료(로컬 서버 127.0.0.1:35000 = tools/swamp): ground2.txt, place2.txt, fx2.txt (swamp2_plan.py), flora.txt (swamp_flora.py)
	순서
	1) 1판 지형(매끈한 흙·물)을 늪지대 네모 전체에서 비운다(1판 버그로 섬 밖까지 물이 찼었다). 물빛은 원래 값으로
	2) 숨겼던 흙 판(Gs)을 SwampOld* 속성 값으로 되살린다
	3) 1판 배치(Surface.Swamp_늪지대)를 지우고 Surface.Swamp2_늪지대 에 새로 짓는다
	   땅(구멍 메움 판) · 물(낮은 판 모양 블록 물) · 길(흙 띠·징검돌·돌둑) · 풀나무 · 건물 · 판자길 · 유적 · 소품
	4) 풀나무 틀(ServerStorage.SwampFlora)을 flora.txt 로 다시 만든다: 나무(Wood)만 부딪히고 잎·이끼·갈대·수련은 안 부딪힘
	높이: 숫자 그대로 / "w" 수면(-0.4) / "d" 판자 위(6.6) / "g±n" 흙 판·메움 판·길에 광선
	보고: /swamp2
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local WATER, DECK = -0.4, 6.6
local report = {}

local TEX = {
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
}
local function NS(...)
	local k, a = {}, { ... }
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
local function nums(s)
	local t = {}
	for _, v in ipairs(string.split(s, " ")) do
		t[#t + 1] = tonumber(v)
	end
	return t
end
local function rgb(s)
	local c = string.split(s, ",")
	return Color3.fromRGB(tonumber(c[1]), tonumber(c[2]), tonumber(c[3]))
end

local ok, err = pcall(function()
	local get = function(n)
		return HS:GetAsync("http://127.0.0.1:35000/" .. n, true)
	end
	local groundTxt, placeTxt, fxTxt, floraTxt = get("ground2.txt"), get("place2.txt"), get("fx2.txt"), get("flora.txt")

	-- 1) 1판 지형 비우기
	local T = workspace.Terrain
	for x = 1384, 3327, 486 do
		for z = 452, 1699, 416 do
			T:FillBlock(CFrame.new(x + 243, 2, z + 208), Vector3.new(486, 28, 416), Enum.Material.Air)
		end
		task.wait()
	end
	T.WaterColor = Color3.new(0.05, 0.33, 0.36)
	-- 2) 흙 판 되살림
	local G = workspace.Surface.World["G_늪지대"]
	local restored = 0
	for _, p in ipairs(G:GetChildren()) do
		local tr = p:GetAttribute("SwampOldTransparency")
		if tr ~= nil then
			p.Transparency = tr
			p.CanCollide = p:GetAttribute("SwampOldCollide")
			p.CanQuery = p:GetAttribute("SwampOldQuery")
			p.CastShadow = p:GetAttribute("SwampOldShadow")
			p.CanTouch = true
			for _, k in ipairs({ "SwampOldTransparency", "SwampOldCollide", "SwampOldQuery", "SwampOldShadow" }) do
				p:SetAttribute(k, nil)
			end
			restored += 1
		end
	end
	-- 3) 옛 배치 지우고 새 폴더
	local S = workspace.Surface
	for _, n in ipairs({ "Swamp_늪지대", "Swamp2_늪지대" }) do
		local f = S:FindFirstChild(n)
		if f then
			f:Destroy()
		end
	end
	local root = Instance.new("Folder")
	root.Name = "Swamp2_늪지대"
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
	-- 땅·물·길
	local nG = 0
	for _, line in ipairs(string.split(groundTxt, "\n")) do
		if line ~= "" then
			local f = string.split(line, "\t")
			local pos, size = nums(f[5]), nums(f[7])
			local p = Instance.new("Part")
			p.Name = f[2]
			p.Anchored = true
			p.Material = Enum.Material[f[3]]
			p.Color = rgb(f[4])
			p.Size = Vector3.new(size[1], math.max(size[2], 0.2), size[3])
			p.CFrame = CFrame.new(pos[1], pos[2], pos[3]) * CFrame.Angles(0, math.rad(tonumber(f[6])), 0)
			p.Transparency = tonumber(f[8])
			p.Reflectance = tonumber(f[9])
			p.CanCollide = f[10] == "1"
			if f[1] == "물" then
				p.CanQuery, p.CanTouch, p.CastShadow = false, false, false
			end
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.Parent = group(f[1])
			nG += 1
		end
	end
	root.Parent = S
	-- 4) 풀나무 틀
	local FL = SS:FindFirstChild("SwampFlora")
	if FL then
		FL:Destroy()
	end
	FL = Instance.new("Folder")
	FL.Name = "SwampFlora"
	FL.Parent = SS
	local models = {}
	for _, line in ipairs(string.split(floraTxt, "\n")) do
		if line ~= "" then
			local f = string.split(line, "\t")
			local m = models[f[1]]
			if not m then
				m = Instance.new("Model")
				m.Name = f[1]
				m.Parent = FL
				models[f[1]] = m
			end
			local c, sz = nums(f[5]), nums(f[6])
			local p = Instance.new("Part")
			p.Name = f[2]
			p.Anchored = true
			p.Material = Enum.Material[f[3]]
			p.Color = rgb(f[4])
			p.Size = Vector3.new(sz[1], sz[2], sz[3])
			p.CFrame = CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
			p.CanCollide = f[3] == "Wood" and sz[1] * sz[2] * sz[3] > 3
			p.CanTouch = false
			p.CastShadow = math.max(sz[1], sz[2], sz[3]) > 2.5 and f[3] ~= "Neon"
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.Parent = m
		end
	end
	for _, m in pairs(models) do
		m.WorldPivot = CFrame.new()
	end
	-- 5) 배치
	local kit = assert(SS:FindFirstChild("SwampKit"), "ServerStorage.SwampKit 이 없다")
	local FX = {}
	for _, line in ipairs(string.split(fxTxt, "\n")) do
		if line ~= "" then
			local f = string.split(line, "\t")
			local pos, r = nums(f[3]), nums(f[4])
			local list = FX[f[1]] or {}
			FX[f[1]] = list
			list[#list + 1] = {
				name = f[2],
				cf = CFrame.new(pos[1], pos[2], pos[3], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]),
				w = tonumber(f[5]), h = tonumber(f[6]), color = f[7], text = (f[8] or ""):gsub("\\n", "\n"),
			}
		end
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { G, group("땅"), group("길") }
	local n, nfx, noground, missing = 0, 0, 0, {}
	for _, line in ipairs(string.split(placeTxt, "\n")) do
		if line ~= "" then
			local f = string.split(line, "\t")
			local src, a, x, z, ys, yaw, s, cat = f[1], f[2], tonumber(f[3]), tonumber(f[4]), f[5], tonumber(f[6]), tonumber(f[7]), f[8]
			local t = (src == "K" and kit or FL):FindFirstChild(a)
			if not t then
				missing[a] = (missing[a] or 0) + 1
				continue
			end
			local y = tonumber(ys)
			if not y then
				local head, off = ys:sub(1, 1), tonumber(ys:sub(2)) or 0
				if head == "w" then
					y = WATER + off
				elseif head == "d" then
					y = DECK + off
				else
					local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -200, 0), rp)
					if hit then
						y = hit.Position.Y + off
					else
						y = WATER + off
						noground += 1
					end
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
			for _, mk in ipairs(src == "K" and FX[a] or {}) do
				local wcf = cf * (mk.cf.Rotation + mk.cf.Position * s)
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
			if n % 80 == 0 then
				task.wait()
			end
		end
	end
	local miss = {}
	for k, v in pairs(missing) do
		miss[#miss + 1] = k .. " " .. v
	end
	local parts = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	report[#report + 1] = string.format("흙 판 되살림 %d, 땅·물·길 %d, 풀나무 틀 %d, 배치 %d, 연출 %d, 땅 못 찾음 %d, 틀 없음 [%s], 부품 %d",
		restored, nG, #FL:GetChildren(), n, nfx, noground, table.concat(miss, ", "), parts)
end)
if not ok then
	report[#report + 1] = "ERR " .. tostring(err)
end
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/swamp2", table.concat(report, "\n"))
end)
print("swamp2", table.concat(report, " / "))
