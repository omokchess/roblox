local MS = game:GetService("MaterialService")
for _, base in { "Grass", "Sand" } do
	MS:SetBaseMaterialOverride(Enum.Material[base], "")
end
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/matrevert", "ok")
