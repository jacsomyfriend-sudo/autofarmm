repeat task.wait(0) until game:IsLoaded()

print("started")

_G.toggle = true

local HttpService = game:GetService("HttpService")
local JSON_FILE = "farm_count.json"
local PLACE_ID = 12360882630 -- duels lobby place (farm map)
local FARM_CFRAME = CFrame.new(193, 439, -1078)

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local localPlayer = Players.LocalPlayer

-- ========= TURN COUNT (1 / 2) =========

local function getCount()
    if not (readfile and isfile and isfile(JSON_FILE)) then
        return 1
    end

    local ok, result = pcall(function()
        local file = readfile(JSON_FILE)
        local data = HttpService:JSONDecode(file)
        return data.count or 1
    end)

    return ok and result or 1
end

local function updateCount(newCount)
    local data = { count = newCount or 1 }
    local json = HttpService:JSONEncode(data)

    if writefile then
        writefile(JSON_FILE, json)
        return true
    end
    return false
end

-- ========= ACCOUNT PRESENCE =========

local function areBothAccountsInServer()
    if not _G.acc1 or not _G.acc2 then
        return false
    end

    local acc1InServer = false
    local acc2InServer = false

    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name == _G.acc1 then
            acc1InServer = true
        end
        if player.Name == _G.acc2 then
            acc2InServer = true
        end

        if acc1InServer and acc2InServer then
            return true
        end
    end

    return acc1InServer and acc2InServer
end

-- ========= RELIABLE TELEPORT BACK TO LOBBY =========

local function teleportBackToLobby()
    -- Keep trying until it works (handles Teleport throttling / failures)
    while true do
        local success, err = pcall(function()
            TeleportService:Teleport(PLACE_ID, localPlayer)
        end)

        if success then
            break
        end

        warn("Teleport to lobby failed, retrying...  Error:", err)
        task.wait(2)
    end
end

-- If one of the two accounts leaves the current server, follow them back to lobby
local function onPlayerRemoving(player)
    if not _G.toggle then return end
    if not _G.acc1 or not _G.acc2 then return end

    -- Only care about the linked accounts
    if player.Name == _G.acc1 or player.Name == _G.acc2 then
        -- If the one leaving is NOT us, we are the other account and should go back to lobby
        if player ~= localPlayer then
            -- If we're already in lobby, no need to teleport
            if game.PlaceId ~= PLACE_ID then
                teleportBackToLobby()
            end
        end
    end
end

Players.PlayerRemoving:Connect(onPlayerRemoving)

-- ========= UI / RANK OVERLAY =========

if _G.toggle then

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RankOverlay"
screenGui.DisplayOrder = 10
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.new(1, 0, 1, 0)
background.BackgroundColor3 = Color3.new(0, 0, 0)
background.BorderSizePixel = 0
background.Parent = screenGui

local rankText = Instance.new("TextLabel")
rankText.Name = "RankText"
rankText.Size = UDim2.new(0, 400, 0, 100)
rankText.Position = UDim2.new(0.5, -200, 0.5, -50)
rankText.AnchorPoint = Vector2.new(0.5, 0.5)
rankText.BackgroundTransparency = 1
rankText.TextColor3 = Color3.new(1, 1, 1)
rankText.TextSize = 48
rankText.Font = Enum.Font.GothamBold
rankText.TextStrokeTransparency = 0.5
rankText.TextStrokeColor3 = Color3.new(0, 0, 0)
rankText.Parent = background

local isVisible = true

local function toggleVisibility()
    isVisible = not isVisible
    background.Visible = isVisible
end

local function onInputBegan(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.P then
        toggleVisibility()
    end
end

UserInputService.InputBegan:Connect(onInputBegan)

local function updateRank()
    local success = pcall(function()
        local rankValue = localPlayer.leaderstats["Solo Rank"].Value
        rankText.Text = "Rank: 👑" .. tostring(rankValue)
    end)

    if not success then
        rankText.Text = "Rank: N/A"
    end
end

task.spawn(function()
    local webhookUrl = "https://discordapp.com/api/webhooks/1462392089433346172/h3cCbMQQ8TBctGbLHU2uq1GWMvyzl4_cBSUNfP5thufwpmbnlK40tV9s6BRyf9-PFFfs"

    local player = localPlayer
    local coinsText = player.leaderstats["Solo Rank"].Value
    local message = player.Name .. " Solo Rank: " .. coinsText

    local requestBody = HttpService:JSONEncode({
        content = message
    })

    request({
        Url = webhookUrl,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = requestBody
    })

    updateRank()

    local leaderstats = player:WaitForChild("leaderstats")
    local soloRank = leaderstats:WaitForChild("Solo Rank")

    soloRank:GetPropertyChangedSignal("Value"):Connect(updateRank)
end)

-- ========= ALWAYS FORCE COORDINATES IN LOBBY =========
-- This "spams" moving you to FARM_CFRAME whenever:
--  - you're in the lobby place (PLACE_ID)
--  - both accounts are in the server

task.spawn(function()
    while _G.toggle do
        if game.PlaceId == PLACE_ID and areBothAccountsInServer() then
            local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
            local hrp = character:FindFirstChild("HumanoidRootPart")
                or character:WaitForChild("HumanoidRootPart", 5)

            if hrp then
                hrp.CFrame = FARM_CFRAME
            end
        end

        task.wait(1) -- how often to re-apply the CFrame
    end
end)

-- ========= MAIN FLOW (LOBBY vs MATCH) =========

local tped = false

if game.PlaceId == PLACE_ID then
    -- In duels lobby / farm place:
    --  - now handled by the loop above that keeps snapping you to FARM_CFRAME
    repeat
        task.wait()
    until areBothAccountsInServer()
    -- nothing else needed here; the loop keeps you at the coords

else
    -- In a match / other place (not PLACE_ID):
    --  - coordinate the reset + teleport back to lobby
    repeat
        task.wait()
    until areBothAccountsInServer()
        and localPlayer.Character
        and localPlayer.Character:FindFirstChild("HumanoidRootPart")

    StarterGui:SetCore("SendNotification", {
        Title = getCount(),
        Duration = 10,
        Button1 = "",
        Callback = CatNotification,
        Text = ""
    })

    if (_G.acc1 == localPlayer.Name and getCount() == 1)
        or (_G.acc2 == localPlayer.Name and getCount() == 2) then

        StarterGui:SetCore("SendNotification", {
            Title = "Reset " .. getCount(),
            Duration = 10,
            Button1 = "",
            Text = ""
        })

        local character = localPlayer.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Dead)
            end
        end

        localPlayer.CharacterAdded:Wait()

        tped = true
        task.wait(0)
        teleportBackToLobby()
    end

    repeat
        task.wait()
    until tped

    if getCount() == 1 then
        updateCount(2)
    else
        updateCount(1)
    end

    teleportBackToLobby()
end

end
