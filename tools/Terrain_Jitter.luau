--!nocheck
--[[
	Terrain_Jitter.luau — 2026-10-04. 이미 지어 둔 지형 부품(Plains_Build 의 Surface.R_평원북·동·중)에 한 번만 x·y·z ±0.1 —
	사용자: "모든 블록에다가 XYZ좌표를 각각 0.1씩 +- 해서 겹쳤을 때 깜빡이는 문제를 없애자".
	새로 짓는 것(Plains_Fill·Desert_Build)은 짓기의 part() 가 스스로 흔든다. 여기서는 속성 Jittered 가 있으면 건너뛰어 두 번 흔들지 않는다.
	보고: /jitter
]]
local HS = game:GetService("HttpService")
local n, c = 0, 0
for _, name in { "R_평원북", "R_평원동", "R_평원중" } do
	local f = workspace.Surface:FindFirstChild(name)
	for _, p in f and f:GetDescendants() or {} do
		if p:IsA("BasePart") and not p:GetAttribute("Jittered") and p.Anchored then
			c += 1
			local k = c % 8
			p.CFrame += Vector3.new(if k % 2 == 0 then 0.1 else -0.1, if (k // 2) % 2 == 0 then 0.1 else -0.1, if (k // 4) % 2 == 0 then 0.1 else -0.1)
			p:SetAttribute("Jittered", true)
			n += 1
		end
	end
end
HS:PostAsync("http://127.0.0.1:34999/jitter", "흔든 부품 " .. n)
