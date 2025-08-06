-- Roblox compatibility shims for Color3, task, game, and wait (for linting outside Roblox)
if not Color3 then
    Color3 = {
        fromRGB = function(r, g, b)
            return {R = r/255, G = g/255, B = b/255}
        end
    }
end
if not task then
    task = {wait = function(t) if wait then return wait(t) end end}
end
if not wait then
    function wait(t) end
end
if not game then
    game = {
        GetService = function(_, name)
            return {}
        end
    }
end

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SendToBlockRemote = ReplicatedStorage.Remotes and ReplicatedStorage.Remotes.SendToBlock

-- Utility functions for detection mode
local function getColor(value, low, mid, high)
    value = tonumber(value)
    if not value then return Color3.fromRGB(150,150,150) end
    if value < low then return Color3.fromRGB(0,255,0)
    elseif value <= mid then return Color3.fromRGB(255,165,0)
    else return Color3.fromRGB(255,0,0) end
end

local function getTempColor(temp)
    temp = tonumber(temp)
    if not temp then return Color3.fromRGB(150,150,150) end
    if temp > 104 then return Color3.fromRGB(255,0,0)
    elseif temp >= 100 then return Color3.fromRGB(255,165,0)
    else return Color3.fromRGB(0,255,0) end
end

local function getBreathingStatus(model)
    local breath = model:FindFirstChild("BreathingNoise")
    if breath then
        local val = breath.Value
        if val == "Safe" then return "Safe", Color3.fromRGB(0,255,0)
        elseif val == "Critical" or val == "Zombie Breathing" then return "Bad", Color3.fromRGB(255,0,0) end
    end
    return "", Color3.fromRGB(150,150,150)
end

local Civilians = Workspace:WaitForChild("Civilians")

-- Detection mode: handle model status (no ESP/UI)
local trackedModels = {}

local function handleModel(model)
    if not model.IsA or not model:IsA("Model") then return end
    if trackedModels[model] then return end
    local humanoid = model.FindFirstChildWhichIsA and model:FindFirstChildWhichIsA("Humanoid")
    local status = model.FindFirstChild and model:FindFirstChild("SymptomStatus")
    local root = model.FindFirstChild and model:FindFirstChild("HumanoidRootPart")
    if not (humanoid and status and root) then return end
    trackedModels[model] = true
    -- Here you can add detection logic, e.g., print or log status
    print("[Detection] Model:", model.Name, "Status:", status.Value)
    -- Listen for status changes
    local connStatus
    local connDied
    if status.GetPropertyChangedSignal then
        connStatus = status:GetPropertyChangedSignal("Value"):Connect(function()
            print("[Detection] Model:", model.Name, "Status changed to:", status.Value)
        end)
    end
    if humanoid and humanoid.Died and humanoid.Died.Connect then
        connDied = humanoid.Died:Connect(function()
            if connStatus and connStatus.Disconnect then connStatus:Disconnect() end
            if connDied and connDied.Disconnect then connDied:Disconnect() end
            trackedModels[model] = nil
        end)
    end
    if model.AncestryChanged and model.AncestryChanged.Connect then
        model.AncestryChanged:Connect(function(_, parent)
            if not parent then
                if connStatus and connStatus.Disconnect then connStatus:Disconnect() end
                if connDied and connDied.Disconnect then connDied:Disconnect() end
                trackedModels[model] = nil
            end
        end)
    end
end

if Civilians and Civilians.GetChildren then
    for _, model in ipairs(Civilians:GetChildren()) do
        handleModel(model)
    end
    if Civilians.ChildAdded and Civilians.ChildAdded.Connect then
        Civilians.ChildAdded:Connect(function(child)
            task.wait(0.1)
            handleModel(child)
        end)
    end
end

local processed = {}

local function getBlockForStatus(status)
    if status == "Safe" then
        return "Survivor"
    elseif status == "Quarantine" then
        return "Quarantine"
    elseif status == "Zombie" then
        return "Liquidation"
    end
    return nil
end

local judgeStationPart = nil
if Workspace.Map and Workspace.Map.GetChildren then
    local mapChildren = Workspace.Map:GetChildren()
    judgeStationPart = mapChildren[103]
end

-- Main auto-judge loop
if Civilians and Civilians.GetChildren and SendToBlockRemote and SendToBlockRemote.FireServer and judgeStationPart then
    task.spawn(function()
        while true do
            local closestModel = nil
            local closestDist = math.huge
            for _, model in ipairs(Civilians:GetChildren()) do
                if not processed[model] and model.FindFirstChild and model:FindFirstChild("HumanoidRootPart") and model:FindFirstChild("SymptomStatus") then
                    local root = model:FindFirstChild("HumanoidRootPart")
                    local dist = (root.Position - judgeStationPart.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closestModel = model
                    end
                end
            end
            if closestModel then -- Always judge the closest
                local statusObj = closestModel:FindFirstChild("SymptomStatus")
                local status = statusObj and statusObj.Value
                local block = getBlockForStatus(status)
                if block then
                    processed[closestModel] = true
                    print("[AutoJudge] Sending", closestModel.Name, "to block:", block, "(distance:", closestDist, ")")
                    SendToBlockRemote:FireServer(block)
                end
            end
            task.wait(3)
        end
    end)
end
