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

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 5
        })
    end)
end

notify("Starting Script", "Waiting for Civilians and Remotes...")

local Civilians = waitForChildDeep(Workspace, "Civilians", 30)
if not Civilians then
    warn("❌ Civilians folder NOT found after 30 seconds!")
    return
end

local Remotes = waitForChildDeep(ReplicatedStorage, "Remotes", 30)
if not Remotes then
    warn("❌ Remotes folder NOT found after 30 seconds!")
    return
end

local SendToBlock = waitForChildDeep(Remotes, "SendToBlock", 30)
if not SendToBlock then
    warn("❌ SendToBlock remote NOT found after 30 seconds!")
    return
end

notify("✅ Script Loaded", "Auto-sort is now running.")

local function getBreathingStatus(model)
    local breath = model:FindFirstChild("BreathingNoise")
    if breath then
        local val = breath.Value
        if val == "Safe" then return "Safe"
        elseif val == "Critical" or val == "Zombie Breathing" then return "Bad" end
    end
    return ""
end

local debounceStatus = {}

local function determineAndSendStatus(model)
    local status = model:FindFirstChild("SymptomStatus")
    if not status then return end

    -- If we are still waiting for cooldown for this model, skip
    if debounceStatus[model] then return end
    debounceStatus[model] = true  -- start cooldown

    local currentStatus = status.Value
    local name = model.Name

    if currentStatus == "Zombie" then
        notify("Liquidation", name .. " (Zombie)")
        SendToBlock:FireServer("Liquidation")

    elseif currentStatus == "Safe" then
        notify("Survivor", name .. " (Safe)")
        SendToBlock:FireServer("Survivor")

    elseif currentStatus == "Quarantine" then
        local bpm = model:FindFirstChild("BPM")
        local temp = model:FindFirstChild("Temp")
        local breathingVal = getBreathingStatus(model)
        local contamValue = model:FindFirstChild("HasContaminatedItems")

        local bpmVal = bpm and tonumber(bpm.Value) or 0
        local tempVal = temp and tonumber(temp.Value) or 0
        local hasContaminatedItems = contamValue and contamValue:IsA("BoolValue") and contamValue.Value

        local isInfected = false
        local isSafe = false

        if bpmVal > 140 or bpmVal < 90 then
            isInfected = true
        end

        if tempVal > 104 then
            isInfected = true
        end

        if breathingVal ~= "Safe" then
            isInfected = true
        end

        if hasContaminatedItems then
            isInfected = true
        end

        if tempVal <= 100 and breathingVal == "Safe" and not hasContaminatedItems and bpmVal >= 90 and bpmVal <= 140 then
            isSafe = true
        end

        if isInfected then
            notify("Liquidation", name .. " (Infected)")
            SendToBlock:FireServer("Liquidation")
        elseif isSafe then
            notify("Survivor", name .. " (Recovered)")
            SendToBlock:FireServer("Survivor")
        else
            notify("Quarantine", name .. " (Uncertain)")
            SendToBlock:FireServer("Quarantine")
        end
    end

    -- Wait 3 seconds before allowing next judgment for this model
    task.delay(3, function()
        debounceStatus[model] = false
    end)
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

    local connStatus = status:GetPropertyChangedSignal("Value"):Connect(function()
        determineAndSendStatus(model)
    end)

    local connDied = humanoid.Died:Connect(function()
        connStatus:Disconnect()
        connDied:Disconnect()
        trackedModels[model] = nil
    end)
end

-- Hook existing civilians
for _, model in ipairs(Civilians:GetChildren()) do
    handleModel(model)
end

-- Hook new civilians as they spawn
Civilians.ChildAdded:Connect(function(child)
    task.wait(0.1)
    handleModel(child)
end)
