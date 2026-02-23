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
local rotasiMode = 1   -- Pilih mode rotasi (1, 2, 3, atau 4)

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

-- FUNGSI: Terbang ke atas mob dengan berbagai mode rotasi
local function floatAboveMob(mob)
    if not mob or not mob.rootPart then return end
    
    -- Hitung posisi di atas mob
    local targetPos = mob.rootPart.Position + Vector3.new(0, floatHeight, 0)
    
    ---=== METODE ROTASI YANG BISA DICOBA ===---
    local newCFrame
    
    if rotasiMode == 1 then
        -- METODE 1: Rotasi manual sumbu X (paling sederhana)
        newCFrame = CFrame.new(targetPos) * CFrame.Angles(-1.5708, 0, 0)  -- -90 derajat dalam radian
        
    elseif rotasiMode == 2 then
        -- METODE 2: Menghadap ke bawah dengan orientasi dunia
        newCFrame = CFrame.fromEulerAnglesXYZ(-1.5708, 0, 0) + targetPos
        
    elseif rotasiMode == 3 then
        -- METODE 3: Menghadap ke arah mob
        local direction = (mob.rootPart.Position - targetPos).Unit
        newCFrame = CFrame.lookAt(targetPos, targetPos + direction)
        -- Tambahkan rotasi menghadap ke bawah
        newCFrame = newCFrame * CFrame.Angles(-0.5, 0, 0)  -- -30 derajat
        
    elseif rotasiMode == 4 then
        -- METODE 4: Coba dengan Vector3 orientation
        humanoidRootPart.CFrame = CFrame.new(targetPos)
        wait(0.05)
        -- Set orientation langsung
        humanoidRootPart.Orientation = Vector3.new(-90, 0, 0)
        print("🔧 Mencoba metode orientation")
        return
    end
    
    -- Terapkan CFrame jika bukan metode 4
    if newCFrame then
        humanoidRootPart.CFrame = newCFrame
    end
    
    -- Tampilkan informasi
    print("📍 Di atas:", mob.model.Name, 
          "| HP:", math.floor(mob.humanoid.Health),
          "| Mode Rotasi:", rotasiMode)
end

-- FUNGSI: Ganti mode rotasi
local function gantiModeRotasi()
    rotasiMode = rotasiMode + 1
    if rotasiMode > 4 then rotasiMode = 1 end
    
    print("🔄 Mode Rotasi:", rotasiMode)
    if rotasiMode == 1 then print("   - Menghadap lurus ke bawah (CFrame Angles)")
    elseif rotasiMode == 2 then print("   - Menghadap ke bawah (fromEulerAngles)")
    elseif rotasiMode == 3 then print("   - Menghadap ke arah mob + miring")
    elseif rotasiMode == 4 then print("   - Menggunakan Orientation Vector3")
    end
end

-- FUNGSI: Reset rotasi ke normal
local function resetRotation()
    local currentPos = humanoidRootPart.Position
    humanoidRootPart.CFrame = CFrame.new(currentPos)
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
    
    if not currentTarget.model or not currentTarget.model.Parent then
        return false
    end
    
    if not currentTarget.humanoid or currentTarget.humanoid.Health <= 0 then
        return false
    end
    
    if not currentTarget.rootPart or not currentTarget.rootPart.Parent then
        return false
    end
    
    return true
end

-- KEYBIND SYSTEM
userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Tombol F: Toggle Floating Mode
    if input.KeyCode == Enum.KeyCode[getgenv().KeyBindToggle or "F"] then
        floatingActive = not floatingActive
        
        if floatingActive then
            print("🚀 FLOATING MODE: ON")
            print("📍 Karakter mengambang di atas mob")
            print("🖱️ Silakan klik untuk menyerang")
            findNewTarget()
        else
            print("💤 FLOATING MODE: OFF")
            resetRotation()
            currentTarget = nil
        end
    end
    
    -- Tombol H: Cari target baru manual
    if input.KeyCode == Enum.KeyCode[getgenv().TeleportKey or "H"] then
        if floatingActive then
            findNewTarget()
        else
            local mob = getNearestMob(getgenv().TeleportRange or 50)
            if mob then
                humanoidRootPart.CFrame = mob.rootPart.CFrame + Vector3.new(0, 5, 0)
                print("📞 Teleport ke:", mob.model.Name)
            end
        end
    end
    
    -- Tombol R: Reset/Turun ke tanah
    if input.KeyCode == Enum.KeyCode.R then
        if floatingActive then
            floatingActive = false
            resetRotation()
            print("⬇️ Turun ke tanah (floating OFF)")
            currentTarget = nil
        else
            print("⚠️ Floating mode tidak aktif")
        end
    end
    
    -- Tombol M: Ganti mode rotasi
    if input.KeyCode == Enum.KeyCode.M then
        gantiModeRotasi()
        if floatingActive and currentTarget then
            floatAboveMob(currentTarget)
        end
    end
end)

-- LOOP UTAMA - Menjaga posisi di atas mob
runService.Heartbeat:Connect(function()
    if not floatingActive then return end
    
    if not isTargetValid() then
        findNewTarget()
    else
        floatAboveMob(currentTarget)
    end
    
    wait(0.1)
end)

print("=================================")
print("✅ RPG Grinder - FLOATING MODE")
print("=================================")
print("Tekan F = ON/OFF Floating")
print("Tekan H = Cari target baru")
print("Tekan R = Turun ke tanah")
print("Tekan M = Ganti mode rotasi")
print("=================================")
print("📍 Mode Rotasi awal: 1")
print("🖱️ Tekan M untuk ganti-ganti mode")
print("=================================")
