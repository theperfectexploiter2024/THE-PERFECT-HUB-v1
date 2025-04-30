local SilentAimModule = {}

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local SilentAimEnabled = false
local SilentAimTarget = nil
local SilentAimClosestPart = nil
local SilentAimLockedTarget = nil
local characterAddedConnections = {}
local localPlayerCharacterConnection = nil
local originalIndex = nil 
local tracerUpdateConnection = nil 
local currentTracer = nil 
local lastTracerUpdate = 0
local TRACER_UPDATE_INTERVAL = 0.3 

local function findNearestEnemyForSilentAim()
    if SilentAimLockedTarget and SilentAimLockedTarget.Character and SilentAimLockedTarget.Character:FindFirstChild("Humanoid") then
        local humanoid = SilentAimLockedTarget.Character.Humanoid
        if humanoid.Health > 0 then
            return SilentAimLockedTarget, SilentAimLockedTarget.Character:FindFirstChild(getgenv().Rake.Settings.AimPart or "Head")
        else
            SilentAimLockedTarget = nil
        end
    end

    local MouseLocation = UserInputService:GetMouseLocation()
    local ClosestToMouse = math.huge
    local ClosestPlayer, ClosestPart = nil, nil

    for _, Player in pairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer then
            local Character = Player.Character
            if Character and Character:FindFirstChild("Humanoid") and Character.Humanoid.Health > 0 then
                local Part = Character:FindFirstChild(getgenv().Rake.Settings.AimPart or "Head")
                if Part then
                    local ScreenPosition, OnScreen = Camera:WorldToViewportPoint(Part.Position)
                    local MouseDistance = (Vector2.new(ScreenPosition.X, ScreenPosition.Y) - MouseLocation).Magnitude
                    local Score = MouseDistance
                    
                    if Score < ClosestToMouse then
                        ClosestToMouse = Score
                        ClosestPlayer = Player
                        ClosestPart = Part
                    end
                end
            end
        end
    end

    if ClosestPlayer then
        SilentAimLockedTarget = ClosestPlayer
    end

    return ClosestPlayer, ClosestPart
end

local function cleanHighlightsAndTracers(plr)
    if plr and plr.Character then
        for _, obj in pairs(plr.Character:GetChildren()) do
            if obj:IsA("Highlight") or obj:IsA("Beam") then
                obj:Destroy()
            end
        end
    end
    currentTracer = nil
end

local function highlightSilentAimTarget(plr)
    if plr and plr.Character then
        cleanHighlightsAndTracers(plr)
        local highlight = Instance.new("Highlight")
        highlight.Parent = plr.Character
        highlight.FillColor = Color3.new(1, 1, 1)
        highlight.OutlineColor = Color3.new(1, 1, 1)
        highlight.FillTransparency = 0.6
        highlight.OutlineTransparency = 0
    end
end

local function createTracerSilentAimTarget(plr)
    if not plr or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return
    end

    cleanHighlightsAndTracers(plr)
    local tracer = Instance.new("Beam")
    tracer.Parent = plr.Character
    tracer.FaceCamera = true
    tracer.Color = ColorSequence.new(Color3.new(1, 1, 1))
    tracer.Width0 = 0.1
    tracer.Width1 = 0.1
    local attachment0 = Instance.new("Attachment", LocalPlayer.Character.HumanoidRootPart)
    local attachment1 = Instance.new("Attachment", plr.Character.HumanoidRootPart)
    tracer.Attachment0 = attachment0
    tracer.Attachment1 = attachment1
    currentTracer = tracer
end

local function startTracerUpdateLoop()
    if tracerUpdateConnection then
        tracerUpdateConnection:Disconnect()
        tracerUpdateConnection = nil
    end

    tracerUpdateConnection = RunService.Heartbeat:Connect(function()
        if not SilentAimEnabled or not SilentAimLockedTarget then
            return
        end

        local currentTime = tick()
        if currentTime - lastTracerUpdate < TRACER_UPDATE_INTERVAL then
            return
        end
        lastTracerUpdate = currentTime

        local targetCharacter = SilentAimLockedTarget.Character
        local targetHumanoid = targetCharacter and targetCharacter:FindFirstChild("Humanoid")
        if not targetCharacter or not targetHumanoid or targetHumanoid.Health <= 0 then
            return
        end

        if not currentTracer or not currentTracer.Parent then
            highlightSilentAimTarget(SilentAimLockedTarget)
            createTracerSilentAimTarget(SilentAimLockedTarget)
        end
    end)
end

function SilentAimModule:Enable()
    if SilentAimEnabled then
        return
    end

    SilentAimEnabled = true
    local mt = getrawmetatable(game)
    originalIndex = mt.__index
    setreadonly(mt, false)

    local PredictionValue = getgenv().Rake.Settings.Prediction or 0.04

    originalIndex = hookmetamethod(game, "__index", function(self, key)
        if not checkcaller() and SilentAimEnabled and SilentAimTarget and self:IsA("Mouse") and key == "Hit" then
            if SilentAimTarget and SilentAimTarget.Character and SilentAimTarget.Character:FindFirstChild(getgenv().Rake.Settings.AimPart or "Head") then
                local target = SilentAimTarget.Character[getgenv().Rake.Settings.AimPart or "Head"]
                local Position = target.Position + (SilentAimTarget.Character.Head.Velocity * PredictionValue)
                return CFrame.new(Position)
            end
        end
        return originalIndex(self, key)
    end)

    if localPlayerCharacterConnection then
        localPlayerCharacterConnection:Disconnect()
    end
    localPlayerCharacterConnection = LocalPlayer.CharacterAdded:Connect(function(newCharacter)
        task.wait(0.1)
        if SilentAimEnabled and SilentAimLockedTarget then
            highlightSilentAimTarget(SilentAimLockedTarget)
            createTracerSilentAimTarget(SilentAimLockedTarget)
        end
    end)

    if SilentAimLockedTarget then
        highlightSilentAimTarget(SilentAimLockedTarget)
        createTracerSilentAimTarget(SilentAimLockedTarget)
        startTracerUpdateLoop()
    end
end

function SilentAimModule:Disable()
    if not SilentAimEnabled then
        return
    end

    SilentAimEnabled = false

    local mt = getrawmetatable(game)
    if originalIndex then
        mt.__index = originalIndex
        setreadonly(mt, true)
        originalIndex = nil
    end

    if tracerUpdateConnection then
        tracerUpdateConnection:Disconnect()
        tracerUpdateConnection = nil
    end

    if SilentAimTarget and SilentAimTarget.Character then
        cleanHighlightsAndTracers(SilentAimTarget)
    end

    for _, connection in pairs(characterAddedConnections) do
        connection:Disconnect()
    end
    characterAddedConnections = {}

    if localPlayerCharacterConnection then
        localPlayerCharacterConnection:Disconnect()
        localPlayerCharacterConnection = nil
    end

    SilentAimTarget = nil
    SilentAimClosestPart = nil
    SilentAimLockedTarget = nil
end

function SilentAimModule:ToggleTarget()
    if not SilentAimEnabled then
        return
    end

    if SilentAimTarget then
        if SilentAimTarget and SilentAimTarget.Character then
            cleanHighlightsAndTracers(SilentAimTarget)
        end
        if characterAddedConnections[SilentAimTarget] then
            characterAddedConnections[SilentAimTarget]:Disconnect()
            characterAddedConnections[SilentAimTarget] = nil
        end
        SilentAimTarget = nil
        SilentAimClosestPart = nil
        SilentAimLockedTarget = nil

        if tracerUpdateConnection then
            tracerUpdateConnection:Disconnect()
            tracerUpdateConnection = nil
        end
    else
        SilentAimTarget, SilentAimClosestPart = findNearestEnemyForSilentAim()
        if SilentAimTarget then
            highlightSilentAimTarget(SilentAimTarget)
            createTracerSilentAimTarget(SilentAimTarget)

            local characterAddedConnection = SilentAimTarget.CharacterAdded:Connect(function(newCharacter)
                task.wait(0.1)
                if SilentAimTarget == SilentAimLockedTarget and SilentAimEnabled then
                    SilentAimTarget, SilentAimClosestPart = SilentAimLockedTarget, newCharacter:FindFirstChild(getgenv().Rake.Settings.AimPart or "Head")
                    if SilentAimTarget and SilentAimClosestPart then
                        highlightSilentAimTarget(SilentAimTarget)
                        createTracerSilentAimTarget(SilentAimLockedTarget)
                    end
                end
            end)
            characterAddedConnections[SilentAimTarget] = characterAddedConnection

            startTracerUpdateLoop()
        else
        end
    end
end

return SilentAimModule
