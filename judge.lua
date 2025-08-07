repeat task.wait() until game:IsLoaded()

repeat task.wait() until game:IsLoaded()

local function waitForChildDeep(parent, childName, timeout)
    local startTime = tick()
    while tick() - startTime < timeout do
        local child = parent:FindFirstChild(childName)
        if child then return child end
        task.wait(0.5)
    end
    return nil
end

print("Waiting for Civilians folder...")
local Civilians = waitForChildDeep(workspace, "Civilians", 30)
if not Civilians then
    warn("❌ Civilians folder NOT found after 30 seconds!")
    return
end
print("✅ Civilians folder found!")

print("Waiting for Remotes folder...")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = waitForChildDeep(ReplicatedStorage, "Remotes", 30)
if not Remotes then
    warn("❌ Remotes folder NOT found after 30 seconds!")
    return
end
print("✅ Remotes folder found!")

print("Waiting for SendToBlock remote...")
local SendToBlock = waitForChildDeep(Remotes, "SendToBlock", 30)
if not SendToBlock then
    warn("❌ SendToBlock remote NOT found after 30 seconds!")
    return
end
print("✅ SendToBlock remote found!")

-- Now you can safely run your logic using Civilians and SendToBlock


local SkipEvent = game:GetService("ReplicatedStorage").Remotes.Skip
SkipEvent:FireServer()

local success, err = pcall(function()

    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local StarterGui = game:GetService("StarterGui")

    local function notify(title, text, duration)
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = title,
                Text = text,
                Duration = duration or 5
            })
        end)
    end

    notify("Starting Script", "Waiting for remotes & civilians...")

    -- ✅ WAIT FOR REQUIRED OBJECTS
    local Civilians = Workspace:WaitForChild("Civilians", 10)
    local liquidationRemote = ReplicatedStorage:WaitForChild("SendToLiquidation", 10)
    local survivorRemote = ReplicatedStorage:WaitForChild("SendToSurvivor", 10)
    local quarantineRemote = ReplicatedStorage:WaitForChild("SendToQuarantine", 10)

    assert(Civilians, "❌ Civilians folder not found")
    assert(liquidationRemote, "❌ SendToLiquidation remote not found")
    assert(survivorRemote, "❌ SendToSurvivor remote not found")
    assert(quarantineRemote, "❌ SendToQuarantine remote not found")

    local function getBreathingStatus(model)
        local breath = model:FindFirstChild("BreathingNoise")
        if breath then
            local val = breath.Value
            if val == "Safe" then return "Safe" else return "Bad" end
        end
        return ""
    end

    local remote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("SendToBlock")

local function determineAndSendStatus(model)
    local status = model:FindFirstChild("SymptomStatus")
    if not status then return end
    
    local currentStatus = status.Value
    
    if currentStatus == "Zombie" then
        notify("Liquidation", model.Name .. " (Zombie)")
        remote:FireServer("Liquidation")
        return
    elseif currentStatus == "Safe" then
        notify("Survivor", model.Name .. " (Safe)")
        remote:FireServer("Survivor")
        return
    elseif currentStatus == "Quarantine" then
        -- Your existing quarantine logic
        local isInfected, isSafe = false, false
        -- Determine infected or safe status based on your logic
        
        if isInfected then
            notify("Liquidation", model.Name .. " (Infected)")
            remote:FireServer("Liquidation")
        elseif isSafe then
            notify("Survivor", model.Name .. " (Recovered)")
            remote:FireServer("Survivor")
        else
            notify("Quarantine", model.Name .. " (Uncertain)")
            remote:FireServer("Quarantine")
        end
    end
end

    local trackedModels = {}

    local function handleModel(model)
        if not model:IsA("Model") or trackedModels[model] then return end

        local humanoid = model:FindFirstChildWhichIsA("Humanoid")
        local status = model:FindFirstChild("SymptomStatus")
        local root = model:FindFirstChild("HumanoidRootPart")
        if not (humanoid and status and root) then return end

        trackedModels[model] = true
        determineAndSendStatus(model)

        status:GetPropertyChangedSignal("Value"):Connect(function()
            determineAndSendStatus(model)
        end)

        humanoid.Died:Connect(function()
            trackedModels[model] = nil
        end)
    end

    -- Hook existing civilians
    for _, model in ipairs(Civilians:GetChildren()) do
        handleModel(model)
    end

    Civilians.ChildAdded:Connect(function(child)
        task.wait(0.1)
        handleModel(child)
    end)

    notify("✅ Script Loaded", "Auto-sort now running.")

end)

-- Print errors if script fails entirely
if not success then
    warn("❌ Script failed to run:", err)
end
