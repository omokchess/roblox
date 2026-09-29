--!strict
--[[
	BattleSpectator — 남의 전투를 내 화면에 그린다(2026-09-29 요청: 다른 플레이어가 전투하는 모습이 보이게).

	싸우는 사람의 전투는 그 사람 클라이언트에서만 그려진다(칸·슬라임은 그 클라이언트 것이고, 관절 움직임도
	복제되지 않는다). 서버가 BattleSpectate 로 보내는 요약(자리·체력·사건)을 받아 여기서 다시 그린다.
	  - 칸: BattleStage(싸우는 사람과 같은 평평한 판, 서버가 정한 높이)
	  - 싸우는 사람: 그 캐릭터를 복제한 인형에 같은 연출기(CombatDirector, Quiet)를 붙이고, 진짜 캐릭터는 내 화면에서 숨긴다
	  - 적: 슬라임, 이름표에 체력
	  - 사건(스킬·적 공격)은 받은 순서대로 하나씩 재생한다. 피해 숫자는 사건에 든 값 그대로
	카메라는 건드리지 않고 화면도 흔들지 않는다. 전투가 끝나면(요약이 비면) 치우고 진짜 캐릭터를 다시 보인다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BattleArena = require(ReplicatedStorage.Shared.BattleArena)
local BattleGrid = require(ReplicatedStorage.Shared.BattleGrid)
local BattleStage = require(script.Parent.BattleStage)
local CombatDirector = require(script.Parent.Combat.CombatDirector)

local W = BattleGrid.DEFAULT_WIDTH
local H = BattleGrid.DEFAULT_HEIGHT
local FLOAT_HEIGHT = 3.4
local FIGHTER = "fighter"

type View = {
	UserId: number,
	Seq: number,
	Folder: Folder,
	Layout: BattleArena.Layout,
	Director: any,
	Doll: Model?,
	Hidden: { [Instance]: number },
	LastEvent: number,
	Queue: { any },
	Packet: any,
	PendingRender: boolean,
	Tiles: { [string]: { { BasePart } } },
}

local BattleSpectator = {}

local views: { [number]: View } = {}
-- 내가 싸우는 중이면 남의 전투 판을 모두 감춘다(2026-09-29 요청)
local hiddenAll = false

function BattleSpectator.SetHidden(on: boolean)
	hiddenAll = on
	for _, view in views do
		-- 혼자 확인용(SpectateSelf) 내 관전 화면은 감추지 않는다
		view.Folder.Parent = if on and view.UserId ~= Players.LocalPlayer.UserId then nil else workspace
	end
end

local function home(view: View, side: BattleGrid.Side, x: number, y: number): CFrame
	local cf = BattleArena.CellWorldCFrame(view.Layout, side, x, y, W, H, nil)
	if side == "Ally" then
		local p = (cf + Vector3.new(0, FLOAT_HEIGHT, 0)).Position
		return CFrame.lookAt(p, p + view.Layout.Origin.RightVector)
	end
	return cf + Vector3.new(0, 0.4, 0)
end

-- 진짜 캐릭터를 내 화면에서만 숨긴다(투명도 배율). 돌려놓을 값을 기억한다
local function hide(view: View, character: Model?)
	if not character then
		return
	end
	for _, d in character:GetDescendants() do
		if (d:IsA("BasePart") or d:IsA("Decal")) and view.Hidden[d] == nil then
			local item = d :: any
			view.Hidden[d] = item.LocalTransparencyModifier
			item.LocalTransparencyModifier = 1
		end
	end
end

local function unhide(view: View)
	for d, v in view.Hidden do
		if d.Parent then
			local item = d :: any
			item.LocalTransparencyModifier = v
		end
	end
	view.Hidden = {}
end

-- 싸우는 사람의 인형: 캐릭터를 복제해 스크립트·소리를 빼고 뿌리를 묶는다
local function makeDoll(character: Model, parent: Instance): Model?
	local was = character.Archivable
	character.Archivable = true
	local ok, doll = pcall(function()
		return character:Clone()
	end)
	character.Archivable = was
	if not ok or not doll then
		return nil
	end
	for _, d in doll:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ForceField") or d:IsA("BillboardGui") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.LocalTransparencyModifier = 0
		end
	end
	local root = doll:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
	end
	local humanoid = doll:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		humanoid.PlatformStand = true
	end
	doll.Name = "Spectate_" .. character.Name
	doll.Parent = parent
	return doll
end

local function labelSlime(model: Model, name: string, lift: number?)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local gui = root:FindFirstChild("Info")
	if not gui then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "Info"
		billboard.Size = UDim2.fromOffset(160, 30)
		billboard.StudsOffset = Vector3.new(0, lift or 4.2, 0)
		billboard.MaxDistance = 160
		billboard.Parent = root
		local label = Instance.new("TextLabel")
		label.Name = "Info"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(220, 255, 210)
		label.TextStrokeTransparency = 0.4
		label.Font = Enum.Font.GothamBold
		label.TextSize = 12
		label.Parent = billboard
		gui = billboard
	end
	local label = (gui :: Instance):FindFirstChild("Info")
	if label and label:IsA("TextLabel") then
		label.Text = name
	end
end

local function close(view: View)
	views[view.UserId] = nil
	view.Director:Destroy()
	if view.Doll then
		view.Doll:Destroy()
	end
	view.Folder:Destroy()
	unhide(view)
end

-- 요약대로 자리·체력을 반영한다(연출 중이면 끝난 뒤로 미룬다 — 적이 모션 도중에 옮겨 가지 않게)
local function render(view: View)
	local packet = view.Packet
	local director = view.Director
	local player = Players:GetPlayerByUserId(view.UserId)
	local me = packet.Units.player
	if me and me.X and me.Y then
		local character = player and player.Character
		if not view.Doll and character and character:FindFirstChild("HumanoidRootPart") then
			view.Doll = makeDoll(character, view.Folder)
			if view.Doll then
				local h = home(view, "Ally", me.X, me.Y)
				director:AddHumanoid(FIGHTER, view.Doll, packet.ClassId or "Berserker", h)
				director:SetHome(FIGHTER, h, true)
			end
		end
		if view.UserId ~= Players.LocalPlayer.UserId then
			hide(view, character)
		end
		if director:Has(FIGHTER) and not director:IsHeld(FIGHTER) then
			director:SetHome(FIGHTER, home(view, "Ally", me.X, me.Y))
		end
		-- 싸우는 사람 머리 위 체력(복제한 캐릭터의 표시는 지우고 관전용으로 새로)
		local root = view.Doll and view.Doll:FindFirstChild("HumanoidRootPart")
		if root then
			local gui = root:FindFirstChild("SpectateHp") :: BillboardGui?
			if not gui then
				local b = Instance.new("BillboardGui")
				b.Name = "SpectateHp"
				b.Size = UDim2.fromOffset(150, 24)
				b.StudsOffset = Vector3.new(0, 3.6, 0)
				b.MaxDistance = 160
				b.Parent = root
				local label = Instance.new("TextLabel")
				label.Name = "Text"
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 0.35
				label.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
				label.TextColor3 = Color3.fromRGB(255, 120, 110)
				label.Font = Enum.Font.GothamBold
				label.TextSize = 12
				label.Parent = b
				gui = b
			end
			local label = (gui :: BillboardGui):FindFirstChild("Text")
			if label and label:IsA("TextLabel") then
				label.Text = string.format("%s  체력 %d / %d", me.Name or "", me.Health or 0, me.MaxHealth or 0)
			end
		end
	end
	-- 보스 판: 칸마다 무슨 칸인지(버프·버그·회복·검수 준비중·검수됨!)
	if packet.Board then
		BattleStage.PaintBoard(view.Tiles, packet.Board)
	end
	local seen: { [string]: boolean } = {}
	for id, unit in packet.Units do
		if unit.Side ~= "Enemy" then
			continue
		end
		seen[id] = true
		if not unit.Alive then
			local a = director.Actors[id]
			if a and not a.Dying and not a.PendingDeath then
				director:Kill(id)
			end
			continue
		end
		if not unit.X or not unit.Y then
			continue
		end
		-- 보스 부위(디버그)는 차지한 칸들 가운데에 부위 몸으로
		local h = if unit.Cells then BattleStage.BlockHome(view.Layout, unit.Cells, W, H, nil) else home(view, "Enemy", unit.X, unit.Y)
		if not director:Has(id) then
			director:AddEnemy(id, unit.Part, view.Folder, h)
		end
		director:SetHome(id, h)
		local model = director:Model(id)
		if model then
			local lift = if unit.Part == "Core" then 19.5 elseif unit.Part then 9 else nil
			labelSlime(model, string.format("%s  %d/%d%s", unit.Name, unit.Health, unit.MaxHealth, if unit.Stunned then "  ★그로기" else ""), lift)
		end
	end
	for id in director.Actors do
		if id ~= FIGHTER and not seen[id] then
			director:Remove(id)
		end
	end
end

local function open(packet: any): View?
	local arena = packet.Arena
	if not arena then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "BattleSpectate_" .. packet.UserId
	local selfTest = packet.UserId == Players.LocalPlayer.UserId
	folder.Parent = if hiddenAll and not selfTest then nil else workspace
	-- 시험 화면은 카메라 쪽(판의 로컬 +Z)으로 26 당겨 원래 판 앞에 그린다
	local layout = BattleArena.NewLayout(CFrame.new(arena.X, arena.Y, arena.Z) * CFrame.Angles(0, arena.Yaw or 0, 0) * CFrame.new(0, 0, if selfTest then 26 else 0))
	layout.FlatY = arena.FlatY
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local tiles = BattleStage.Build(folder, layout, arena.BaseY, W, H, params)
	local view: View = {
		UserId = packet.UserId,
		Seq = packet.Seq,
		Folder = folder,
		Layout = layout,
		Director = CombatDirector.new({ Quiet = true }),
		Doll = nil,
		Hidden = {},
		LastEvent = 0,
		Queue = {},
		Packet = packet,
		PendingRender = false,
		Tiles = tiles,
	}
	-- 처음 본 전투의 지난 사건은 재생하지 않는다
	for _, ev in packet.Events or {} do
		view.LastEvent = math.max(view.LastEvent, ev.Seq)
	end
	views[packet.UserId] = view
	return view
end

local function onPacket(packet: any)
	if type(packet) ~= "table" or type(packet.UserId) ~= "number" then
		return
	end
	-- 내 전투는 BattleClient 가 그린다. 시험 스위치(SpectateSelf)면 옆(+Z 36)에 관전 화면을 한 벌 더
	if packet.UserId == Players.LocalPlayer.UserId and workspace:GetAttribute("SpectateSelf") ~= true then
		return
	end
	local view = views[packet.UserId]
	if not packet.Units then
		if view then
			-- 마지막 연출(쓰러짐)을 잠깐 보여 주고 치운다
			task.delay(2.5, function()
				if views[packet.UserId] == view then
					close(view)
				end
			end)
		end
		return
	end
	if view and view.Seq ~= packet.Seq then
		close(view)
		view = nil
	end
	if not view then
		view = open(packet)
		if not view then
			return
		end
		render(view)
		return
	end
	view.Packet = packet
	for _, ev in packet.Events or {} do
		if ev.Seq > view.LastEvent then
			view.LastEvent = ev.Seq
			table.insert(view.Queue, ev)
		end
	end
	if view.Director:IsBusy() or #view.Queue > 0 then
		view.PendingRender = true
	else
		render(view)
	end
end

-- 사건 하나 재생. 스킬은 싸우는 사람이, 적 공격은 그 적이 한다. 결과(숫자·쓰러짐)를 바로 붙인다
local function playEvent(view: View, ev: any)
	local director = view.Director
	local groups = {}
	for i, list in ev.Hits or {} do
		groups[i] = {}
		for _, hit in list do
			table.insert(groups[i], hit.Id == "player" and FIGHTER or hit.Id)
		end
	end
	local function remap(result: any): any
		local copy = table.clone(result)
		copy.Hits = {}
		for i, list in result.Hits or {} do
			copy.Hits[i] = {}
			for _, hit in list do
				local h = table.clone(hit)
				if h.Id == "player" then
					h.Id = FIGHTER
				end
				table.insert(copy.Hits[i], h)
			end
		end
		return copy
	end
	if ev.Kind == "Skill" and director:Has(FIGHTER) then
		local play = director:PlaySkill(FIGHTER, ev.SkillId, groups)
		if play then
			play:SetResult(remap(ev))
		end
	elseif ev.Kind == "EnemyAttack" and director:Has(ev.Actor) then
		local play = director:PlayEnemyAttack(ev.Actor, ev.SkillId or "SlimeTackle", FIGHTER, ev.Grade or "Fail")
		if play then
			play:SetResult(remap(ev))
		end
	end
end

function BattleSpectator.Start(remotes: Folder)
	local remote = remotes:WaitForChild("BattleSpectate", 10)
	if not remote or not remote:IsA("RemoteEvent") then
		return
	end
	remote.OnClientEvent:Connect(onPacket)
	RunService.Heartbeat:Connect(function()
		for _, view in views do
			if view.Director:IsBusy() then
				continue
			end
			local ev = table.remove(view.Queue, 1)
			if ev then
				playEvent(view, ev)
			elseif view.PendingRender then
				view.PendingRender = false
				render(view)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local view = views[player.UserId]
		if view then
			close(view)
		end
	end)
end

return BattleSpectator
