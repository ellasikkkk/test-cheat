-- ==========================================
-- SCRIPT AUTOFARM (OVERHEAD + AUTO DODGE BOSS)
-- Fitur: Autofarm, Float, Noclip, Direct Auto-Attack, Auto Evasion
-- ==========================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

-- ==========================================
-- 🔗 HOOKING KE MODULE GAME (KNIT)
-- ==========================================
print("Mencoba mengakses Controller Game...")
local AutoAttackController = require(ReplicatedStorage:WaitForChild("Controllers"):WaitForChild("Modules"):WaitForChild("Platform"):WaitForChild("AutoAttackController"))
local EntityController = require(ReplicatedStorage:WaitForChild("Controllers"):WaitForChild("Game"):WaitForChild("EntityController"))
print("✅ Hooking Berhasil!")

-- ==========================================
-- VARIABEL KONTROL TINGKAT LANJUT
-- ==========================================
local Config = {
    AutoFarm = false,
    AutoDodge = false, -- FITUR BARU
    AutoFarmHeight = 45,
    Float = false,
    FloatHeight = 15,
    Noclip = false,
    Keybind = Enum.KeyCode.T
}

local floatBodyVelocity = nil
local noclipConnection = nil
local farmConnection = nil

-- ==========================================
-- SISTEM RADAR BAHAYA (AKTIF SCANNER)
-- ==========================================
local function getActiveHazards()
    local hazards = {}
    -- Kita scan area di sekitar boss atau area tempur
    -- Mengincar Part yang menjadi indikator lingkaran merah (biasanya Decal atau Part khusus)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local name = string.lower(obj.Name)
            -- Memperluas deteksi: mencari nama yang mengandung tentacle, warning, atau aoe
            if string.find(name, "tentacle") or string.find(name, "warning") or string.find(name, "circle") or string.find(name, "aoe") then
                -- Hanya ambil yang terlihat (visible) atau aktif
                if obj.Transparency < 0.8 then 
                    table.insert(hazards, obj)
                end
            end
        end
    end
    return hazards
end

-- ==========================================
-- FUNGSI LOGIKA (BACKEND)
-- ==========================================

local function getBestTarget()
    local bestTarget = nil
    local shortestDist = math.huge
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    
    local playerPos = root.Position
    
    if EntityController.EntityViewRoot and typeof(EntityController.EntityViewRoot) == "Instance" then
        for _, obj in ipairs(EntityController.EntityViewRoot:GetChildren()) do
            local targetRoot = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart")
            if targetRoot and not Players:GetPlayerFromCharacter(obj) then
                local dist = (playerPos - targetRoot.Position).Magnitude
                if dist < shortestDist then shortestDist = dist; bestTarget = targetRoot end
            end
        end
        if bestTarget then return bestTarget end
    end
    
    local foldernames = {"ActiveSpirits", "Live", "World", "Mobs", "Entities"}
    for _, fname in ipairs(foldernames) do
        local f = workspace:FindFirstChild(fname)
        if f then
            for _, obj in ipairs(f:GetDescendants()) do
                if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) then
                    local targetRoot = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart")
                    if targetRoot then
                        local dist = (playerPos - targetRoot.Position).Magnitude
                        if dist < shortestDist then shortestDist = dist; bestTarget = targetRoot end
                    end
                end
            end
        end
    end
    return bestTarget
end

local function toggleFloat(state)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    if state then
        if not floatBodyVelocity then
            floatBodyVelocity = Instance.new("BodyVelocity")
            floatBodyVelocity.Name = "AutoFarmFloat"
            floatBodyVelocity.MaxForce = Vector3.new(0, math.huge, 0)
            floatBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            floatBodyVelocity.Parent = root
        end
        root.CFrame = CFrame.new(root.Position.X, Config.FloatHeight, root.Position.Z)
    else
        if floatBodyVelocity then
            floatBodyVelocity:Destroy()
            floatBodyVelocity = nil
        end
    end
end

local function toggleNoclip(state)
    if state then
        if not noclipConnection then
            noclipConnection = RunService.Stepped:Connect(function()
                local char = player.Character
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
            end)
        end
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
    end
end

local function toggleAutoFarm(state)
    if state then
        pcall(function() AutoAttackController:SetManualFireHeld(true) end)
        pcall(function() AutoAttackController:Toggle(true) end)
        
        farmConnection = RunService.Heartbeat:Connect(function()
            local char = player.Character
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then return end

            local target = getBestTarget()
            
            if target then
                local isEvading = false
                local evadePos = nil
                
                -- LOGIKA AUTO DODGE (SCANNER AKTIF)
                if Config.AutoDodge then
                    local currentHazards = getActiveHazards() -- Scan setiap frame
                    for _, part in ipairs(currentHazards) do
                        local p1 = Vector3.new(root.Position.X, 0, root.Position.Z)
                        local p2 = Vector3.new(part.Position.X, 0, part.Position.Z)
                        
                        -- Radius bahaya diperbesar sedikit agar lebih responsif
                        if (p1 - p2).Magnitude < 30 then 
                            isEvading = true
                            -- Arah menghindar menjauhi pusat bahaya
                            local escapeDir = (p1 - p2).Unit
                            if escapeDir.X ~= escapeDir.X then escapeDir = Vector3.new(1,0,0) end
                            
                            evadePos = target.Position + (escapeDir * 40) + Vector3.new(0, Config.AutoFarmHeight, 0)
                            break -- Langsung keluar loop jika sudah ketemu bahaya terdekat
                        end
                    end
                end

                root.Velocity = Vector3.new(0,0,0) 
                
                if isEvading and evadePos then
                    root.CFrame = CFrame.lookAt(evadePos, target.Position)
                else
                    -- Mode Normal: Kembali ke atas target
                    local goalPosition = target.Position + Vector3.new(0, Config.AutoFarmHeight, 0)
                    root.CFrame = CFrame.lookAt(goalPosition, target.Position)
                end
            end
        end)
    else
        if farmConnection then farmConnection:Disconnect(); farmConnection = nil end
        pcall(function() AutoAttackController:SetManualFireHeld(false) end)
        pcall(function() AutoAttackController:Toggle(false) end)
    end
end

-- ==========================================
-- SETUP GUI (MENIRU REFERENSI GAMBAR)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.Name = "Advanced_Grinder_UI"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 280, 0, 340) -- Tinggi ditambah untuk tombol Dodge
MainFrame.Position = UDim2.new(0.5, -140, 0.5, -170)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
MainFrame.Active = true; MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local UIListLayout = Instance.new("UIListLayout", MainFrame)
UIListLayout.Padding = UDim.new(0, 8); UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
Instance.new("UIPadding", MainFrame).PaddingTop = UDim.new(0, 10)

local function CreateRow(text, hasToggle, isNumberVal, defaultNum)
    local Row = Instance.new("Frame", MainFrame)
    Row.Size = UDim2.new(0.9, 0, 0, 40)
    Row.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 6)
    
    local Label = Instance.new("TextLabel", Row)
    Label.Size = UDim2.new(0.6, 0, 1, 0); Label.Position = UDim2.new(0.05, 0, 0, 0)
    Label.BackgroundTransparency = 1; Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.TextColor3 = Color3.fromRGB(220, 220, 220); Label.Font = Enum.Font.GothamSemibold
    Label.TextSize = 13; Label.Text = text
    
    local Controller = {}
    
    if hasToggle then
        local ToggleBtn = Instance.new("TextButton", Row)
        ToggleBtn.Size = UDim2.new(0, 40, 0, 20); ToggleBtn.Position = UDim2.new(0.8, 0, 0.25, 0)
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70); ToggleBtn.Text = ""
        Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
        
        local Indicator = Instance.new("Frame", ToggleBtn)
        Indicator.Size = UDim2.new(0, 16, 0, 16); Indicator.Position = UDim2.new(0, 2, 0, 2)
        Indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Instance.new("UICorner", Indicator).CornerRadius = UDim.new(1, 0)
        
        Controller.Toggle = ToggleBtn; Controller.Indicator = Indicator
    end
    
    if isNumberVal then
        Label.Text = text .. ": " .. defaultNum
        local MinusBtn = Instance.new("TextButton", Row)
        MinusBtn.Size = UDim2.new(0, 25, 0, 25); MinusBtn.Position = UDim2.new(0.7, 0, 0.2, 0)
        MinusBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70); MinusBtn.Text = "-"
        MinusBtn.TextColor3 = Color3.fromRGB(255, 255, 255); Instance.new("UICorner", MinusBtn).CornerRadius = UDim.new(0, 4)
        
        local PlusBtn = Instance.new("TextButton", Row)
        PlusBtn.Size = UDim2.new(0, 25, 0, 25); PlusBtn.Position = UDim2.new(0.85, 0, 0.2, 0)
        PlusBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70); PlusBtn.Text = "+"
        PlusBtn.TextColor3 = Color3.fromRGB(255, 255, 255); Instance.new("UICorner", PlusBtn).CornerRadius = UDim.new(0, 4)
        
        Controller.Label = Label; Controller.Minus = MinusBtn; Controller.Plus = PlusBtn
    end
    return Controller
end

-- ==========================================
-- MENYAMBUNGKAN UI DENGAN LOGIKA
-- ==========================================
local FarmUI = CreateRow("Autofarm (Overhead + Aim)", true, false)
FarmUI.Toggle.MouseButton1Click:Connect(function()
    Config.AutoFarm = not Config.AutoFarm
    FarmUI.Indicator.Position = Config.AutoFarm and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)
    FarmUI.Toggle.BackgroundColor3 = Config.AutoFarm and Color3.fromRGB(40, 150, 255) or Color3.fromRGB(60, 60, 70)
    toggleAutoFarm(Config.AutoFarm)
end)

local DodgeUI = CreateRow("Auto Dodge Boss (AoE)", true, false)
DodgeUI.Toggle.MouseButton1Click:Connect(function()
    Config.AutoDodge = not Config.AutoDodge
    DodgeUI.Indicator.Position = Config.AutoDodge and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)
    DodgeUI.Toggle.BackgroundColor3 = Config.AutoDodge and Color3.fromRGB(40, 150, 255) or Color3.fromRGB(60, 60, 70)
end)

local HeightUI = CreateRow("Autofarm Height", false, true, Config.AutoFarmHeight)
HeightUI.Minus.MouseButton1Click:Connect(function() Config.AutoFarmHeight = Config.AutoFarmHeight - 5; HeightUI.Label.Text = "Autofarm Height: " .. Config.AutoFarmHeight end)
HeightUI.Plus.MouseButton1Click:Connect(function() Config.AutoFarmHeight = Config.AutoFarmHeight + 5; HeightUI.Label.Text = "Autofarm Height: " .. Config.AutoFarmHeight end)

local FloatUI = CreateRow("Float", true, false)
FloatUI.Toggle.MouseButton1Click:Connect(function()
    Config.Float = not Config.Float
    FloatUI.Indicator.Position = Config.Float and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)
    FloatUI.Toggle.BackgroundColor3 = Config.Float and Color3.fromRGB(40, 150, 255) or Color3.fromRGB(60, 60, 70)
    toggleFloat(Config.Float)
end)

local NoclipUI = CreateRow("Noclip", true, false)
NoclipUI.Toggle.MouseButton1Click:Connect(function()
    Config.Noclip = not Config.Noclip
    NoclipUI.Indicator.Position = Config.Noclip and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)
    NoclipUI.Toggle.BackgroundColor3 = Config.Noclip and Color3.fromRGB(40, 150, 255) or Color3.fromRGB(60, 60, 70)
    toggleNoclip(Config.Noclip)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.Keybind then
        Config.AutoFarm = not Config.AutoFarm
        FarmUI.Indicator.Position = Config.AutoFarm and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)
        FarmUI.Toggle.BackgroundColor3 = Config.AutoFarm and Color3.fromRGB(40, 150, 255) or Color3.fromRGB(60, 60, 70)
        toggleAutoFarm(Config.AutoFarm)
    end
end)

print("✅ Auto Dodge Boss Berhasil Ditambahkan!")
