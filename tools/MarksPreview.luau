--!nocheck
-- MarksPreview.luau — 편집 모드에서 보스 검수 칸 묶음 표시(BattleStage.GroupMarks)를 하늘 위 가짜 판에 그려 본다. (2026-10-02)
-- 끄기: workspace.MarksPreview:Destroy()  보고: /markspreview
local HS = game:GetService("HttpService")
local ok, err = pcall(function()
	local old = workspace:FindFirstChild("MarksPreview")
	if old then
		old:Destroy()
	end
	local BattleStage = require(game.StarterPlayer.StarterPlayerScripts.Client.BattleStage)
	local root = Instance.new("Folder")
	root.Name = "MarksPreview"
	root.Parent = workspace
	local base = Vector3.new(0, 700, 0)
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(44, 1, 26)
	floor.CFrame = CFrame.new(base + Vector3.new(15, -0.6, 6))
	floor.Color = Color3.fromRGB(40, 42, 52)
	floor.Material = Enum.Material.Slate
	floor.Parent = root
	local tilesFolder = Instance.new("Folder")
	tilesFolder.Name = "Tiles"
	tilesFolder.Parent = root
	local tiles = { Ally = {}, Enemy = {} }
	local cell = 6
	for y = 1, 3 do
		tiles.Ally[y] = {}
		for x = 1, 6 do
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.Transparency = 1
			p.Size = Vector3.new(cell - 0.2, 0.05, cell - 0.2)
			p.CFrame = CFrame.new(base + Vector3.new((x - 1) * cell, 0.12, (y - 1) * cell))
			p.Parent = tilesFolder
			local box = Instance.new("SelectionBox")
			box.Name = "Mark"
			box.Adornee = p
			box.LineThickness = 0.05
			box.Parent = p
			BattleStage.Paint(p, BattleStage.TILE_IDLE, false)
			tiles.Ally[y][x] = p
		end
	end
	-- 예고(검수 준비중): 번개 무늬 비슷하게 두 덩어리 / 검수됨: 오른쪽 두 칸
	local pending = { ["1,1"] = true, ["2,1"] = true, ["2,2"] = true, ["3,2"] = true, ["3,3"] = true, ["1,3"] = true }
	local gone = { ["5,1"] = true, ["6,1"] = true, ["6,2"] = true }
	for key in pending do
		local x, y = string.match(key, "(%d+),(%d+)")
		BattleStage.Paint(tiles.Ally[tonumber(y)][tonumber(x)], BattleStage.BOARD.Pending, true)
	end
	for key in gone do
		local x, y = string.match(key, "(%d+),(%d+)")
		BattleStage.PaintGone(tiles.Ally[tonumber(y)][tonumber(x)])
	end
	BattleStage.GroupMarks(tiles, "Pending", pending)
	BattleStage.GroupMarks(tiles, "Gone", gone)
	local n = 0
	for _ in tilesFolder:GetDescendants() do
		n += 1
	end
	return n
end)
HS:PostAsync("http://127.0.0.1:34999/markspreview", tostring(ok) .. " " .. tostring(err))
