local PREFIX = "[ChestAuto] "
local INTERVAL = 1.15
local RESPONSE_TIMEOUT = 12
local STATE_TIMEOUT = 12
local POLL = 0.05
local env = type(getgenv) == "function" and getgenv() or _G
if env.GloryBoundChestAutoRunning then
    warn(PREFIX .. "Already running. Set getgenv().GloryBoundChestAutoStop = true to stop.")
    return
end
env.GloryBoundChestAutoRunning = true
env.GloryBoundChestAutoStop = false

local player, playerGui, stateConnection, resultConnection
local pulseActive = false
local sent, opened = 0, 0
local pending = false
local function restoreZone()
    if not pulseActive then return end
    local ok, err = pcall(function()
        if player and player:GetAttribute("Zone") == "Arena" then
            player:SetAttribute("Zone", "Lobby")
        end
    end)
    pulseActive = false
    env.GloryBoundLocalZonePulse = false
    if not ok then warn(PREFIX .. "Could not restore local Zone: " .. tostring(err)) end
end
local function stopped()
    if env.GloryBoundChestAutoStop then error("Stopped by user.", 0) end
end
local function waitFor(test, seconds, description)
    local deadline = os.clock() + seconds
    repeat
        stopped()
        if test() then return end
        task.wait(POLL)
    until os.clock() >= deadline
    error("Timed out waiting for " .. description .. ". Check inventory before restarting.", 0)
end
local function child(parent, name)
    local value = parent:WaitForChild(name, 15)
    assert(value, "Missing " .. parent:GetFullName() .. "/" .. name)
    return value
end
local function visuals()
    if not playerGui then return false end
    local reveal = playerGui:FindFirstChild("ChestReveal")
    local opening = reveal and reveal:FindFirstChild("ChestOpening", true)
    local cutscene = playerGui:FindFirstChild("ChestCutscene3D")
    return opening ~= nil or (cutscene ~= nil and cutscene.Enabled == true)
end
local function checkLobby()
    local zone, combat = player:GetAttribute("Zone"), player:GetAttribute("CombatState")
    assert(zone == "Lobby" and combat ~= "Alive" and combat ~= "Downed", "Enter the lobby and leave combat before running.")
end
local function clearOnce()
    if sent == 0 then return end
    if pending then
        warn(PREFIX .. "A request was not confirmed; check inventory before restarting.")
    end
    task.wait(0.8)
    if player:GetAttribute("Zone") ~= "Lobby" then
        warn(PREFIX .. "Zone is no longer Lobby; skipped automatic clear.")
        return
    end
    print(PREFIX .. "Opening finished or stopped; clearing the reveal queue once...")
    env.GloryBoundLocalZonePulse = true
    pulseActive = true
    local ok, err = xpcall(function()
        player:SetAttribute("Zone", "Arena")
        task.wait(0.4)
    end, function(message) return tostring(message) end)
    restoreZone()
    if not ok then
        warn(PREFIX .. "Clear failed: " .. tostring(err))
        return
    end
    task.wait(0.6)
    if visuals() then
        warn(PREFIX .. "A reveal is still visible after the one-shot clear. Stop here and rejoin or clear it manually.")
    else
        print(PREFIX .. "No reveal GUI is currently visible after the one-shot clear.")
    end
end
local function cleanup()
    restoreZone()
    if resultConnection then pcall(function() resultConnection:Disconnect() end) end
    if stateConnection then pcall(function() stateConnection:Disconnect() end) end
    env.GloryBoundChestAutoRunning = false
end
local function main()
    player = assert(game:GetService("Players").LocalPlayer, "LocalPlayer unavailable")
    local rs = game:GetService("ReplicatedStorage")
    playerGui = child(player, "PlayerGui")
    local remotes = child(rs, "Remotes")
    local open, result = child(remotes, "ChestOpen"), child(remotes, "ChestResult")
    local sync, request = child(remotes, "StateSync"), child(remotes, "RequestSync")
    assert(open:IsA("RemoteEvent") and result:IsA("RemoteEvent") and sync:IsA("RemoteEvent") and request:IsA("RemoteEvent"), "Expected RemoteEvents are missing")
    checkLobby()
    assert(not visuals(), "A chest reveal is already active. Clear it or rejoin before starting.")
    local chests
    stateConnection = sync.OnClientEvent:Connect(function(message)
        if type(message) ~= "table" then return end
        if message.full and type(message.data) == "table" then
            chests = type(message.data.OwnedChests) == "table" and message.data.OwnedChests or nil
        elseif chests and type(message.patch) == "table" and message.patch.OwnedChests ~= nil then
            chests = type(message.patch.OwnedChests) == "table" and message.patch.OwnedChests or nil
        end
    end)
    print(PREFIX .. "Requesting player data...")
    for attempt = 1, 3 do
        stopped()
        request:FireServer()
        local deadline = os.clock() + 6
        repeat
            stopped()
            if chests then break end
            task.wait(POLL)
        until os.clock() >= deadline
        if chests then break end
    end
    assert(chests, "No full inventory sync received. No chests were opened.")
    local queue = {}
    for uid, value in pairs(chests) do
        local tier = type(value) == "table" and (value.tier or value.Tier) or value
        assert(type(uid) == "string" and type(tier) == "string", "Unexpected chest data; stopped before opening.")
        table.insert(queue, {uid = uid, tier = tier})
    end
    table.sort(queue, function(a, b)
        local na = tonumber(a.uid:match("_(%d+)$")) or math.huge
        local nb = tonumber(b.uid:match("_(%d+)$")) or math.huge
        return na == nb and a.uid < b.uid or na < nb
    end)
    if #queue == 0 then print(PREFIX .. "No chests found."); return end
    local currentUid, response
    resultConnection = result.OnClientEvent:Connect(function(data)
        if type(data) == "table" and data.chestUid == currentUid then response = data end
    end)
    print(string.format(PREFIX .. "%d chests queued; reveal queue will be cleared once at the end.", #queue))
    local lastSent = -math.huge
    for index, entry in ipairs(queue) do
        stopped()
        checkLobby()
        assert(type(chests) == "table" and chests[entry.uid] ~= nil, "Chest " .. entry.uid .. " is no longer in inventory.")
        while os.clock() - lastSent < INTERVAL do stopped(); task.wait(POLL) end
        checkLobby()
        currentUid, response = entry.uid, nil
        lastSent = os.clock()
        sent = sent + 1
        pending = true
        open:FireServer(entry.uid)
        waitFor(function() return response ~= nil end, RESPONSE_TIMEOUT, "ChestResult for " .. entry.uid)
        pending = false
        assert(response.ok == true, "Chest " .. entry.uid .. " rejected: " .. tostring(response.reason or "unknown reason"))
        assert(type(response.item) == "table", "Chest " .. entry.uid .. " returned no item; check inventory before restarting.")
        waitFor(function() return type(chests) == "table" and chests[entry.uid] == nil end, STATE_TIMEOUT, "inventory update for " .. entry.uid)
        opened = opened + 1
        local item = response.item
        print(string.format(PREFIX .. "%d/%d opened %s (%s): %s", opened, #queue, entry.uid, entry.tier, tostring(item.name or item.id or item.kind or "reward")))
        currentUid = nil
    end
    print(string.format(PREFIX .. "Confirmed %d/%d chests opened.", opened, #queue))
end

local ok, err = xpcall(main, function(message) return tostring(message) end)
if not ok then warn(string.format(PREFIX .. "Stopped after %d confirmed openings: %s", opened, tostring(err))) end
local clearOk, clearError = xpcall(clearOnce, function(message) return tostring(message) end)
if not clearOk then warn(PREFIX .. "Clear failed: " .. tostring(clearError)) end
cleanup()
