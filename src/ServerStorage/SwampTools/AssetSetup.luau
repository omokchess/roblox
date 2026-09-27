--!strict
-- FBX 임포트 후처리 도구 (Studio 전용)
--
-- 사용법
--   1) Studio > 3D Importer(또는 Asset Manager 일괄 임포트)로 assets/fbx/*.fbx 를 가져온다.
--      임포트된 모델은 Workspace 어디에 있든 상관없다.
--   2) 명령창:  require(game.ServerStorage.SwampTools.AssetSetup).Run()
--      - 이름(<에셋>__<재질키>)으로 MeshPart 를 찾아 매니페스트대로 크기/위치/재질/색을 복원
--      - Part 버전 템플릿의 충돌체·마커·조명을 그대로 가져와 메시 버전 템플릿을 만든다
--      - 결과: ServerStorage/ReplicatedStorage 의 "SwampAssetsMesh" 폴더
--   3) Run({ Rebuild = true }) 이면 월드 배치도 메시 버전으로 다시 만든다.
--
-- 임포트 단위(스터드/미터) 설정이 달라도 매니페스트의 크기로 강제 복원하므로 안전하다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetLibrary = require(Shared:WaitForChild("World"):WaitForChild("AssetLibrary"))
local Manifest = require(script.Parent:WaitForChild("AssetManifest"))

local AssetSetup = {}

export type Options = {
	Sources: { Instance }?, -- 임포트된 MeshPart 를 찾을 범위 (기본: Workspace, ServerStorage, ReplicatedStorage)
	Rebuild: boolean?, -- 월드 배치 재생성
	DeleteImported: boolean?, -- 원본 임포트 모델 삭제 (기본 true)
	Only: { string }?, -- 특정 에셋만
}

local function normalize(name: string): string
	-- 임포터가 붙이는 접미사 제거 (예: "Name.001", "Name (1)")
	local n = string.gsub(name, "%.%d+$", "")
	n = string.gsub(n, "%s*%(%d+%)$", "")
	return n
end

local function collectMeshParts(sources: { Instance }): { [string]: MeshPart }
	local found: { [string]: MeshPart } = {}
	for _, src in sources do
		for _, d in src:GetDescendants() do
			if d:IsA("MeshPart") then
				local key = normalize(d.Name)
				-- 이미 우리가 만든 메시 템플릿 안의 것은 제외
				local inTemplates = d:FindFirstAncestor(AssetLibrary.MESH_FOLDER) ~= nil
				if not inTemplates and string.find(key, "__", 1, true) and not found[key] then
					found[key] = d
				end
			end
		end
	end
	return found
end

local function meshFolder(replicated: boolean): Folder
	local parent: Instance = if replicated then ReplicatedStorage else ServerStorage
	local existing = parent:FindFirstChild(AssetLibrary.MESH_FOLDER)
	if existing then
		return existing :: Folder
	end
	local f = Instance.new("Folder")
	f.Name = AssetLibrary.MESH_FOLDER
	f.Parent = parent
	return f
end

local function partTemplate(name: string): Model?
	for _, parent in { ReplicatedStorage, ServerStorage } :: { Instance } do
		local f = parent:FindFirstChild(AssetLibrary.PART_FOLDER)
		local m = f and f:FindFirstChild(name)
		if m and m:IsA("Model") then
			return m
		end
	end
	return nil
end

local function applyInfo(mp: MeshPart, info: any)
	mp.Anchored = true
	mp.CanCollide = false
	mp.CanQuery = false
	mp.CanTouch = false
	mp.Massless = true
	mp.Size = Vector3.new(info.z[1], info.z[2], info.z[3])
	mp.CFrame = CFrame.new(info.p[1], info.p[2], info.p[3])
	local ok = pcall(function()
		mp.Material = (Enum.Material :: any)[info.m]
	end)
	if not ok then
		mp.Material = Enum.Material.SmoothPlastic
	end
	mp.Color = Color3.fromRGB(info.c[1], info.c[2], info.c[3])
	mp.Transparency = info.t
	mp.CastShadow = info.sh
	mp.TextureID = ""
	for _, c in mp:GetChildren() do
		if c:IsA("SurfaceAppearance") or c:IsA("Decal") or c:IsA("Texture") then
			c:Destroy()
		end
	end
	-- Studio 전용 속성 (플러그인/명령창 권한에서만 쓰기 가능)
	pcall(function()
		(mp :: any).DoubleSided = info.ds
	end)
	pcall(function()
		mp.CollisionFidelity = Enum.CollisionFidelity.Box
	end)
	pcall(function()
		mp.RenderFidelity = Enum.RenderFidelity.Automatic
	end)
end

function AssetSetup.Run(opts: Options?): { built: { string }, missing: { [string]: { string } } }
	local o: Options = opts or {}
	local sources = o.Sources or { workspace, ServerStorage, ReplicatedStorage }
	local found = collectMeshParts(sources)
	local report = { built = {} :: { string }, missing = {} :: { [string]: { string } } }
	local usedSources: { [Instance]: boolean } = {}

	local names = {}
	for name in Manifest do
		table.insert(names, name)
	end
	table.sort(names)
	for _, assetName in names do
		if o.Only and not table.find(o.Only, assetName) then
			continue
		end
		local info = Manifest[assetName]
		local hits, misses = 0, {}
		for _, pi in info.Parts do
			if found[pi.n] then
				hits += 1
			else
				table.insert(misses, pi.n)
			end
		end
		if hits == 0 then
			continue
		end
		local base = partTemplate(assetName)
		if not base then
			warn("[AssetSetup] Part 템플릿 없음:", assetName)
			continue
		end
		local model = base:Clone()
		model:SetAttribute("Kind", "Mesh")
		local oldVisual = model:FindFirstChild("Visual")
		if oldVisual then
			oldVisual:Destroy()
		end
		local visual = Instance.new("Model")
		visual.Name = "Visual"
		visual.Parent = model
		local groups: { [string]: Model } = {}
		for _, pi in info.Parts do
			local src = found[pi.n]
			if not src then
				continue
			end
			local mp = src:Clone()
			mp.Name = pi.n
			for _, c in mp:GetChildren() do
				if not c:IsA("SurfaceAppearance") then
					c:Destroy()
				end
			end
			applyInfo(mp, pi)
			local parent: Instance = visual
			if pi.g ~= "Main" then
				local g = groups[pi.g]
				if not g then
					local newGroup = Instance.new("Model")
					newGroup.Name = pi.g
					newGroup.Parent = visual
					groups[pi.g] = newGroup
					g = newGroup
				end
				parent = g
			end
			mp.Parent = parent
			local top = src:FindFirstAncestorWhichIsA("Model")
			if top then
				-- 최상위 임포트 모델 기록 (정리용)
				local cur: Instance = top
				while cur.Parent and cur.Parent ~= workspace and cur.Parent:IsA("Model") do
					cur = cur.Parent
				end
				usedSources[cur] = true
			end
		end
		model.WorldPivot = CFrame.new()
		local folder = meshFolder(info.Replicated)
		local old = folder:FindFirstChild(assetName)
		if old then
			old:Destroy()
		end
		model.Parent = folder
		table.insert(report.built, assetName)
		if #misses > 0 then
			report.missing[assetName] = misses
		end
	end

	if o.DeleteImported ~= false then
		for inst in usedSources do
			if inst.Parent and inst:FindFirstAncestor(AssetLibrary.MESH_FOLDER) == nil then
				inst:Destroy()
			end
		end
	end

	print(string.format("[AssetSetup] 메시 템플릿 %d개 생성", #report.built))
	for asset, list in report.missing do
		warn(string.format("[AssetSetup] %s: 누락 파트 %d개 (%s)", asset, #list, table.concat(list, ", ")))
	end
	if o.Rebuild then
		local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder")) :: any
		WorldBuilder.RebuildPlacements()
	end
	return report
end

-- 메시 템플릿 삭제 (Part 버전으로 되돌리기)
function AssetSetup.Revert()
	for _, parent in { ReplicatedStorage, ServerStorage } :: { Instance } do
		local f = parent:FindFirstChild(AssetLibrary.MESH_FOLDER)
		if f then
			f:Destroy()
		end
	end
	print("[AssetSetup] 메시 템플릿 제거 — Part 버전 사용")
end

return AssetSetup
