-- Prevent double load
if getgenv().ANTI_AFK_LOADED then
    warn("Anti-AFK already loaded!")
    return
end
getgenv().ANTI_AFK_LOADED = true

-- Config
getgenv().AntiAFKEnabled = true
getgenv().AntiAFKInterval = 60 -- seconds
getgenv().AntiAFKDebug = false

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    warn("Anti-AFK: LocalPlayer not found")
    return
end

local idleConnection

local function log(...)
    if getgenv().AntiAFKDebug then
        print("[AntiAFK]", ...)
    end
end

local function onIdle()
    if not getgenv().AntiAFKEnabled then
        return
    end

    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)

    log("Idle detected, anti-AFK input sent")
end

local function startAntiAFK()
    if idleConnection and idleConnection.Connected then
        idleConnection:Disconnect()
    end

    idleConnection = LocalPlayer.Idled:Connect(onIdle)
    log("Anti-AFK active")
end

startAntiAFK()

-- Extra heartbeat pulse for some games/executors
task.spawn(function()
    while getgenv().ANTI_AFK_LOADED do
        if getgenv().AntiAFKEnabled then
            pcall(function()
                VirtualUser:CaptureController()
            end)
        end
        task.wait(getgenv().AntiAFKInterval)
    end
end)

-- Auto reattach when character respawns
LocalPlayer.CharacterAdded:Connect(function()
    if getgenv().ANTI_AFK_LOADED then
        task.wait(1)
        startAntiAFK()
    end
end)

-- Optional helper to stop anti afk manually in executor
getgenv().StopAntiAFK = function()
    getgenv().ANTI_AFK_LOADED = false
    getgenv().AntiAFKEnabled = false

    if idleConnection and idleConnection.Connected then
        idleConnection:Disconnect()
    end

    warn("Anti-AFK stopped")
end

warn("Anti-AFK auto execute loaded")
