--!strict
-- 에셋 템플릿 조회: 메시 버전(FBX 임포트 후 AssetSetup 으로 생성)을 우선, 없으면 Part 버전.
--   서버: ServerStorage/ReplicatedStorage 모두 탐색
--   클라이언트: ReplicatedStorage 만 (배 등 복제 에셋)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AssetLibrary = {}

AssetLibrary.MESH_FOLDER = "SwampAssetsMesh"
AssetLibrary.PART_FOLDER = "SwampAssets"

local function containers(): { Instance }
	local list: { Instance } = {}
	local ServerStorage = if RunService:IsServer() then game:GetService("ServerStorage") else nil
	for _, folderName in { AssetLibrary.MESH_FOLDER, AssetLibrary.PART_FOLDER } do
		local rep = ReplicatedStorage:FindFirstChild(folderName)
		if rep then
			table.insert(list, rep)
		end
		if ServerStorage then
			local srv = ServerStorage:FindFirstChild(folderName)
			if srv then
				table.insert(list, srv)
			end
		end
	end
	return list
end

function AssetLibrary.Get(name: string): Model?
	for _, c in containers() do
		local m = c:FindFirstChild(name)
		if m and m:IsA("Model") then
			return m
		end
	end
	return nil
end

-- 클라이언트용: 복제 에셋이 도착할 때까지 대기
function AssetLibrary.WaitFor(name: string, timeout: number?): Model?
	local deadline = os.clock() + (timeout or 20)
	while os.clock() < deadline do
		local m = AssetLibrary.Get(name)
		if m then
			return m
		end
		task.wait(0.25)
	end
	return nil
end

function AssetLibrary.Clone(name: string): Model?
	local t = AssetLibrary.Get(name)
	if not t then
		return nil
	end
	return t:Clone()
end

function AssetLibrary.IsMesh(model: Model): boolean
	return model:GetAttribute("Kind") == "Mesh"
end

-- 모델 안의 마커(Attachment) 찾기
function AssetLibrary.Marker(model: Model, name: string): Attachment?
	local anchor = model:FindFirstChild("Anchor")
	if not anchor then
		return nil
	end
	local a = anchor:FindFirstChild(name)
	if a and a:IsA("Attachment") then
		return a
	end
	return nil
end

function AssetLibrary.Markers(model: Model, prefix: string?): { Attachment }
	local out = {}
	local anchor = model:FindFirstChild("Anchor")
	if anchor then
		for _, a in anchor:GetChildren() do
			if a:IsA("Attachment") and (prefix == nil or string.sub(a.Name, 1, #prefix) == prefix) then
				table.insert(out, a)
			end
		end
	end
	return out
end

return AssetLibrary
