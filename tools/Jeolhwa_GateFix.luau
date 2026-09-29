--!nocheck
--[[
	Jeolhwa_GateFix.luau — 2026-09-27. 절화 문간을 막던 충돌을 끈다.

	문 모델은 재질별로 메시 하나씩이라, 문짝 띠(낮음)와 현판·용마루·서까래(높음)가 한 메시에 든
	재질이 볼록 껍질(Hull) 충돌로 문간 전체를 투명한 벽으로 채웠다 (Jeolhwa_GateProbe 로 확인).
	  Gate_Palace, Gate_Hall : *_RoofEdge  (문짝 띠 + 현판 테 + 용마루)
	  Wall_GateTile          : *_Eave      (문짝 띠 + 처마 서까래)
	  Granary                : *_Eave      (반쯤 연 문짝 + 건물을 두른 판자 띠 → 곳간 전체를 채움)
	  Shop_Row5, Shop_Row3   : *_Eave, *_RoofEdge, *_Onggi (칸마다 좌판 널·궤짝·항아리가 한 메시)
	모두 장식이라 충돌이 필요 없다. 문짝·기둥·벽·지붕 몸은 그대로 부딪힌다.
	Workspace.Jeolhwa 에 놓인 것과 ServerStorage 의 틀(다시 지을 때 쓰는 것) 둘 다 고친다.
]]

local OFF = {
	Gate_Palace = { "_RoofEdge$" },
	Gate_Hall = { "_RoofEdge$" },
	Wall_GateTile = { "_Eave$" },
	Granary = { "_Eave$" },
	Shop_Row5 = { "_Eave$", "_RoofEdge$", "_Onggi$" },
	Shop_Row3 = { "_Eave$", "_RoofEdge$", "_Onggi$" },
}

local n, tpl = 0, 0
local function fix(root, isTemplate)
	for _, m in ipairs(root:GetDescendants()) do
		local pats = m:IsA("Model") and OFF[m.Name]
		if pats then
			for _, p in ipairs(m:GetDescendants()) do
				local hit = false
				for _, pat in ipairs(pats) do
					hit = hit or (p:IsA("BasePart") and p.Name:match(pat) ~= nil)
				end
				if hit and p.CanCollide then
					p.CanCollide = false
					if isTemplate then
						tpl += 1
					else
						n += 1
					end
				end
			end
		end
	end
end
fix(workspace:FindFirstChild("Jeolhwa"), false)
fix(game:GetService("ServerStorage"), true)
print(string.format("gatefix 놓인 문 파트 %d, 틀 파트 %d 충돌 끔", n, tpl))
