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
local rotasiMode = 1   -- Default mode 1 (yang sudah berhasil)

-- FUNGSI: Mendapatkan mob terdekat
local function getNearestMob(range)
    local nearestMob = nil
    local shortestDistance = range or math.huge
    
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and not players:GetPlayerFromCharacter(obj) then
            local mobRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
            if mobRoot then
                local humanoid = obj:FindFirstChild("Humanoid")
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

-- FUNGSI: Terbang ke atas mob (menggunakan mode yang sudah berhasil)
local function floatAboveMob(mob)
    if not mob or not mob.rootPart then return end
    
    -- Hitung posisi di atas mob
    local targetPos = mob.rootPart.Position + Vector3.new(0, floatHeight, 0)
    
    -- Gunakan mode yang sudah terbukti berhasil (mode 1)
    -- CFrame.Angles(math.rad(-90), 0, 0) = menghadap lurus ke bawah
    local lookDownCFrame = CFrame.new(targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
    
    -- Terapkan CFrame
    humanoidRootPart.CFrame = lookDownCFrame
    
    -- Tampilkan informasi
    print("📍 Di atas:", mob.model.Name, 
          "| HP:", math.floor(mob.humanoid.Health),
          "| Mode: Default (Menghadap ke bawah)")
end

-- FUNGSI: Reset rotasi ke normal
local function resetRotation()
    local currentPos = humanoidRootPart.Position
    humanoidRootPart.CFrame = CFrame.new(currentPos)
    print("↩️ Rotasi kembali normal")
end

-- FUNGSI: Cari target baru
local function findNewTarget()
    print("🔍 Mencari mob terdekat...")
    local mob = getNearestMob(getgenv().TeleportRange or 50)
    
    if mob then
        currentTarget = mob
        floatAboveMob(currentTarget)
        print("✅ Target baru ditemukan:", currentTarget.model.Name)
        print("   Posisi: X=" .. math.floor(mob.rootPart.Position.X) .. 
              " Y=" .. math.floor(mob.rootPart.Position.Y) .. 
              " Z=" .. math.floor(mob.rootPart.Position.Z))
    else
        print("❌ Tidak ada mob di sekitar")
        currentTarget = nil
    end
end

-- FUNGSI: Cek apakah target masih valid
local function isTargetValid()
    if not currentTarget then return false end
    
    if not currentTarget.model or not currentTarget.model.Parent then
        print("⚠️ Target hilang dari game")
        return false
    end
    
    if not currentTarget.humanoid or currentTarget.humanoid.Health <= 0 then
        print("💀 Target sudah mati")
        return false
    end
    
    if not currentTarget.rootPart or not currentTarget.rootPart.Parent then
        print("⚠️ Root part target hilang")
        return false
    end
    
    return true
end

-- FUNGSI: Tampilkan status floating
local function tampilkanStatus()
    print("=================================")
    print("📊 STATUS FLOATING MODE")
    print("=================================")
    print("Mode Aktif:", floatingActive and "✅ ON" or "❌ OFF")
    if floatingActive and currentTarget then
        print("Target:", currentTarget.model.Name)
        print("HP Target:", math.floor(currentTarget.humanoid.Health))
        print("Tinggi Melayang:", floatHeight, "studs")
    elseif floatingActive then
        print("Status: Mencari target...")
    end
    print("Mode Rotasi: Default (Menghadap ke bawah)")
    print("=================================")
end

-- KEYBIND SYSTEM
userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Tombol F: Toggle Floating Mode
    if input.KeyCode == Enum.KeyCode[getgenv().KeyBindToggle or "F"] then
        floatingActive = not floatingActive
        
        if floatingActive then
            print("=================================")
            print("🚀 FLOATING MODE: AKTIF")
            print("=================================")
            print("📍 Karakter akan mengambang di atas mob")
            print("🖱️ Silakan klik untuk menyerang")
            print("📢 Mode Rotasi: Menghadap ke bawah (sudah bekerja)")
            findNewTarget()
        else
            print("=================================")
            print("💤 FLOATING MODE: DIMATIKAN")
            print("=================================")
            resetRotation()
            currentTarget = nil
        end
    end
    
    -- Tombol H: Cari target baru manual
    if input.KeyCode == Enum.KeyCode[getgenv().TeleportKey or "H"] then
        if floatingActive then
            print("🔄 Mencari target baru secara manual...")
            findNewTarget()
        else
            -- Kalau floating mati, tetap bisa teleport biasa
            print("📞 Mode Teleport Manual (floating mati)")
            local mob = getNearestMob(getgenv().TeleportRange or 50)
            if mob then
                humanoidRootPart.CFrame = mob.rootPart.CFrame + Vector3.new(0, 5, 0)
                print("✅ Teleport ke:", mob.model.Name)
            else
                print("❌ Tidak ada mob untuk teleport")
            end
        end
    end
    
    -- Tombol R: Reset/Turun ke tanah
    if input.KeyCode == Enum.KeyCode.R then
        if floatingActive then
            floatingActive = false
            resetRotation()
            currentTarget = nil
            print("⬇️ Turun ke tanah dan floating dimatikan")
        else
            print("⚠️ Floating mode tidak aktif (tekan F untuk aktivasi)")
        end
    end
    
    -- Tombol P: Tampilkan status
    if input.KeyCode == Enum.KeyCode.P then
        tampilkanStatus()
    end
end)

-- LOOP UTAMA - Menjaga posisi di atas mob
runService.Heartbeat:Connect(function()
    if not floatingActive then return end
    
    if not isTargetValid() then
        print("🔄 Target tidak valid, mencari target baru...")
        findNewTarget()
    else
        floatAboveMob(currentTarget)
    end
    
    wait(0.1)
end)

-- Tampilkan pesan selamat datang
print("=================================")
print("✅ RPG Grinder - FLOATING MODE")
print("=================================")
print("🎯 Mode Rotasi: Menghadap ke bawah")
print("   (Sudah dikonfirmasi bekerja)")
print("=================================")
print("Tombol:")
print("F = ON/OFF Floating Mode")
print("H = Cari target baru")
print("R = Turun ke tanah")
print("P = Tampilkan status")
print("=================================")
print("📢 Catatan: Mode rotasi default sudah bekerja!")
print("   Saat tekan F, karakter langsung menghadap ke bawah")
print("=================================")
