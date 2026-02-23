-- Script Utama RPG Grinder
-- Jangan diedit langsung, atur melalui konfigurasi di atas

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local players = game:GetService("Players")

-- Fungsi untuk mendapatkan mob terdekat
local function getNearestMob(range)
    local nearestMob = nil
    local shortestDistance = range or math.huge
    
    for _, obj in pairs(workspace:GetDescendants()) do
        -- Deteksi mob berdasarkan pola umum (sesuaikan dengan game guru Anda)
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and not players:GetPlayerFromCharacter(obj) then
            local mobRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
            if mobRoot then
                local distance = (humanoidRootPart.Position - mobRoot.Position).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    nearestMob = obj
                end
            end
        end
    end
    return nearestMob, shortestDistance
end

-- Fungsi Kill Aura
local function killAura()
    if not getgenv().KillAura then return end
    
    local range = getgenv().KillAuraRange or 30
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") then
            -- Skip player jika TargetMobsOnly true
            if getgenv().TargetMobsOnly and players:GetPlayerFromCharacter(obj) then
                continue
            end
            
            local mobRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
            if mobRoot then
                local distance = (humanoidRootPart.Position - mobRoot.Position).Magnitude
                if distance <= range then
                    local humanoid = obj:FindFirstChild("Humanoid")
                    if humanoid and humanoid.Health > 0 then
                        humanoid.Health = 0  -- Langsung kill (sederhana)
                        -- Alternatif: gunakan :TakeDamage() jika ada
                    end
                end
            end
        end
    end
end

-- Fungsi Teleport ke mob terdekat
local function teleportToNearestMob()
    local mob, distance = getNearestMob(getgenv().TeleportRange or 50)
    if mob then
        local mobRoot = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Torso")
        if mobRoot then
            humanoidRootPart.CFrame = mobRoot.CFrame + Vector3.new(0, 5, 0)  -- Offset 5 studs ke atas
        end
    end
end

-- Keybind system
userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode[getgenv().KeyBindToggle or "F"] then
        getgenv().AutoFarm = not getgenv().AutoFarm
        print("AutoFarm:", getgenv().AutoFarm and "ON" or "OFF")
    end
    
    if input.KeyCode == Enum.KeyCode[getgenv().TeleportKey or "T"] then
        teleportToNearestMob()
    end
end)

-- Loop utama auto farm
runService.Heartbeat:Connect(function()
    if getgenv().AutoFarm and getgenv().KillAura then
        killAura()
    end
end)

-- ESP sederhana (opsional)
if getgenv().ESPEnabled then
    while true do
        wait(0.1)
        for _, mob in pairs(workspace:GetDescendants()) do
            if mob:IsA("Model") and mob:FindFirstChild("Humanoid") and not players:GetPlayerFromCharacter(mob) then
                local mobRoot = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Torso")
                if mobRoot then
                    -- Gambar ESP (implementasi sederhana, bisa dikembangkan)
                    local distance = (humanoidRootPart.Position - mobRoot.Position).Magnitude
                    if getgenv().ShowDistance then
                        -- Tampilkan jarak (bisa pakai BillboardGui atau debug)
                    end
                end
            end
        end
    end
end

print("✅ RPG Grinder Loaded! Tekan", getgenv().KeyBindToggle, "untuk toggle")