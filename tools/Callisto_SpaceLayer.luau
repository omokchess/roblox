--!nocheck
--[[
	Callisto_SpaceLayer.luau — 2026-11-01. models/CallistoSpaceLayer.glb(우주 그림을 입힌 판 — build_space_layer.py)를 3D 가져오기로 넣으면
	그림이 업로드된다. 그 그림 주소를 ReplicatedStorage.CallistoAssets 속성 SpaceLayerImage 로 옮기고 판은 지운다.
	클라이언트 Combat/SpaceLayer(칼리스토 2·3페이즈 '우주를 담은 몸' 레이어)가 이 그림을 화면에 고정해 깐다. 보고: /spacelayer
]]
local HS = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local lines = {}
local ok, err = pcall(function()
	local plate
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") and d.Name:find("CallistoSpaceLayer") then
			plate = d
			break
		end
	end
	assert(plate, "가져온 CallistoSpaceLayer 판이 없다(GLB 를 먼저 가져올 것)")
	local sa = plate:FindFirstChildOfClass("SurfaceAppearance")
	local id = (sa and sa.ColorMap ~= "" and sa.ColorMap) or plate.TextureID
	assert(id and id ~= "", "판에 그림 주소가 없다")
	local kit = RS:FindFirstChild("CallistoAssets") or Instance.new("Folder")
	kit.Name = "CallistoAssets"
	kit.Parent = RS
	kit:SetAttribute("SpaceLayerImage", id)
	table.insert(lines, "SpaceLayerImage = " .. id .. (if sa then " (SurfaceAppearance)" else " (TextureID)"))
	local holder = plate:FindFirstAncestorWhichIsA("Model")
	;(if holder and holder.Parent == workspace then holder else plate):Destroy()
end)
if not ok then
	table.insert(lines, "오류 " .. tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/spacelayer", table.concat(lines, "\n"))
