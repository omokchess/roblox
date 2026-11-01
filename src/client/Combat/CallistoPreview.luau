--!strict
--[[
	CallistoPreview — 스튜디오 전용 칼리스토 페이즈 미리보기(2026-11-01 사용자: "보스 모델을 설원 보스 방 쪽 나열해 둔 데에 쭉 놔 줘, 3페이즈 거도").
	workspace.CallistoPreview(얼어붙은 호수)의 자리표(BasePart, 속성 Page = 1·2·3)마다 플레이할 때 칼리스토를 그 페이즈 모습으로 세운다
	— 우주 그림 창(Combat/SpaceLayer)은 플레이 중 이 사람 화면에만 그려지므로 편집 화면이 아니라 여기서 짓는다.
	  1페이즈: 옷·가면 + 팔 검(날이 나온 채) · 2페이즈: 우주 머리 + 우주 오른팔 + 북두칠성 망치 · 3페이즈: 우주 몸 + 망치
	init.client 가 workspace.CallistoPreview 가 있을 때 스튜디오에서만 부른다. 자리표 = tools/Callisto_PreviewMarks.luau
]]

local Callisto = require(script.Parent.Callisto)
local CombatWeapons = require(script.Parent.CombatWeapons)

local CallistoPreview = {}

-- 모션 없이 세워 두므로 무기 모터는 등록할 곳이 없다(무기는 팔 축 그대로)
local NO_RIG = { SetWeaponMotor = function() end }

function CallistoPreview.Start()
	local folder = workspace:WaitForChild("CallistoPreview", 10)
	if not folder then
		return
	end
	for _, mark in folder:GetChildren() do
		local page = mark:GetAttribute("Page")
		if not mark:IsA("BasePart") or type(page) ~= "number" then
			continue
		end
		local model = Callisto.Build("Callisto_Preview_" .. page)
		model:PivotTo(mark.CFrame)
		model.Parent = folder
		CombatWeapons.Attach(model, NO_RIG, if page >= 2 then "CallistoHammer" else "CallistoArms", "Callisto")
		if page == 1 then
			Callisto.Blade(model, true)
		end
		Callisto.SetPage(model, page)
	end
end

return CallistoPreview
