--!nocheck
--[[
	Jeolhwa_Sundial.luau — 2026-10-03. 블렌더 앙부일구(models/build_sundial.py → Sundial.fbx)를 틀로 만든다(편집 모드, StudioJobs).
	Ctrl+M 으로 가져온 Workspace.Sundial 을 받아
	  - 원점 표지(Sun_Marker) 밑면을 피벗(대석 밑 가운데)으로
	  - 켜마다 재질·빛(돌은 석회암·점판암, 청동은 녹슨 쇠빛 금속, 시각선은 금빛)
	  - ServerStorage.JeolhwaKit.Sundial 로 옮긴다(Jeolhwa_Infill 의 광장 해시계가 이 틀을 쓴다)
	블렌더 +y(북) = 로블록스 +Z(궁 쪽, 이 판의 북)라 돌리지 않는다. 보고: /sundial
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local RGB = Color3.fromRGB
local LOOK = {
	Granite = { RGB(143, 139, 128), Enum.Material.Slate },
	Stone = { RGB(186, 181, 167), Enum.Material.Limestone },
	Bronze = { RGB(94, 74, 42), Enum.Material.Metal },
	Gilt = { RGB(201, 174, 110), Enum.Material.Metal },
}

local ok, err = pcall(function()
	local fresh = assert(workspace:FindFirstChild("Sundial"), "Workspace.Sundial 이 없다 — FBX 를 먼저 가져올 것")
	local marker
	for _, p in fresh:GetDescendants() do
		if p:IsA("BasePart") and p.Name:match("Marker$") then
			marker = p
		end
	end
	assert(marker, "원점 표지가 없다")
	local origin = CFrame.new(marker.Position - Vector3.new(0, marker.Size.Y / 2, 0))
	marker:Destroy()
	local m = Instance.new("Model")
	m.Name = "Sundial"
	for _, p in fresh:GetDescendants() do
		if p:IsA("BasePart") then
			local key = p.Name:match("_(%a+)$")
			local look = assert(LOOK[key], "모르는 켜 " .. p.Name)
			p.CFrame = origin:ToObjectSpace(p.CFrame)
			p.Color, p.Material = look[1], look[2]
			p.Anchored = true
			if p:IsA("MeshPart") then
				p.RenderFidelity = Enum.RenderFidelity.Precise
				-- 시각선·영침은 가늘어 부딪힐 필요가 없다
				p.CanCollide = key ~= "Gilt"
			end
			p.Name = "Sun_" .. key
			p.Parent = m
		end
	end
	m.WorldPivot = CFrame.new()
	fresh:Destroy()
	local kit = SS.JeolhwaKit
	if kit:FindFirstChild("Sundial") then
		kit.Sundial:Destroy()
	end
	m.Parent = kit
	HS:PostAsync("http://127.0.0.1:34999/sundial", "true 틀 만듦 파트 " .. #m:GetChildren())
end)
if not ok then
	HS:PostAsync("http://127.0.0.1:34999/sundial", "false " .. tostring(err))
end
