-- Script RPG Grinder - Versi Simple
-- Cocok untuk pemula dan ringan di PC

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Fungsi untuk mencari mob di sekitar
function findMobs()
    local mobs = {}
    local range = 30 -- Jarak pencarian
    
    -- Cari semua object di workspace
    for _, obj in pairs(workspace:GetChildren()) do
        -- Cek apakah ini adalah mob (punya Humanoid dan bukan player)
        if obj:FindFirstChild("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
            -- Pastikan ini bukan player
            if not game.Players:GetPlayerFromCharacter(obj) then
                local mobPos = obj.HumanoidRootPart.Position
                local playerPos = humanoidRootPart.Position
                local distance = (mobPos - playerPos).magnitude
                
                -- Jika dalam range, tambahkan ke daftar
                if distance <= range then
                    table.insert(mobs, obj)
                end
            end
        end
    end
    
    return mobs
end

-- Fungsi untuk kill mob
function killMobs()
    local mobs = findMobs()
    
    for _, mob in pairs(mobs) do
        local humanoid = mob:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health > 0 then
            humanoid.Health = 0 -- Langsung matikan
            print("Mob terbunuh:", mob.Name)
        end
    end
end

-- Fungsi teleport ke mob terdekat
function teleportToMob()
    local mobs = findMobs()
    
    if #mobs > 0 then
        local targetMob = mobs[1] -- Ambil mob pertama
        local mobPos = targetMob.HumanoidRootPart.Position
        humanoidRootPart.CFrame = CFrame.new(mobPos.x, mobPos.y + 5, mobPos.z)
        print("Teleport ke:", targetMob.Name)
    else
        print("Tidak ada mob di sekitar")
    end
end

-- Control dengan keyboard
local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input)
    -- Tekan F untuk auto kill (toggle)
    if input.KeyCode == Enum.KeyCode.F then
        getgenv().autoKill = not getgenv().autoKill
        print("Auto Kill:", getgenv().autoKill and "ON" or "OFF")
    end
    
    -- Tekan T untuk teleport
    if input.KeyCode == Enum.KeyCode.T then
        teleportToMob()
    end
    
    -- Tekan K untuk kill sekali
    if input.KeyCode == Enum.KeyCode.K then
        killMobs()
    end
end)

-- Loop untuk auto kill (jika diaktifkan)
game:GetService("RunService").Heartbeat:Connect(function()
    if getgenv().autoKill then
        killMobs()
        wait(0.5) -- Delay biar tidak berat
    end
end)

print("===== SCRIPT RPG GRINDER LOADED =====")
print("Tekan F = Toggle Auto Kill")
print("Tekan T = Teleport ke Mob")
print("Tekan K = Kill Manual")
