local repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"
local Library     = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Window = Library:CreateWindow({
    Title   = "Symptom Checker",
    Center  = true,
    AutoShow = true,
})

local Tabs = {
    Main       = Window:AddTab("Main"),
    Quarantine = Window:AddTab("Quarantine"),
    Debug      = Window:AddTab("Debug"),
    Settings   = Window:AddTab("Settings"),
}

local StatusBox  = Tabs.Main:AddLeftGroupbox("Scanner")
local ResultBox  = Tabs.Main:AddRightGroupbox("Result")
local ControlBox = Tabs.Main:AddLeftGroupbox("Controls")

local LblStatus  = StatusBox:AddLabel("Status:  Idle")
local LblTarget  = StatusBox:AddLabel("Target:  —")
local LblTimer   = StatusBox:AddLabel("Next in:  —")

local LblVerdict  = ResultBox:AddLabel("Verdict:  —")
local LblSymCount = ResultBox:AddLabel("Symptoms: —")
local LblSymList  = ResultBox:AddLabel("", true)

local QuarantineControlBox = Tabs.Quarantine:AddLeftGroupbox("Controls")
local QuarantineStatusBox  = Tabs.Quarantine:AddRightGroupbox("Status")

local LblQStatus  = QuarantineStatusBox:AddLabel("please select a person")
local LblQTarget  = QuarantineStatusBox:AddLabel("Target:  —")
local LblQVerdict = QuarantineStatusBox:AddLabel("Verdict:  —")

local DebugBox   = Tabs.Debug:AddLeftGroupbox("Log (last 12_events)")
local LblLog     = DebugBox:AddLabel("No events yet.", true)

local AutoJudgeToggle = ControlBox:AddToggle("AutoJudge", {
    Text    = "Enable Auto-Judge",
    Default = false,
})

local DirectStatusToggle = ControlBox:AddToggle("DirectStatusMode", {
    Text    = "Use Direct SymptomStatus",
    Default = true,
})

local NoclipToggle = ControlBox:AddToggle("Noclip", {
    Text    = "Noclip",
    Default = false,
})

local QuarantineToggle = QuarantineControlBox:AddToggle("QuarantineAutoJudge", {
    Text    = "Enable Quarantine Auto-Judge",
    Default = false,
})

local LogHistory = {}

function _log(msg)
    local entry = ("[%s] %s"):format(os.date("%H:%M:%S"), msg)
    table.insert(LogHistory, 1, entry)
    if #LogHistory > 12 then
        table.remove(LogHistory, #LogHistory)
    end
    LblLog:SetText(table.concat(LogHistory, "\n"))
end

local SymptomDB = {
    { name = "Rash",                 category = "Appearance",        status = "Safe"      },
    { name = "Minor Bruising",       category = "Appearance",        status = "Safe"      },
    { name = "Profuse Sweating",     category = "Appearance",        status = "Possible"  },
    { name = "Pale Gray Skin",       category = "Appearance",        status = "Possible"  },
    { name = "Mouth Blood",          category = "Appearance",        status = "Possible"  },
    { name = "Skin Cracks",          category = "Appearance",        status = "Dangerous" },
    { name = "Bloated Face",         category = "Appearance",        status = "Dangerous" },
    { name = "Glowing Eyes",         category = "Appearance",        status = "Dangerous" },
    { name = "Bleeding Eyes",        category = "Appearance",        status = "Dangerous" },
    { name = "Green Skin",           category = "Appearance",        status = "Dangerous" },
    { name = "Foaming at Mouth",     category = "Appearance",        status = "Dangerous" },
    { name = "Faceless",             category = "Appearance",        status = "Dangerous" },
    { name = "Extreme Blood",        category = "Appearance",        status = "Dangerous" },
    { name = "Zombie Blood",         category = "Appearance",        status = "Dangerous" },
    { name = "Heavy Bitemarks",      category = "Appearance",        status = "Dangerous" },
    { name = "Zombie Spores",        category = "Appearance",        status = "Dangerous" },
    { name = "Paranoia",             category = "Mental/Behaviour",  status = "Possible"  },
    { name = "Sneezing",             category = "Sounds",            status = "Safe"      },
    { name = "Coughing",             category = "Sounds",            status = "Safe"      },
    { name = "Sniffling",            category = "Sounds",            status = "Safe"      },
    { name = "Growling",             category = "Sounds",            status = "Dangerous" },
    { name = "Zombie Breathing",     category = "Sounds",            status = "Dangerous" },
    { name = "Normal Pulse",         category = "Vitals",            status = "Safe"      },
    { name = "Normal Temperature",   category = "Vitals",            status = "Safe"      },
    { name = "Limp",                 category = "Vitals/Movement",   status = "Safe"      },
    { name = "Shivering",            category = "Vitals",            status = "Possible"  },
    { name = "Elevated Pulse",       category = "Vitals",            status = "Possible"  },
    { name = "Elevated Temperature", category = "Vitals",            status = "Possible"  },
    { name = "Spasms",               category = "Vitals",            status = "Dangerous" },
    { name = "Extreme Pulse",        category = "Vitals",            status = "Dangerous" },
    { name = "Extreme Temperature",  category = "Vitals",            status = "Dangerous" },
    { name = "Zombie Movements",     category = "Movement",          status = "Dangerous" },
}

local SymptomLookup = {}
for _, s in ipairs(SymptomDB) do
    SymptomLookup[s.name] = s.status
end

local function getCurrentCivilian()
    local repStorage = game:GetService("ReplicatedStorage")
    local gameData = repStorage:FindFirstChild("Game_Data")
    if not gameData then return nil end

    local civVal = gameData:FindFirstChild("CurrentCivilian")
    if not civVal then return nil end

    local civ = nil
    if civVal:IsA("ObjectValue") then
        civ = civVal.Value
    elseif civVal:IsA("StringValue") then
        local civsFolder = workspace:FindFirstChild("Civilians")
        if civsFolder then
            civ = civsFolder:FindFirstChild(civVal.Value)
        end
    end

    if civ and civ.Parent == workspace:FindFirstChild("Civilians") then
        return civ
    end

    return nil
end

local function getCurrentQuarantine()
    local repStorage = game:GetService("ReplicatedStorage")
    local gameData = repStorage:FindFirstChild("Game_Data")
    if not gameData then return nil end

    local qVal = gameData:FindFirstChild("CurrentQuarantine")
    if not qVal then return nil end

    local civ = nil
    if qVal:IsA("ObjectValue") then
        civ = qVal.Value
    elseif qVal:IsA("StringValue") then
        local civsFolder = workspace:FindFirstChild("Civilians")
        if civsFolder then
            civ = civsFolder:FindFirstChild(qVal.Value)
        end
    end

    if civ and civ.Parent == workspace:FindFirstChild("Civilians") then
        return civ
    end

    return nil
end

local function hasContaminatedItems(civName)
    local civItemsFolder = workspace:FindFirstChild("CivItems")
    local contamFolder = game:GetService("ReplicatedStorage"):FindFirstChild("ContaminatedItems")

    if not civItemsFolder or not contamFolder then return false end

    local personFolder = civItemsFolder:FindFirstChild(civName)
    if not personFolder then return false end

    local badNames = {}
    for _, item in ipairs(contamFolder:GetChildren()) do
        badNames[item.Name] = true
    end

    for _, obj in ipairs(personFolder:GetDescendants()) do
        if badNames[obj.Name] then
            return true
        end
    end

    return false
end

local function judgeSymptoms(civ)
    if DirectStatusToggle.Value then
        local statusVal = civ:FindFirstChild("SymptomStatus")
        if statusVal then
            local valStr = tostring(statusVal.Value):lower()
            if valStr:find("zombie") then
                return "Liquidation", 0, { "✓ Direct Status: Zombie" }
            elseif valStr:find("safe") then
                return "Survivor", 0, { "✓ Direct Status: Safe" }
            end
        end
    end

    if hasContaminatedItems(civ.Name) then
        return "Liquidation", 0, { "✗ Contaminated Item Detected" }
    end

    local sympFolder = civ:FindFirstChild("Symptoms")
    if not sympFolder then
        return "Survivor", 0, { "⚠ No Symptoms folder found" }
    end

    local tier = 0
    local details = {}
    local unknown = {}

    for _, child in ipairs(sympFolder:GetChildren()) do
        local status = SymptomLookup[child.Name]
        if status then
            if status == "Dangerous" and tier < 2 then tier = 2
            elseif status == "Possible" and tier < 1 then tier = 1
            end
            local icon = status == "Safe" and "✓" or status == "Possible" and "⚡" or "✗"
            table.insert(details, icon .. " " .. child.Name)
        else
            table.insert(unknown, child.Name)
        end
    end

    if #unknown > 0 then
        _log("Unknown symptoms: " .. table.concat(unknown, ", "))
    end

    local verdict = (tier == 2) and "Liquidation"
                 or (tier == 1) and "Quarantine"
                 or "Survivor"

    return verdict, #sympFolder:GetChildren(), details
end

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:SetFolder("SymptomChecker")
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

RunService.Stepped:Connect(function()
    if NoclipToggle.Value and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

_log("Script loaded. Tracking targets exclusively via Game_Data.CurrentCivilian...")

task.spawn(function()
    while true do
        if not AutoJudgeToggle.Value then
            LblStatus:SetText("Status:  Paused")
            task.wait(0.5)
            continue
        end

        LblStatus:SetText("Status:  Finding target...")
        local civ = getCurrentCivilian()
        if not civ then
            LblTarget:SetText("Target:  None found")
            LblStatus:SetText("Status:  No current civilian!")
            task.wait(1)
            continue
        end

        LblTarget:SetText("Target:  " .. civ.Name)

        LblStatus:SetText("Status:  Judging...")
        local verdict, symCount, details = judgeSymptoms(civ)

        LblSymCount:SetText("Symptoms: " .. symCount)
        LblSymList:SetText(table.concat(details, "\n"))
        LblVerdict:SetText("Verdict:  " .. verdict)
        _log(civ.Name .. " → " .. verdict)

        local SendEvent = game:GetService("ReplicatedStorage").Remotes.SendToBlock
        SendEvent:FireServer(verdict)

        LblStatus:SetText("Status:  ✓ Fired → " .. verdict)
        
        for i = 30, 1, -1 do
            LblTimer:SetText(("Next in:  %.1fs"):format(i * 0.1))
            task.wait(0.1)
        end
        task.wait(0.02)
    end
end)

task.spawn(function()
    local lastQuarantineCiv = nil
    while true do
        task.wait(0.1)
        
        if not QuarantineToggle.Value then
            LblQStatus:SetText("Status:  Paused")
            continue
        end

        local civ = getCurrentQuarantine()
        if not civ then
            LblQStatus:SetText("please select a person")
            LblQTarget:SetText("Target:  —")
            lastQuarantineCiv = nil
            continue
        end

        if civ == lastQuarantineCiv then
            LblQStatus:SetText("Status:  Waiting for next selection...")
            continue
        end

        LblQTarget:SetText("Target:  " .. civ.Name)
        LblQStatus:SetText("Status:  Selected! Waiting 3s...")
        
        task.wait(3)

        civ = getCurrentQuarantine()
        if not civ or civ == lastQuarantineCiv then
            continue
        end

        local verdict = "Survivor"
        local statusVal = civ:FindFirstChild("SymptomStatus")
        if statusVal then
            local valStr = tostring(statusVal.Value):lower()
            if valStr:find("zombie") then
                verdict = "Liquidation"
            end
        end

        LblQVerdict:SetText("Verdict:  " .. verdict)
        _log("[Quarantine] " .. civ.Name .. " → " .. verdict)

        local SendEvent2 = game:GetService("ReplicatedStorage").Remotes.SendToBlock2
        SendEvent2:FireServer(verdict)

        LblQStatus:SetText("Status:  ✓ Fired → " .. verdict)
        lastQuarantineCiv = civ
    end
end)
