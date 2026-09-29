local MS = game:GetService("MaterialService")
local pack = game:GetService("ServerStorage").MaterialPacks.Pack_13591987222["Handpainted Materials"]
local use = { Grass = "Grass", Rock = "Stone", Sand = "Sand", Ground = "Dirt", Snow = "Snow", Cobblestone = "Cobblestone", WoodPlanks = "Planks", Wood = "Bark", Ice = "Ice" }
local out = {}
for base, name in use do
	local v = pack:FindFirstChild(name)
	if v then
		local copy = MS:FindFirstChild("HP_" .. name) or v:Clone()
		copy.Name = "HP_" .. name
		copy.Parent = MS
		MS:SetBaseMaterialOverride(Enum.Material[base], copy.Name)
		table.insert(out, base .. " -> " .. copy.Name)
	end
end
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/matapply", table.concat(out, "\n"))
