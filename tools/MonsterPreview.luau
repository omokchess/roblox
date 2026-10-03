--!nocheck
-- MonsterPreview.luau — 몬스터(슬라임 셋·보스 디버그 네 부위 — 블록 + 블렌더 장식)를 편집 모드 하늘(0, 760, 300)에 세워 본다. (2026-10-03)
-- 끄기: workspace.MonsterPreview:Destroy()  보고: /monsterpreview
local HS = game:GetService("HttpService")
local ok, err = pcall(function()
	local old = workspace:FindFirstChild("MonsterPreview")
	if old then
		old:Destroy()
	end
	-- 편집 모드 require 캐시를 피해 소스를 새로 읽는다
	local cache = {}
	local function fresh(mod)
		if cache[mod] then
			return cache[mod]
		end
		local f = assert(loadstring(mod.Source, mod:GetFullName()))
		setfenv(f, setmetatable({
			script = mod,
			require = function(m)
				if typeof(m) == "Instance" and m:IsA("ModuleScript") then
					return fresh(m)
				end
				return require(m)
			end,
		}, { __index = getfenv(0) }))
		cache[mod] = f()
		return cache[mod]
	end
	local combat = game.StarterPlayer.StarterPlayerScripts.Client.Combat
	local Slime = fresh(combat.Slime)
	local DebugBoss = fresh(combat.DebugBoss)
	local folder = Instance.new("Folder")
	folder.Name = "MonsterPreview"
	folder.Parent = workspace
	local base = Vector3.new(0, 760, 300)
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(80, 1, 60)
	floor.CFrame = CFrame.new(base + Vector3.new(0, -0.5, 0))
	floor.Color = Color3.fromRGB(70, 74, 64)
	floor.Material = Enum.Material.Slate
	floor.Parent = folder
	-- 슬라임 셋(색 셋) — 정면(-Z)이 카메라 쪽
	for i, col in { Color3.fromRGB(96, 214, 88), Color3.fromRGB(90, 150, 255), Color3.fromRGB(255, 120, 90) } do
		local m = Slime.Build("PreviewSlime" .. i, col)
		m.Parent = folder
		local rig = Slime.new(m)
		rig.Pivot = CFrame.new(base + Vector3.new(-30 + i * 5, 0, -18))
		rig:Apply({ Body = { 0, 0, 0 }, Eyes = { 0, if i == 3 then 100 else 0 } })
	end
	-- 보스: 부위 자리 = 칸 가운데 바닥. 코어 뒤, 머리 가운데 앞, 팔 양옆 앞(한 칸 6)
	local homes = { Core = Vector3.new(6, 0, 6), Head = Vector3.new(6, 0, -9), DeleteArm = Vector3.new(12, 0, -9), PatchArm = Vector3.new(0, 0, -9) }
	for _, key in DebugBoss.Parts do
		local rig = DebugBoss.new(key, CFrame.new(base + homes[key]))
		rig.Model.Parent = folder
		rig:Apply({})
	end
	local n = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("MeshPart") then
			n += 1
		end
	end
	return n
end)
HS:PostAsync("http://127.0.0.1:34999/monsterpreview", tostring(ok) .. " " .. tostring(err))
