--!nocheck
--[[
	Callisto_Space.luau — 2026-11-01. 블렌더 우주(models/build_callisto_space.py → models/CallistoSpace.fbx)를 Ctrl+M 으로 가져온 뒤
	(Workspace.CallistoSpace) ReplicatedStorage.CallistoAssets.Space(별·성운·행성) / .Galaxy(우리은하)로 나눈다. 피벗 = 원점 표지(전투 필드 가운데).
	클라이언트 Combat/CallistoSpace 가 전투 칸 위에 선 사람에게만 카메라 아래로 복제해 보인다(스카이박스·스카이 스피어 아님). 보고: /calspace
]]
local HS = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local RGB = Color3.fromRGB
local M = Enum.Material
-- { 색, 재질, 투명 }
local SKIN = {
	StarWhite = { RGB(242, 246, 255), M.Neon, 0 },
	StarBlue = { RGB(156, 196, 255), M.Neon, 0 },
	StarGold = { RGB(255, 217, 138), M.Neon, 0 },
	NebulaViolet = { RGB(122, 76, 224), M.Neon, 0.86 },
	NebulaBlue = { RGB(60, 108, 224), M.Neon, 0.87 },
	NebulaPink = { RGB(214, 92, 176), M.Neon, 0.87 },
	PlanetBand = { RGB(201, 162, 122), M.SmoothPlastic, 0 },
	PlanetBand2 = { RGB(142, 106, 78), M.SmoothPlastic, 0 },
	PlanetIce = { RGB(127, 182, 230), M.Glass, 0.05 },
	PlanetRed = { RGB(181, 82, 60), M.SmoothPlastic, 0 },
	Moon = { RGB(184, 182, 176), M.Slate, 0 },
	Ring = { RGB(230, 211, 168), M.Neon, 0.55 },
	GalaxyCore = { RGB(255, 226, 168), M.Neon, 0.1 },
	GalaxyBlue = { RGB(168, 200, 255), M.Neon, 0 },
	GalaxyGold = { RGB(255, 207, 138), M.Neon, 0 },
	GalaxyHaze = { RGB(140, 108, 240), M.Neon, 0.86 },
}
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end
local ok, err = pcall(function()
	local imp = assert(workspace:FindFirstChild("CallistoSpace"), "가져온 Workspace.CallistoSpace 가 없다(Ctrl+M 먼저)")
	local marker = assert(imp:FindFirstChild("SpaceOrigin_Marker", true), "원점 표지가 없다")
	local origin = marker.CFrame
	local folder = RS:FindFirstChild("CallistoAssets") or Instance.new("Folder")
	folder.Name = "CallistoAssets"
	folder.Parent = RS
	local models = {}
	for _, name in { "Space", "Galaxy" } do
		local old = folder:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local m = Instance.new("Model")
		m.Name = name
		models[name] = m
	end
	local n = 0
	for _, p in imp:GetDescendants() do
		if p:IsA("MeshPart") and p ~= marker then
			local pre, key = p.Name:match("^(%a+)_(.+)$")
			local skin = SKIN[key or ""]
			local m = models[pre or ""]
			if skin and m then
				p.CFrame = CFrame.new() * (origin:Inverse() * p.CFrame)
				p.Color, p.Material, p.Transparency = skin[1], skin[2], skin[3]
				p.Anchored = true
				p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
				p.Parent = m
				n += 1
			else
				say("모르는 메시 %s", p.Name)
			end
		end
	end
	for _, m in models do
		m.WorldPivot = CFrame.new()
		m.Parent = folder
	end
	imp:Destroy()
	say("우주 메시 %d (Space %d · Galaxy %d)", n, #models.Space:GetChildren(), #models.Galaxy:GetChildren())
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/calspace", table.concat(lines, "\n"))
