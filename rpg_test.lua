-- Script RPG Grinder - FLOATING MODE
-- Karakter selalu berada di atas mob terdekat

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local userInputService = game:GetService("UserInputService")
local players = game:GetService("Players")

-- VARIABEL KONTROL
local floatingActive = false
local currentTarget = nil
local floatHeight = 8  -- Tinggi mengambang di atas mob

-- FUNGSI: Cari mob terdekat
local function getNearestMob()
    local nearestMob = nil
    local shortestDistance = math.huge
    local playerPos = humanoidRootPart.Position
    local range = 50  -- Jarak pencarian
    
    -- Cari mob di sekitar
    for _, obj in pairs(workspace:GetChildren()) do
        -- Cek apakah ini mob (punya Humanoid dan bukan player)
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and not players:GetPlayerFromCharacter(obj) then
            local humanoid = obj:FindFirstChild("Humanoid")
            local rootPart = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
            
            -- Pastikan mob masih hidup
            if humanoid and rootPart and humanoid.Health > 0 then
                local distance = (playerPos - rootPart.Position).Magnitude
                
                -- Cari yang terdekat
                if distance < shortestDistance and distance <= range then
                    shortestDistance = distance
                    nearestMob = {
                        model = obj,
                        rootPart = rootPart,
                        humanoid = humanoid
                    }
                end
            end
        end
    end
    
    return nearestMob
end

-- FUNGSI: Terbang ke atas mob
local function floatAboveMob(mob)
    if not mob or not mob.rootPart then return end
    
    -- Posisi di atas mob (mengambang)
    local targetPos = mob.rootPart.Position + Vector3.new(0, floatHeight, 0)
    
    -- Teleport halus (bisa langsung atau smooth)
    humanoidRootPart.CFrame = CFrame.new(targetPos)
    
    -- Opsi: Tampilkan informasi mob
    print("🎯 Target:", mob.model.Name, 
          "| HP:", math.floor(mob.humanoid.Health),
          "| Jarak:", math.floor((humanoidRootPart.Position - mob.rootPart.Position).Magnitude))
end

-- FUNGSI: Cari target baru
local function findNewTarget()
    currentTarget = getNearestMob()
    
    if currentTarget then
        print("✅ Menemukan target:", currentTarget.model.Name)
        floatAboveMob(currentTarget)
    else
        print("❌ Tidak ada mob di sekitar")
    end
end

-- FUNGSI: Cek apakah target masih ada dan hidup
local function isTargetValid()
    if not currentTarget then return false end
    
    -- Cek apakah mob masih ada di workspace
    if not currentTarget.model or not currentTarget.model.Parent then
        return false
    end
    
    -- Cek apakah masih hidup
    if not currentTarget.humanoid or currentTarget.humanoid.Health <= 0 then
        return false
    end
    
    -- Cek jarak (jika terlalu jauh, cari baru)
    local distance = (humanoidRootPart.Position - currentTarget.rootPart.Position).Magnitude
    if distance > 60 then  -- Jika terlalu jauh
        return false
    end
    
    return true
end

-- KEYBIND SYSTEM
userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Tombol F: Aktifkan mode floating
    if input.KeyCode == Enum.KeyCode[getgenv().KeyBindToggle or "F"] then
        floatingActive = not floatingActive
        
        if floatingActive then
            print("🚀 FLOATING MODE: ON")
            print("📍 Karakter akan mengambang di atas mob")
            print("🖱️ Silakan klik manual untuk menyerang")
            
            -- Langsung cari target pertama
            findNewTarget()
        else
            print("💤 FLOATING MODE: OFF")
            currentTarget = nil
        end
    end
    
    -- Tombol T: Cari target baru manual
    if input.KeyCode == Enum.KeyCode.T then
        findNewTarget()
    end
    
    -- Tombol R: Reset posisi (turun ke tanah)
    if input.KeyCode == Enum.KeyCode.R then
        if currentTarget then
            -- Turun ke tanah di dekat mob
            local groundPos = currentTarget.rootPart.Position + Vector3.new(2, 0, 2)
            humanoidRootPart.CFrame = CFrame.new(groundPos)
            print("⬇️ Turun ke tanah")
        end
    end
end)

-- LOOP UTAMA - Menjaga posisi di atas mob
game:GetService("RunService").Heartbeat:Connect(function()
    if not floatingActive then return end
    
    -- Validasi target
    if not isTargetValid() then
        -- Cari target baru
        findNewTarget()
    else
        -- Tetap di atas mob
        floatAboveMob(currentTarget)
    end
    
    -- Delay kecil agar tidak terlalu berat
    wait(0.1)
end)

print("=================================")
print("✅ FLOATING MODE Loaded!")
print("=================================")
print("Tekan F = ON/OFF Floating Mode")
print("Tekan T = Cari target baru")
print("Tekan R = Turun ke tanah")
print("=================================")
print("📍 Fungsi: Karakter mengambang di atas mob")
print("🖱️ Anda tinggal klik untuk menyerang")
print("=================================")
