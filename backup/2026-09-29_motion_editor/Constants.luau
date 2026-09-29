--!strict

local Constants = {
	REMOTE_FOLDER = "PorcelainRemotes",
	REMOTES = {
		-- 광장에 세워졌다는 신호. 카메라를 되돌리는 데 쓴다.
		PlazaState = "PlazaState",
		SaveMotion = "SaveMotion",
		RequestMotion = "RequestMotion",
		MotionSaved = "MotionSaved",
		RequestInventory = "RequestInventory",
		InventoryState = "InventoryState",
		EquipMotion = "EquipMotion",
		--[[
			격자 전투 (추가&수정.md `#### 전투 시스템`). 판정은 전부 서버(`BattleService`·`GridBattle`)가 한다.
			  BattleAction / BattleState  입장·디버그·레벨업(카드·스탯)
			  GridAction / GridState      전투 한 판(이동·스킬·회피 → 스냅샷)
			2026-09-28 탑 입장(TowerAction/TowerState)을 걷어내고 이 둘로 바꿨다.
		]]
		BattleAction = "BattleAction",
		BattleState = "BattleState",
		GridAction = "GridAction",
		GridState = "GridState",
	},
	MAX_MOTION_FRAMES = 300,
	MAX_MOTION_DURATION = 30,
}

return table.freeze(Constants)
