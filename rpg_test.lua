-- Script test manual
local player = game.Players.LocalPlayer
local character = player.Character

-- Cari mob di dekat Anda
for _, obj in pairs(workspace:GetChildren()) do
    if obj:FindFirstChild("Humanoid") then
        local hum = obj:FindFirstChild("Humanoid")
        print("Mob:", obj.Name, "HP:", hum.Health)
        
        -- Test berbagai metode
        hum.Health = hum.Health - 20  -- Metode 1
        -- hum:TakeDamage(20)  -- Metode 2
    end
end