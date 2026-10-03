--!nocheck
-- SingularitySwordPreview.luau — 특이점의 떨어지는 검(퀘이사 대검 2.2배, 끝이 아래)을 편집 모드 하늘(0, 760, 0)에 띄워 본다. (2026-10-03)
-- 끄기: workspace.SingularitySwordPreview:Destroy()  보고: /swordpreview
local HS = game:GetService("HttpService")
local ok, err = pcall(function()
	local old = workspace:FindFirstChild("SingularitySwordPreview")
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
	local CombatWeapons = fresh(game.StarterPlayer.StarterPlayerScripts.Client.Combat.CombatWeapons)
	local WeaponDefinitions = fresh(game.ReplicatedStorage.Shared.Combat.WeaponDefinitions)
	local w = setmetatable({ Def = WeaponDefinitions.Get("Greatsword") }, CombatWeapons)
	local model = w:ClonePiece("W")
	model.Name = "SingularitySwordPreview"
	local pivot = model:GetPivot()
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local rel = pivot:ToObjectSpace(p.CFrame)
			p.Size *= 2.2
			p.CFrame = pivot * (CFrame.new(rel.Position * 2.2) * rel.Rotation)
		end
	end
	model:PivotTo(CFrame.new(0, 760, 0) * CFrame.Angles(math.pi, 0, 0))
	model.Parent = workspace
	return #model:GetChildren()
end)
HS:PostAsync("http://127.0.0.1:34999/swordpreview", tostring(ok) .. " " .. tostring(err))
