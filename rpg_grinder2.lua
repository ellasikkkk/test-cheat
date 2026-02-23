-- Optimized RPG Grinder

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local players = game:GetService("Players")

-- Cache mob list
local mobs = {}

-- Update mob list tiap 0.5 detik (biar gak berat)
task.spawn(function()
    while true do
        task.wait(0.5)
        mobs = {}
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") then
                local humanoid = obj:FindFirstChild("Humanoid")
                local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")

                if humanoid and root and not players:GetPlayerFromCharacter(obj) then
                    table.insert(mobs, {
                        model = obj,
                        humanoid = humanoid,
                        root = root
                    })
                end
            end
        end
    end
end)

-- Get nearest mob (pakai cache)
local function getNearestMob(range)
    local nearestMob = nil
    local shortestDistance = range or math.huge

    for _, mobData in ipairs(mobs) do
        local distance = (humanoidRootPart.Position - mobData.root.Position).Magnitude
        if distance < shortestDistance then
            shortestDistance = distance
            nearestMob = mobData
        end
    end

    return nearestMob
end

-- Kill Aura (lebih ringan)
local function killAura()
    if not getgenv().KillAura then return end

    local range = getgenv().KillAuraRange or 30

    for _, mobData in ipairs(mobs) do
        if mobData.humanoid.Health > 0 then
            local distance = (humanoidRootPart.Position - mobData.root.Position).Magnitude
            if distance <= range then
                mobData.humanoid.Health = 0
            end
        end
    end
end

-- Teleport
local function teleportToNearestMob()
    local mobData = getNearestMob(getgenv().TeleportRange or 50)
    if mobData then
        humanoidRootPart.CFrame = mobData.root.CFrame + Vector3.new(0, 5, 0)
    end
end

-- Keybind
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

-- Loop utama (dibatasi 0.1 detik, bukan tiap frame)
task.spawn(function()
    while true do
        task.wait(0.1)
        if getgenv().AutoFarm and getgenv().KillAura then
            killAura()
        end
    end
end)

print("✅ Optimized RPG Grinder Loaded!")
