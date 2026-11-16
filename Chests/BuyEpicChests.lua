local PREFIX = "[EpicBuyer] "
local INTERVAL = 0.65
local PRICE = 3200
local MAX_OWNED = 60
local POLL = 0.05
local TIMEOUT = 12
local env = type(getgenv) == "function" and getgenv() or _G
if env.GloryBoundEpicBuyerRunning then
    warn(PREFIX .. "Already running. Set getgenv().GloryBoundEpicBuyerStop = true to stop.")
    return
end
env.GloryBoundEpicBuyerRunning = true
env.GloryBoundEpicBuyerStop = false

local stateConnection
local purchased = 0
local function cleanup()
    if stateConnection then pcall(function() stateConnection:Disconnect() end) end
    env.GloryBoundEpicBuyerRunning = false
end
local function checkStopped()
    if env.GloryBoundEpicBuyerStop then error("Stopped by user.", 0) end
end
local function waitFor(test, seconds, description)
    local deadline = os.clock() + seconds
    repeat
        checkStopped()
        if test() then return end
        task.wait(POLL)
    until os.clock() >= deadline
    error("Timed out waiting for " .. description .. ". Check Cash and inventory before restarting.", 0)
end
local function child(parent, name)
    local value = parent:WaitForChild(name, 15)
    assert(value, "Missing " .. parent:GetFullName() .. "/" .. name)
    return value
end
local function copyKeys(t)
    local keys = {}
    for key in pairs(t) do keys[key] = true end
    return keys
end

local function main()
    local player = assert(game:GetService("Players").LocalPlayer, "LocalPlayer unavailable")
    local remotes = child(game:GetService("ReplicatedStorage"), "Remotes")
    local buy = child(remotes, "ChestBuy")
    local sync = child(remotes, "StateSync")
    local request = child(remotes, "RequestSync")
    assert(buy:IsA("RemoteEvent") and sync:IsA("RemoteEvent") and request:IsA("RemoteEvent"), "Expected RemoteEvents are missing")
    local function checkLobby()
        local deadline = os.clock() + 5
        while env.GloryBoundLocalZonePulse do
            checkStopped()
            assert(os.clock() < deadline, "Timed out waiting for the opener to restore Zone.")
            task.wait(POLL)
        end
        local zone, combat = player:GetAttribute("Zone"), player:GetAttribute("CombatState")
        assert(zone == "Lobby" and combat ~= "Alive" and combat ~= "Downed", "Enter the lobby and leave combat before running.")
    end
    checkLobby()
    local chests, cash
    stateConnection = sync.OnClientEvent:Connect(function(message)
        if type(message) ~= "table" then return end
        if message.full and type(message.data) == "table" then
            chests = type(message.data.OwnedChests) == "table" and message.data.OwnedChests or nil
            cash = tonumber(message.data.Cash)
        elseif chests and type(message.patch) == "table" then
            if message.patch.OwnedChests ~= nil then
                chests = type(message.patch.OwnedChests) == "table" and message.patch.OwnedChests or nil
            end
            if message.patch.Cash ~= nil then cash = tonumber(message.patch.Cash) end
        end
    end)
    print(PREFIX .. "Requesting player data...")
    for attempt = 1, 3 do
        checkStopped()
        request:FireServer()
        local deadline = os.clock() + 6
        repeat
            checkStopped()
            if chests and cash then break end
            task.wait(POLL)
        until os.clock() >= deadline
        if chests and cash then break end
    end
    assert(chests and cash, "No full inventory/Cash sync received. No purchases were sent.")
    print(string.format(PREFIX .. "Starting Cash: %s. Buying Epic Chests (dump price: %d Cash).", tostring(cash), PRICE))
    local lastSent = -math.huge
    local waitingForOpener = false
    while true do
        checkStopped()
        checkLobby()
        assert(type(chests) == "table", "Inventory state unavailable; check inventory before restarting.")
        assert(type(cash) == "number", "Cash state unavailable; check inventory before restarting.")
        local count = 0
        for _ in pairs(chests) do count = count + 1 end
        if cash < PRICE or count >= MAX_OWNED then
            if env.GloryBoundChestAutoRunning then
                if not waitingForOpener then
                    print(PREFIX .. "Waiting for the opener: insufficient Cash or chest inventory full.")
                    waitingForOpener = true
                end
                task.wait(0.25)
            else
                print(string.format(PREFIX .. "Finished after %d purchases. Cash: %s, chests: %d.", purchased, tostring(cash), count))
                return
            end
        else
            waitingForOpener = false
            while os.clock() - lastSent < INTERVAL do checkStopped(); task.wait(POLL) end
            checkLobby()
            local currentCount = 0
            for _ in pairs(chests) do currentCount = currentCount + 1 end
            if cash >= PRICE and currentCount < MAX_OWNED then
                local before = copyKeys(chests)
                local beforeCash = cash
                lastSent = os.clock()
                buy:FireServer("Epic")
                local foundUid
                waitFor(function()
                    if type(chests) ~= "table" then return false end
                    for key, value in pairs(chests) do
                        local tier = type(value) == "table" and (value.tier or value.Tier) or value
                        if not before[key] and tier == "Epic" then foundUid = key; break end
                    end
                    return foundUid ~= nil and type(cash) == "number" and cash < beforeCash
                end, TIMEOUT, "new Epic Chest and reduced Cash (the server may have rejected the purchase)")
                purchased = purchased + 1
                print(string.format(PREFIX .. "Bought %d: %s. Cash: %s", purchased, tostring(foundUid), tostring(cash)))
            end
        end
    end
end

local ok, err = xpcall(main, function(message) return tostring(message) end)
cleanup()
if not ok then warn(string.format(PREFIX .. "Stopped after %d confirmed purchases: %s", purchased, tostring(err))) end
