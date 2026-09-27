--!nocheck
-- 빌드된 플레이스(build/SwampArchipelago.rbxl) 구조 검사
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

return function(H)
	local path = "build/SwampArchipelago.rbxl"
	if not fs.isFile(path) then
		print("    (build/SwampArchipelago.rbxl 없음 — rojo build 후 실행하면 검사)")
		return
	end
	local game = roblox.deserializePlace(fs.readFile(path))
	local RS = game:GetService("ReplicatedStorage")
	local SS = game:GetService("ServerStorage")
	local SSS = game:GetService("ServerScriptService")
	local SP = game:GetService("StarterPlayer")
	H.check("Shared 모듈 트리", RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Combat") and RS.Shared:FindFirstChild("World") and RS.Shared:FindFirstChild("Ferry"))
	H.check("서버 진입점", SSS:FindFirstChild("Server") and SSS.Server:FindFirstChild("Main") and SSS.Server.Main.ClassName == "Script")
	local client = SP:FindFirstChild("StarterPlayerScripts") and SP.StarterPlayerScripts:FindFirstChild("Client")
	H.check("클라이언트 진입점", client and client:FindFirstChild("Main") and client.Main.ClassName == "LocalScript")
	local ferry = RS:FindFirstChild("SwampAssets") and RS.SwampAssets:FindFirstChild("Ferry")
	H.check("복제 에셋: 배", ferry ~= nil)
	if ferry then
		local anchor = ferry:FindFirstChild("Anchor")
		H.check("배: Anchor/마커", anchor and anchor:FindFirstChild("GangplankHinge") and anchor:FindFirstChild("Helm"))
		H.check("배: 돛/도선판 그룹", ferry.Visual:FindFirstChild("Sails") and ferry.Visual:FindFirstChild("Gangplank"))
		local cols = ferry:FindFirstChild("Colliders")
		H.check("배: 갑판 충돌체", cols and #cols:GetChildren() > 20)
	end
	local assets = SS:FindFirstChild("SwampAssets")
	local count = assets and #assets:GetChildren() or 0
	H.check("서버 에셋 템플릿 ≥ 50", count >= 50, count)
	if assets then
		local bad = {}
		for _, m in assets:GetChildren() do
			if not (m:FindFirstChild("Anchor") and m:FindFirstChild("Visual") and m:FindFirstChild("Colliders")) then
				table.insert(bad, m.Name)
			end
			if m.PrimaryPart == nil then
				table.insert(bad, m.Name .. "(PrimaryPart)")
			end
		end
		H.check("모든 템플릿 구조(Anchor/Visual/Colliders/PrimaryPart)", #bad == 0, table.concat(bad, ", "))
		local crawler = assets:FindFirstChild("E_BogCrawler")
		if crawler then
			local joints = 0
			for _, a in crawler.Anchor:GetChildren() do
				if string.sub(a.Name, 1, 2) == "J_" then
					joints += 1
				end
			end
			H.check("크리처 관절 마커 11개", joints == 11, joints)
			H.check("크리처 리그 속성", crawler:GetAttribute("HipHeight") ~= nil and crawler:GetAttribute("HrpSize") ~= nil)
		end
		local house = assets:FindFirstChild("StiltHouseA")
		if house then
			local visual = 0
			for _, d in house.Visual:GetDescendants() do
				if d:IsA("BasePart") then
					visual += 1
					if d.CanCollide then
						table.insert(bad, "collide:" .. d.Name)
					end
				end
			end
			H.check("가옥: 시각 파트는 충돌 없음 (" .. visual .. "개)", #bad == 0)
		end
	end
	H.check("SwampTools 모듈", SS:FindFirstChild("SwampTools") and SS.SwampTools:FindFirstChild("WorldBuilder") and SS.SwampTools:FindFirstChild("AssetSetup"))
	local lighting = game:GetService("Lighting")
	H.check("조명 Future", tostring(lighting.Technology) == "Enum.Technology.Future", tostring(lighting.Technology))
end
