-- Script Utama RPG Grinder - FLOATING MODE
-- Karakter selalu mengambang di atas mob terdekat

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local players = game:GetService("Players")

-- VARIABEL FLOATING
local floatingActive = false
local currentTarget = nil
local floatHeight = 8  -- Tinggi mengambang (bisa diatur)

-- FUNGSI: Mendapatkan mob terdekat (sama seperti kode Anda)
local function getNearestMob(range)
    local nearestMob = nil
    local shortestDistance = range or math.huge
    
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and not players:GetPlayerFromCharacter(obj) then
            local mobRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
            if mobRoot then
                local humanoid = obj:FindFirstChild("Humanoid")
                -- Pastikan mob masih hidup
                if humanoid and humanoid.Health > 0 then
                    local distance = (humanoidRootPart.Position - mobRoot.Position).Magnitude
                    if distance < shortestDistance then
                        shortestDistance = distance
                        nearestMob = {
                            model = obj,
                            rootPart = mobRoot,
                            humanoid = humanoid
                        }
                    end
                end
            end
        end
    end
    return nearestMob, shortestDistance
end

-- FUNGSI: Terbang ke atas mob
local function floatAboveMob(mob)
    if not mob or not mob.rootPart then return end
    
    -- Hitung posisi di atas mob
    local targetPos = mob.rootPart.Position + Vector3.new(0, floatHeight, 0)
    
    -- Teleport ke atas mob
    humanoidRootPart.CFrame = CFrame.new(targetPos)
    
    -- Tampilkan informasi (opsional, bisa dihapus kalau ganggu)
    print("📍 Di atas:", mob.model.Name, 
          "| HP:", math.floor(mob.humanoid.Health),
          "| Jarak ke mob:", math.floor((humanoidRootPart.Position - mob.rootPart.Position).Magnitude))
end

-- FUNGSI: Cari target baru
local function findNewTarget()
    local mob = getNearestMob(getgenv().TeleportRange or 50)
    
    if mob then
        currentTarget = mob
        floatAboveMob(currentTarget)
        print("✅ Target baru:", currentTarget.model.Name)
    else
        print("❌ Tidak ada mob di sekitar")
        currentTarget = nil
    end
end

-- FUNGSI: Cek apakah target masih valid
local function isTargetValid()
    if not currentTarget then return false end
    
    -- Cek apakah mob masih ada di game
    if not currentTarget.model or not currentTarget.model.Parent then
        return false
    end
    
    -- Cek apakah masih hidup
    if not currentTarget.humanoid or currentTarget.humanoid.Health <= 0 then
        return false
    end
    
    -- Cek apakah root part masih ada
    if not currentTarget.rootPart or not currentTarget.rootPart.Parent then
        return false
    end
    
    return true
end

-- KEYBIND SYSTEM (sama seperti kode Anda, tapi dimodifikasi)
userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Tombol F: Toggle Floating Mode
    if input.KeyCode == Enum.KeyCode[getgenv().KeyBindToggle or "F"] then
        floatingActive = not floatingActive
        
        if floatingActive then
            print("🚀 FLOATING MODE: ON")
            print("📍 Karakter akan mengambang di atas mob")
            print("🖱️ Silakan klik untuk menyerang")
            findNewTarget()  -- Langsung cari target
        else
            print("💤 FLOATING MODE: OFF")
            currentTarget = nil
        end
    end
    
    -- Tombol H (atau sesuai setting): Cari target baru manual
    if input.KeyCode == Enum.KeyCode[getgenv().TeleportKey or "H"] then
        if floatingActive then
            findNewTarget()
        else
            -- Kalau floating mati, tetap bisa teleport biasa
            local mob = getNearestMob(getgenv().TeleportRange or 50)
            if mob then
                humanoidRootPart.CFrame = mob.rootPart.CFrame + Vector3.new(0, 5, 0)
                print("📞 Teleport ke:", mob.model.Name)
            end
        end
    end
    
    -- Tombol R: Reset/Turun ke tanah
    if input.KeyCode == Enum.KeyCode.R then
        if currentTarget then
            -- Turun ke tanah di dekat mob
            local groundPos = currentTarget.rootPart.Position + Vector3.new(3, 0, 3)
            humanoidRootPart.CFrame = CFrame.new(groundPos)
            print("⬇️ Turun ke tanah")
        end
    end
end)

-- LOOP UTAMA - Menjaga posisi di atas mob
runService.Heartbeat:Connect(function()
    if not floatingActive then return end
    
    -- Validasi target
    if not isTargetValid() then
        findNewTarget()  -- Cari target baru kalau yang lama mati/hilang
    else
        -- Tetap di atas mob
        floatAboveMob(currentTarget)
    end
    
    wait(0.1)  -- Delay kecil agar tidak terlalu berat
end)

print("=================================")
print("✅ RPG Grinder - FLOATING MODE")
print("=================================")
print("Tekan", getgenv().KeyBindToggle or "F", "= ON/OFF Floating")
print("Tekan", getgenv().TeleportKey or "H", "= Cari target baru")
print("Tekan R = Turun ke tanah")
print("=================================")
print("📍 Fungsi: Karakter mengambang di atas mob")
print("🖱️ Anda tinggal klik untuk menyerang")
print("=================================")
