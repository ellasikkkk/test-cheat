-- Script Utama RPG Grinder - FLOATING MODE
-- Karakter selalu mengambang di atas mob terdekat dan menghadap ke bawah

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

-- FUNGSI: Terbang ke atas mob dan menghadap ke bawah
local function floatAboveMob(mob)
    if not mob or not mob.rootPart then return end
    
    -- Hitung posisi di atas mob
    local targetPos = mob.rootPart.Position + Vector3.new(0, floatHeight, 0)
    
    ---=== MEMBUAT KARAKTER MENGHADAP KE BAWAH ===---
    -- local lookAtMob = CFrame.lookAt(targetPos, mob.rootPart.Position)
    -- local lookDownCFrame = lookAtMob * CFrame.Angles(math.rad(-45), 0, 0)
    
    -- Terapkan CFrame
    humanoidRootPart.CFrame = lookDownCFrame
    
    -- Tampilkan informasi
    print("📍 Di atas:", mob.model.Name, 
          "| HP:", math.floor(mob.humanoid.Health),
          "| Posisi: Menghadap ke bawah")
end

-- FUNGSI: Reset rotasi ke normal (untuk turun ke tanah)
local function resetRotation()
    -- Kembalikan ke rotasi normal (berdiri tegak)
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
            print("📍 Karakter mengambang di atas mob (menghadap ke bawah)")
            print("🖱️ Silakan klik untuk menyerang")
            findNewTarget()
        else
            print("💤 FLOATING MODE: OFF")
            resetRotation()  -- Kembalikan rotasi normal
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
print("    dengan rotasi menghadap ke bawah")
print("=================================")
print("Tekan", getgenv().KeyBindToggle or "F", "= ON/OFF Floating")
print("Tekan", getgenv().TeleportKey or "H", "= Cari target baru")
print("Tekan R = Turun ke tanah")
print("=================================")
print("📍 Karakter menghadap ke bawah saat melayang")
print("🖱️ Anda tinggal klik untuk menyerang")
print("=================================")
