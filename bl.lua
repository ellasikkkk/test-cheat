-- Script Utama RPG Grinder - V8 (PREMIUM UI & MULTI-SELECT HYBRID)
-- Fitur: Multi-Select, Sequential, Bypass UUID, Tweening, Premium Glass UI, Smooth Drag

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")
local virtualUser = game:GetService("VirtualUser")
local userInputService = game:GetService("UserInputService")

-- ==========================================
-- VARIABEL & LOGIKA FARMING
-- ==========================================
local autoFarmActive = false
local TWEEN_SPEED = 150 
local currentTween = nil

local targetSettings = {
    {name = "Illusiver", active = false},
    {name = "Pufflare", active = false},
    {name = "Phant", active = false},
    {name = "Orbitfin", active = false},
    {name = "Pico", active = false}
}

local function getActiveMobsList()
    local list = {}
    for _, mob in ipairs(targetSettings) do
        if mob.active then table.insert(list, mob.name) end
    end
    return list
end

local function getMobFolder()
    local live = workspace:FindFirstChild("Live")
    if live then
        local mobs = live:FindFirstChild("Mobs")
        if mobs then return mobs:FindFirstChild("Client") end
    end
    return nil
end

local function isCorrectMob(model, targetName)
    local targetLower = string.lower(targetName)
    for _, item in ipairs(model:GetDescendants()) do
        if item:IsA("TextLabel") or item:IsA("TextButton") then
            if item.Text and string.find(string.lower(item.Text), targetLower) then
                return true
            end
        end
    end
    return false
end

local function getNearestSpecificMob(targetName)
    local nearestMobPart, targetModel = nil, nil
    local shortestDist = math.huge
    
    if not humanoidRootPart then return nil, nil end
    local mobFolder = getMobFolder()
    if not mobFolder then return nil, nil end

    for _, object in ipairs(mobFolder:GetChildren()) do
        local rootPart = object:FindFirstChild("HumanoidRootPart")
        if rootPart and isCorrectMob(object, targetName) then
            local dist = (humanoidRootPart.Position - rootPart.Position).Magnitude
            if dist < shortestDist then
                shortestDist = dist
                nearestMobPart = rootPart
                targetModel = object
            end
        end
    end
    return nearestMobPart, targetModel
end

local function tweenToTarget(targetCFrame)
    if not humanoidRootPart then return end
    
    local distance = (humanoidRootPart.Position - targetCFrame.Position).Magnitude
    local timeToTravel = distance / TWEEN_SPEED
    local tweenInfo = TweenInfo.new(timeToTravel, Enum.EasingStyle.Linear)
    
    if currentTween then currentTween:Cancel() end
    
    currentTween = tweenService:Create(humanoidRootPart, tweenInfo, {CFrame = targetCFrame})
    currentTween:Play()
    
    local bg = humanoidRootPart:FindFirstChild("AntiGravity")
    if not bg then
        bg = Instance.new("BodyGyro", humanoidRootPart)
        bg.Name = "AntiGravity"; bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9); bg.P = 9e4
    end
    
    local bv = humanoidRootPart:FindFirstChild("AntiFall")
    if not bv then
        bv = Instance.new("BodyVelocity", humanoidRootPart)
        bv.Name = "AntiFall"; bv.MaxForce = Vector3.new(0, 9e9, 0); bv.Velocity = Vector3.new(0, 0, 0)
    end
    return timeToTravel
end

local function cleanupFlight()
    if currentTween then currentTween:Cancel() end
    if humanoidRootPart then
        local bg = humanoidRootPart:FindFirstChild("AntiGravity")
        local bv = humanoidRootPart:FindFirstChild("AntiFall")
        if bg then bg:Destroy() end
        if bv then bv:Destroy() end
    end
end

-- ==========================================
-- SETUP UI (PREMIUM DESIGN)
-- ==========================================
if game.CoreGui:FindFirstChild("RPG_Grinder_Premium") then
    game.CoreGui:FindFirstChild("RPG_Grinder_Premium"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.Name = "RPG_Grinder_Premium"

local CanvasGroup = Instance.new("CanvasGroup", ScreenGui)
CanvasGroup.Position = UDim2.new(0.5, 0, 0.5, 0)
CanvasGroup.AnchorPoint = Vector2.new(0.5, 0.5)
CanvasGroup.BackgroundColor3 = Color3.fromHex("#161616")
CanvasGroup.BackgroundTransparency = 0.15
Instance.new("UICorner", CanvasGroup).CornerRadius = UDim.new(0, 12)

-- Smooth Dragging System
local dragging, dragInput, dragStart, startPos
CanvasGroup.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = CanvasGroup.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
CanvasGroup.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
userInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        CanvasGroup.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local UIPadding = Instance.new("UIPadding", CanvasGroup)
UIPadding.PaddingTop = UDim.new(0, 14); UIPadding.PaddingLeft = UDim.new(0, 14)
UIPadding.PaddingRight = UDim.new(0, 14); UIPadding.PaddingBottom = UDim.new(0, 14)

local UIListLayout = Instance.new("UIListLayout", CanvasGroup)
UIListLayout.FillDirection = "Vertical"
UIListLayout.SortOrder = "LayoutOrder"
UIListLayout.Padding = UDim.new(0, 10)

-- HEADER & TITLE
local TitleLabel = Instance.new("TextLabel", CanvasGroup)
TitleLabel.Size = UDim2.new(1, 0, 0, 0)
TitleLabel.TextXAlignment = "Left"; TitleLabel.AutomaticSize = "Y"
TitleLabel.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold)
TitleLabel.BackgroundTransparency = 1; TitleLabel.TextColor3 = Color3.new(1, 1, 1)
TitleLabel.Text = "RPG Grinder V8"; TitleLabel.TextSize = 22; TitleLabel.LayoutOrder = 1

local MinimizeBtn = Instance.new("ImageButton", TitleLabel)
MinimizeBtn.Size = UDim2.new(0, 22, 0, 22); MinimizeBtn.Position = UDim2.new(1, 0, 0, 0)
MinimizeBtn.AnchorPoint = Vector2.new(1, 0); MinimizeBtn.BackgroundTransparency = 1
MinimizeBtn.Image = "rbxassetid://10747384394"

-- MOB SELECTION BUTTONS
for i, mobData in ipairs(targetSettings) do
    local MobBtnCanvas = Instance.new("Frame", CanvasGroup)
    MobBtnCanvas.Size = UDim2.new(1, 0, 0, 35)
    MobBtnCanvas.BackgroundColor3 = Color3.new(1, 1, 1); MobBtnCanvas.BackgroundTransparency = 0.95
    MobBtnCanvas.LayoutOrder = i + 1
    Instance.new("UICorner", MobBtnCanvas).CornerRadius = UDim.new(0, 8)
    
    local UIStroke = Instance.new("UIStroke", MobBtnCanvas)
    UIStroke.Thickness = 0.6; UIStroke.Color = Color3.new(1, 1, 1); UIStroke.Transparency = 0.8
    
    local MobBtn = Instance.new("TextButton", MobBtnCanvas)
    MobBtn.Size = UDim2.new(1, 0, 1, 0)
    MobBtn.BackgroundTransparency = 1
    MobBtn.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold)
    MobBtn.Text = "  " .. mobData.name .. " (OFF)"
    MobBtn.TextColor3 = Color3.new(0.6, 0.6, 0.6)
    MobBtn.TextXAlignment = "Left"; MobBtn.TextSize = 16
    
    MobBtn.MouseButton1Click:Connect(function()
        mobData.active = not mobData.active
        if mobData.active then
            tweenService:Create(MobBtnCanvas, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 170, 255), BackgroundTransparency = 0.2}):Play()
            MobBtn.Text = "  " .. mobData.name .. " (ON)"
            MobBtn.TextColor3 = Color3.new(1, 1, 1)
        else
            tweenService:Create(MobBtnCanvas, TweenInfo.new(0.2), {BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.95}):Play()
            MobBtn.Text = "  " .. mobData.name .. " (OFF)"
            MobBtn.TextColor3 = Color3.new(0.6, 0.6, 0.6)
        end
    end)
end

-- START/STOP BUTTON
local StartBtn = Instance.new("TextButton", CanvasGroup)
StartBtn.Size = UDim2.new(1, 0, 0, 40)
StartBtn.Text = "START FARM"
StartBtn.AutoButtonColor = false
StartBtn.TextColor3 = Color3.new(1, 1, 1)
StartBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
StartBtn.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold)
StartBtn.TextSize = 18; StartBtn.LayoutOrder = 10
Instance.new("UICorner", StartBtn).CornerRadius = UDim.new(0, 8)

-- Minimize/Maximize Logic
local Closed = false
local BaseSize = UDim2.new(0, 250, 0, UIListLayout.AbsoluteContentSize.Y + 28)
CanvasGroup.Size = BaseSize

MinimizeBtn.MouseButton1Click:Connect(function()
    if not Closed then
        tweenService:Create(CanvasGroup, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 250, 0, TitleLabel.TextBounds.Y + 28)
        }):Play()
        tweenService:Create(MinimizeBtn, TweenInfo.new(0.25), {Rotation = 45}):Play()
    else
        tweenService:Create(CanvasGroup, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = BaseSize
        }):Play()
        tweenService:Create(MinimizeBtn, TweenInfo.new(0.25), {Rotation = 0}):Play()
    end
    Closed = not Closed
end)

-- ==========================================
-- LOGIKA LOOP UTAMA (SEQUENTIAL)
-- ==========================================
local function startAutoFarmLoop()
    spawn(function()
        local seqIndex = 1 
        while autoFarmActive do
            character = player.Character or player.CharacterAdded:Wait()
            humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
            local myHumanoid = character:WaitForChild("Humanoid", 5)
            local activeMobs = getActiveMobsList()

            if humanoidRootPart and myHumanoid and #activeMobs > 0 then
                if seqIndex > #activeMobs then seqIndex = 1 end
                local currentSearchName = activeMobs[seqIndex]
                local targetPart, targetModel = getNearestSpecificMob(currentSearchName)
                
                if targetPart and targetModel then
                    TitleLabel.Text = "Hunting: " .. currentSearchName
                    local distance = (humanoidRootPart.Position - targetPart.Position).Magnitude
                    
                    if distance > 8 then
                        tweenToTarget(targetPart.CFrame * CFrame.new(0, 0, 3))
                    else
                        cleanupFlight() 
                        humanoidRootPart.CFrame = CFrame.lookAt(humanoidRootPart.Position, targetPart.Position)
                        
                        local tool = character:FindFirstChildOfClass("Tool") or player.Backpack:FindFirstChildOfClass("Tool")
                        if tool then
                            myHumanoid:EquipTool(tool)
                            tool:Activate()
                        else
                            virtualUser:CaptureController()
                            virtualUser:ClickButton1(Vector2.new(0,0))
                        end
                    end
                else
                    cleanupFlight()
                    TitleLabel.Text = "Looking for next..."
                    seqIndex = seqIndex + 1
                    if seqIndex > #activeMobs then seqIndex = 1 end
                end
            elseif #activeMobs == 0 then
                cleanupFlight()
            end
            runService.Heartbeat:Wait() 
        end
        cleanupFlight()
        TitleLabel.Text = "RPG Grinder V8"
    end)
end

StartBtn.MouseButton1Click:Connect(function()
    autoFarmActive = not autoFarmActive
    if autoFarmActive then
        local activeMobs = getActiveMobsList()
        if #activeMobs == 0 then
            autoFarmActive = false
            StartBtn.Text = "SELECT A MOB FIRST!"
            StartBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
            wait(2)
            StartBtn.Text = "START FARM"
            StartBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            return
        end
        tweenService:Create(StartBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 180, 80)}):Play()
        StartBtn.Text = "STOP FARM"
        startAutoFarmLoop()
    else
        tweenService:Create(StartBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 40, 40)}):Play()
        StartBtn.Text = "START FARM"
        cleanupFlight()
    end
end)

player.Idled:Connect(function()
    virtualUser:ClickButton2(Vector2.new()) 
end)

print("✅ RPG Grinder V8 Premium UI Loaded!")
