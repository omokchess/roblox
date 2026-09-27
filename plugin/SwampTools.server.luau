--!strict
-- SwampTools Studio 플러그인: 버튼 하나로 에셋 정리 / 월드 생성 / 배치 재생성 / 삭제.
-- 설치: rojo build plugin.project.json -o SwampTools.rbxmx 후 Studio 의 Plugins 폴더에 복사
-- (플러그인 없이도 명령창에서 같은 모듈을 require 해 실행할 수 있다 — README 참고)

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")

local toolbar = plugin:CreateToolbar("Swamp Tools")

local function tools(name: string): any
	local folder = ServerStorage:FindFirstChild("SwampTools")
	local mod = folder and folder:FindFirstChild(name)
	if not mod or not mod:IsA("ModuleScript") then
		warn("[SwampTools] ServerStorage.SwampTools." .. name .. " 을(를) 찾을 수 없습니다. Rojo 동기화/플레이스를 확인하세요.")
		return nil
	end
	return require(mod) :: any
end

local function run(label: string, fn: () -> ...any)
	local recording = ChangeHistoryService:TryBeginRecording(label)
	local ok, err = pcall(fn)
	if recording then
		ChangeHistoryService:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
	end
	if not ok then
		warn("[SwampTools] " .. label .. " 실패: " .. tostring(err))
	else
		print("[SwampTools] " .. label .. " 완료")
	end
end

local buttons = {
	{
		id = "SetupAssets",
		text = "에셋 정리",
		tip = "FBX 임포트한 MeshPart 를 찾아 메시 템플릿(SwampAssetsMesh) 생성 + 월드 배치 교체",
		fn = function()
			local m = tools("AssetSetup")
			if m then
				m.Run({ Rebuild = workspace:FindFirstChild("SwampWorld") ~= nil })
			end
		end,
	},
	{
		id = "BuildWorld",
		text = "월드 생성",
		tip = "바다/섬 지형 + 건물·식생 배치 + 스폰/경계 생성 (저장하면 서버 시작 시 재생성하지 않음)",
		fn = function()
			local m = tools("WorldBuilder")
			if m then
				m.Build({ Clear = true })
			end
		end,
	},
	{
		id = "RebuildPlacements",
		text = "배치 재생성",
		tip = "지형은 그대로 두고 건물·식생만 다시 배치",
		fn = function()
			local m = tools("WorldBuilder")
			if m then
				m.RebuildPlacements()
			end
		end,
	},
	{
		id = "ClearWorld",
		text = "월드 삭제",
		tip = "SwampWorld 폴더와 지형을 모두 삭제",
		fn = function()
			local m = tools("WorldBuilder")
			if m then
				m.Clear()
			end
		end,
	},
}

for _, b in buttons do
	local button = toolbar:CreateButton(b.id, b.tip, "rbxasset://textures/TerrainTools/mt_terrain_import.png", b.text)
	button.ClickableWhenViewportHidden = true
	button.Click:Connect(function()
		run(b.text, b.fn)
		button:SetActive(false)
	end)
end
