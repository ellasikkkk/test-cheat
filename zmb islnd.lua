-- ==========================================
-- SCRIPT AUTOFARM (OVERHEAD + KNIT HOOK)
-- Fitur: Autofarm Overhead, Float, Noclip, Direct Auto-Attack
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
-- FUNGSI LOGIKA (BACKEND)
-- ==========================================

-- 1. FUNGSI MENCARI MUSUH VIA RUNTIME ENTITY
local function getBestTarget()
    local bestTarget = nil
    local shortestDistance = math.huge
    
    if not EntityController.Runtime then return nil end
    
    -- Membaca tabel Runtime dari game itu sendiri
    for entityId, entityData in pairs(EntityController.Runtime) do
        -- Dapatkan model fisiknya
        local model = EntityController:GetEntityModel(entityId)
        
        -- Validasi jika model ada dan memiliki nyawa
        if model and model.PrimaryPart then
            local healthInfo = EntityController:GetPredictedHealthInfo(entityId)
            
            -- Jika bukan player dan masih hidup (asumsi HP > 0)
            if healthInfo and healthInfo.Health > 0 and not Players:GetPlayerFromCharacter(model) then
                local distance = (rootPart.Position - model.PrimaryPart.Position).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    bestTarget = model.PrimaryPart
                end
            end
        end
    end
    return bestTarget
end

-- 2. FUNGSI FLOAT (MELAYANG)
local function toggleFloat(state)
    if state then
        if not floatBodyVelocity then
            floatBodyVelocity = Instance.new("BodyVelocity")
            floatBodyVelocity.Name = "AutoFarmFloat"
            floatBodyVelocity.MaxForce = Vector3.new(0, math.huge, 0)
            floatBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            floatBodyVelocity.Parent = rootPart
        end
        -- Kunci di ketinggian tertentu dari tanah (opsional, sementara dikunci Y velocity)
        rootPart.CFrame = CFrame.new(rootPart.Position.X, Config.FloatHeight, rootPart.Position.Z)
    else
        if floatBodyVelocity then
            floatBodyVelocity:Destroy()
            floatBodyVelocity = nil
        end
    end
end

-- 3. FUNGSI NOCLIP (TEMBUS TEMBOK)
local function toggleNoclip(state)
    if state then
        if not noclipConnection then
            noclipConnection = RunService.Stepped:Connect(function()
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
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

-- 4. FUNGSI AUTOFARM LOOP (OVERHEAD + AIM + ATTACK)
local function toggleAutoFarm(state)
    if state then
        -- Memicu fungsi Auto Attack bawaan game secara paksa
        pcall(function() AutoAttackController:SetManualFireHeld(true) end)
        
        farmConnection = RunService.Heartbeat:Connect(function()
            local target = getBestTarget()
            if target then
                -- Posisi persis di atas musuh
                local overheadPosition = target.Position + Vector3.new(0, Config.AutoFarmHeight, 0)
                
                -- Memindahkan dan membidik (Aiming ke bawah menatap musuh)
                rootPart.CFrame = CFrame.lookAt(overheadPosition, target.Position)
                
                -- Pastikan tidak jatuh dengan menahan gravitasi
                rootPart.Velocity = Vector3.new(0,0,0)
            end
        end)
    else
        if farmConnection then farmConnection:Disconnect() end
        -- Matikan serangan
        pcall(function() AutoAttackController:SetManualFireHeld(false) end)
    end
end

-- ==========================================
-- SETUP GUI (MENIRU REFERENSI GAMBAR)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.Name = "Advanced_Grinder_UI"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 280, 0, 300)
MainFrame.Position = UDim2.new(0.5, -140, 0.5, -150)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
MainFrame.Active = true; MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local UIListLayout = Instance.new("UIListLayout", MainFrame)
UIListLayout.Padding = UDim.new(0, 8); UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
Instance.new("UIPadding", MainFrame).PaddingTop = UDim.new(0, 10)

-- Template Pembuat Baris UI
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
        
        Controller.Toggle = ToggleBtn
        Controller.Indicator = Indicator
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
        
        Controller.Label = Label
        Controller.Minus = MinusBtn
        Controller.Plus = PlusBtn
    end
    
    return Controller
end

-- Membangun UI dan Menyambungkan Logika
local FarmUI = CreateRow("Autofarm (Overhead + Aim)", true, false)
FarmUI.Toggle.MouseButton1Click:Connect(function()
    Config.AutoFarm = not Config.AutoFarm
    FarmUI.Indicator.Position = Config.AutoFarm and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)
    FarmUI.Toggle.BackgroundColor3 = Config.AutoFarm and Color3.fromRGB(40, 150, 255) or Color3.fromRGB(60, 60, 70)
    toggleAutoFarm(Config.AutoFarm)
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

-- Keybind Listener
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.Keybind then
        -- Simulasikan klik pada toggle autofarm
        Config.AutoFarm = not Config.AutoFarm
        FarmUI.Indicator.Position = Config.AutoFarm and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)
        FarmUI.Toggle.BackgroundColor3 = Config.AutoFarm and Color3.fromRGB(40, 150, 255) or Color3.fromRGB(60, 60, 70)
        toggleAutoFarm(Config.AutoFarm)
    end
end)

print("✅ Advanced Grinder Terpasang Sempurna!")
