repeat task.wait() until game:IsLoaded()

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

    local function determineAndSendStatus(model)
        local status = model:FindFirstChild("SymptomStatus")
        if not status then return end

        local currentStatus = status.Value
        local name = model.Name

        if currentStatus == "Zombie" then
            notify("Liquidation", name .. " (Zombie)")
            liquidationRemote:FireServer(model)
            return
        end

        if currentStatus == "Safe" then
            notify("Survivor", name .. " (Safe)")
            survivorRemote:FireServer(model)
            return
        end

        if currentStatus == "Quarantine" then
            local bpm = model:FindFirstChild("BPM")
            local temp = model:FindFirstChild("Temp")
            local breathingVal = getBreathingStatus(model)
            local contamValue = model:FindFirstChild("HasContaminatedItems")

            local bpmVal = bpm and tonumber(bpm.Value) or 0
            local tempVal = temp and tonumber(temp.Value) or 0
            local hasContaminatedItems = contamValue and contamValue:IsA("BoolValue") and contamValue.Value

            local isInfected = false
            local isSafe = false

            if bpmVal > 140 or bpmVal < 90 then isInfected = true end
            if tempVal > 104 then isInfected = true end
            if breathingVal ~= "Safe" then isInfected = true end
            if hasContaminatedItems then isInfected = true end

            if tempVal <= 100 and breathingVal == "Safe" and not hasContaminatedItems and bpmVal >= 90 and bpmVal <= 140 then
                isSafe = true
            end

            if isInfected then
                notify("Liquidation", name .. " (Infected)")
                liquidationRemote:FireServer(model)
            elseif isSafe then
                notify("Survivor", name .. " (Recovered)")
                survivorRemote:FireServer(model)
            else
                notify("Quarantine", name .. " (Uncertain)")
                quarantineRemote:FireServer(model)
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
