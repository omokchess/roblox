--!nocheck
--[[
	MaterialPacks_Apply.luau — 크리에이터 스토어 재질 묶음을 받아 몇 가지 재질을 바꾼다. (2026-09-29 요청: "재질도 몇개 플레이스에서 받아오자")
	편집 모드 로더: bash tools/job.sh tools/MaterialPacks_Apply.luau → /matpacks

	받은 것(ServerStorage.MaterialPacks — 쓰지 않는 것도 보관):
	  13591987222  Stylized Handpainted Materials(무료, 만든이: 쓰면 사진 공유·크레딧 환영) — 손그림 재질 16
	               https://devforum.roblox.com/t/free-stylized-handpainted-pbr-materials-pack/2398008
	  11000216412  Realistic Materials (MaterialVariant)(무료) — 사실풍 12. 블록 맵과 안 맞아 지금은 안 씀
	바꾸는 것(MaterialService 기본 재질 덮어쓰기 — 그 재질을 쓰는 부품 전부):
	  Rock→돌  Cobblestone→조약돌  WoodPlanks→널판  Wood→나무껍질  Ground→흙  Snow→눈
	안 바꾸는 것: Grass(어둡고 납작해지고 나뭇잎까지 바뀜), Sand(해변이 샛노래짐), Ice(얼음 탑이 새파래짐) — 2026-09-29 스크린샷으로 비교해 뺐다.
	되돌리기: MaterialService:SetBaseMaterialOverride(Enum.Material.X, "")
]]
local MS = game:GetService("MaterialService")
local SS = game:GetService("ServerStorage")
local out = {}

local holder = SS:FindFirstChild("MaterialPacks")
if not holder then
	holder = Instance.new("Folder")
	holder.Name = "MaterialPacks"
	holder.Parent = SS
end
for _, id in { 13591987222, 11000216412 } do
	if not holder:FindFirstChild("Pack_" .. id) then
		local ok, objs = pcall(function()
			return game:GetObjects("rbxassetid://" .. id)
		end)
		if ok then
			local f = Instance.new("Folder")
			f.Name = "Pack_" .. id
			f.Parent = holder
			for _, o in objs do
				o.Parent = f
			end
		else
			table.insert(out, id .. " 받기 실패: " .. tostring(objs))
		end
	end
end

local pack = holder.Pack_13591987222:FindFirstChild("Handpainted Materials")
local use = { Rock = "Stone", Cobblestone = "Cobblestone", WoodPlanks = "Planks", Wood = "Bark", Ground = "Dirt", Snow = "Snow" }
for base, name in use do
	local v = pack and pack:FindFirstChild(name)
	if v then
		local copy = MS:FindFirstChild("HP_" .. name) or v:Clone()
		copy.Name = "HP_" .. name
		copy.Parent = MS
		MS:SetBaseMaterialOverride(Enum.Material[base], copy.Name)
		table.insert(out, base .. " → HP_" .. name)
	end
end
for _, base in { "Grass", "Sand", "Ice" } do
	MS:SetBaseMaterialOverride(Enum.Material[base], "")
end
pcall(function()
	game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/matpacks", table.concat(out, "\n"))
end)
