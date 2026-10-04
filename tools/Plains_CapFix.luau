--!nocheck
-- Plains_CapFix.luau — 2026-10-04. 옛 평원 지형(Plains_Build: R_평원북·동·중)의 풀 윗판(_풀)을 0.2 낮추고 옆으로 0.1 넓힌다
-- (Terrain_Jitter 의 ±0.1 흔들기로 바위와 윗판 사이가 떠 보이던 것). 속성 CapFix 가 있으면 건너뜀. 보고: /capfix
local n = 0
for _, name in { "R_평원북", "R_평원동", "R_평원중" } do
	local f = workspace.Surface:FindFirstChild(name)
	for _, p in f and f:GetDescendants() or {} do
		if p:IsA("BasePart") and p.Name:match("_풀$") and not p:GetAttribute("CapFix") then
			p.Size += Vector3.new(0.1, 0, 0.1)
			p.CFrame -= Vector3.new(0, 0.2, 0)
			p:SetAttribute("CapFix", true)
			n += 1
		end
	end
end
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/capfix", "고친 윗판 " .. n)
