--!nocheck
-- BossInfoPreview.luau — 편집 모드에서 보스 정보 창(BattleHud:ShowBossInfo)을 가짜 스냅샷으로 띄워 본다. (2026-10-02)
-- 끄기: game.StarterGui.BossInfoPreview:Destroy()  보고: /bossinfo
local HS = game:GetService("HttpService")
local ok, err = pcall(function()
	local old = game.StarterGui:FindFirstChild("BossInfoPreview")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossInfoPreview"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- 전투 화면(TowerBattleGui)과 같게
	gui.Parent = game.StarterGui
	-- 편집 모드 require 는 한 번 읽은 모듈을 붙잡아 둔다(StudioSync 로 고친 글이 안 보임) → 소스를 새로 읽어 쓴다
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
	local BattleHud = fresh(game.StarterPlayer.StarterPlayerScripts.Client.BattleHud)
	local hud = BattleHud.new(gui, { Select = function() end, Attack = function() end, Stance = function() end, Exit = function() end })
	hud:SetActive(false)
	local function unit(part, hp, max, alive, plan)
		return { Id = "boss_" .. part, Part = part, Health = hp, MaxHealth = max, Alive = alive, Side = "Enemy", Plan = plan }
	end
	local snap = {
		Turn = 3,
		Boss = { Id = "Debug" },
		Units = {
			boss_Head = unit("Head", 0, 20000, false),
			boss_DeleteArm = unit("DeleteArm", 9420, 16000, true, { SkillId = "DeleteCells", Cells = {} }),
			boss_PatchArm = unit("PatchArm", 16000, 16000, true),
			boss_Core = unit("Core", 31877, 48000, true, { SkillId = "MemoryLeak", Cells = {} }),
		},
	}
	hud:ShowBossInfo(snap, "Core")
	return #gui:GetDescendants()
end)
HS:PostAsync("http://127.0.0.1:34999/bossinfo", tostring(ok) .. " " .. tostring(err))
