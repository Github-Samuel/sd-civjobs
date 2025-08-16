local config = require('configs/main')
local paperboyConfig = require('configs/paperboy')

-- Variables to track active paperboy jobs
local activePaperboyJobs = {}

--- Function to select a random delivery route for paperboy job
--- @param source number Player source ID
--- @return table deliveryData Contains route information and locations
local SelectPaperboyRoute = function(source)
    local playerPed = GetPlayerPed(source)
    local deliveryRoutes = paperboyConfig.DeliveryRoutes
    
    -- Simply select a random route
    local selectedRoute = deliveryRoutes[math.random(#deliveryRoutes)]
    local routeName = selectedRoute.name
    
    -- Create delivery data structure
    local deliveryData = {
        locations = {},
        netid = NetworkGetNetworkIdFromEntity(playerPed),
        totalDeliveries = #selectedRoute.locations,
        routeName = routeName
    }
    
    for i, location in ipairs(selectedRoute.locations) do
        deliveryData.locations[i] = {
            x = location.x,
            y = location.y,
            z = location.z
        }
    end
    
    return deliveryData
end

--- Callback to start a paperboy job session
--- @param source number Player source ID
--- @return boolean success Whether the job was started successfully
--- @return string message Status message for the player
--- @return table deliveryData Delivery locations and job data
lib.callback.register('sd-civilianjobs:server:startPaperboyJob', function(source)
    local identifier = GetIdentifier(source)
    if not identifier then return false, "Failed to get player identifier" end
    
    -- Check if player already has an active paperboy job
    if activePaperboyJobs[identifier] then
        return false, "You already have an active paperboy job!"
    end
    
    -- Select best delivery route
    local deliveryData = SelectPaperboyRoute(source)
    
    -- Give player newspapers (WEAPON_ACIDPACKAGE)
    local Player = GetPlayer(source)
    if Player then
        Player.Functions.AddItem('WEAPON_ACIDPACKAGE', deliveryData.totalDeliveries)
        TriggerClientEvent('inventory:client:ItemBox', source, exports.ox_inventory:Items()['WEAPON_ACIDPACKAGE'], "add", deliveryData.totalDeliveries)
    end
    
    -- Initialize paperboy job tracking
    activePaperboyJobs[identifier] = {
        source = source,
        startTime = os.time(),
        newspapersDelivered = 0,
        totalEarned = 0,
        totalDeliveries = deliveryData.totalDeliveries,
        deliveryData = deliveryData
    }
    
    return true, "Paperboy job started! Throw newspapers at the marked locations. Come back when finished.", deliveryData
end)

--- Callback to complete a paperboy delivery task
--- @param source number Player source ID
--- @return boolean success Whether the task was completed successfully
--- @return number cashReward Amount of cash added to paycheck
lib.callback.register('sd-civilianjobs:server:completePaperboyTask', function(source)
    local identifier = GetIdentifier(source)
    if not identifier or not activePaperboyJobs[identifier] then return false end
    
    local paperboyJobData = activePaperboyJobs[identifier]
    
    -- Get player level to determine reward
    local playerLevel = GetPlayerLevel(identifier, "paperboy")
    local rewardConfig = paperboyConfig.Rewards[playerLevel] or paperboyConfig.Rewards[1]
    local cashReward = math.random(rewardConfig.min, rewardConfig.max)
    
    -- Don't give money immediately, just accumulate for final paycheck
    paperboyJobData.totalEarned = paperboyJobData.totalEarned + cashReward
    
    -- Ensure player entry exists before updating stats
    EnsurePlayerEntry(identifier)
    
    -- Update paperboy job tracking and stats
    paperboyJobData.newspapersDelivered = paperboyJobData.newspapersDelivered + 1
    UpdateStats(identifier, "paperboy", "newspapers_delivered", 1)
    UpdateStats(identifier, "paperboy", "successes", 1)
    
    -- Award base XP for successful delivery
    AwardXP(identifier, "paperboy", paperboyConfig.BaseXP)
    
    print("^2[Civilian Jobs] Paperboy stats updated for " .. identifier .. ": newspaper delivered, $" .. cashReward .. " added to paycheck^0")
    
    return true, cashReward
end)

--- Callback to end paperboy job session and process final paycheck
--- @param source number Player source ID
--- @return boolean success Whether the job was ended successfully
--- @return table summary Job completion summary with earnings and stats
lib.callback.register('sd-civilianjobs:server:endPaperboyJob', function(source)
    local identifier = GetIdentifier(source)
    if not identifier or not activePaperboyJobs[identifier] then return false end
    
    local paperboyJobData = activePaperboyJobs[identifier]
    local workTime = os.time() - paperboyJobData.startTime
    
    local totalPayout = paperboyJobData.totalEarned
    
    -- Give final paycheck
    local Player = GetPlayer(source)
    if Player then
        Player.Functions.AddMoney('cash', totalPayout)
        -- Update cash_earned stat with total amount
        UpdateStats(identifier, "paperboy", "cash_earned", totalPayout)
        
        -- Update routes completed only if ALL deliveries in the route were completed
        if paperboyJobData.newspapersDelivered >= paperboyJobData.totalDeliveries then
            UpdateStats(identifier, "paperboy", "routes_completed", 1)
        end
    end
    
    local paperboyJobSummary = {
        newspapersDelivered = paperboyJobData.newspapersDelivered,
        totalEarned = paperboyJobData.totalEarned,
        workTime = workTime
    }
    
    -- Clean up active paperboy job
    activePaperboyJobs[identifier] = nil
    
    return true, paperboyJobSummary
end)

--- Callback to check if player has an active paperboy job
--- @param source number Player source ID
--- @return boolean hasActiveJob Whether the player has an active paperboy job
lib.callback.register('sd-civilianjobs:server:hasActivePaperboyJob', function(source)
    local identifier = GetIdentifier(source)
    if not identifier then return false end
    
    return activePaperboyJobs[identifier] ~= nil
end)

--- Callback to validate newspaper drop at delivery location
--- @param source number Player source ID
--- @param coords vector3 Coordinates where newspaper was thrown
--- @param netid number Network ID for validation
--- @return boolean success Whether the delivery was successful
--- @return number remainingDeliveries Number of deliveries remaining
lib.callback.register('sd-civilianjobs:server:validatePaperboyDrop', function(source, coords, netid)
    local identifier = GetIdentifier(source)
    if not identifier or not activePaperboyJobs[identifier] then return false, 0 end
    
    local paperboyJobData = activePaperboyJobs[identifier]
    
    -- Get player level to determine reward
    local playerLevel = GetPlayerLevel(identifier, "paperboy")
    local rewardConfig = paperboyConfig.Rewards[playerLevel] or paperboyConfig.Rewards[1]
    local cashReward = math.random(rewardConfig.min, rewardConfig.max)
    
    -- Don't give money immediately, just accumulate for final paycheck
    paperboyJobData.totalEarned = paperboyJobData.totalEarned + cashReward
    
    -- Ensure player entry exists before updating stats
    EnsurePlayerEntry(identifier)
    
    -- Update paperboy job tracking and stats
    paperboyJobData.newspapersDelivered = paperboyJobData.newspapersDelivered + 1
    UpdateStats(identifier, "paperboy", "newspapers_delivered", 1)
    UpdateStats(identifier, "paperboy", "successes", 1)
    
    -- Award base XP for successful delivery
    AwardXP(identifier, "paperboy", paperboyConfig.BaseXP)
    
    -- Calculate remaining deliveries
    local remainingDeliveries = paperboyJobData.totalDeliveries - paperboyJobData.newspapersDelivered
    
    print("^2[Civilian Jobs] Paperboy delivery validated for " .. identifier .. ": $" .. cashReward .. " added to paycheck, " .. remainingDeliveries .. " deliveries remaining^0")
    
    return true, remainingDeliveries
end)

--- Callback to retrieve paperboy job statistics
--- @param source number Player source ID
--- @return table paperboyStats Raw paperboy statistics from database
lib.callback.register('sd-civilianjobs:server:getPaperboyStats', function(source)
    local identifier = GetIdentifier(source)
    if not identifier then return {} end
    
    for _, record in ipairs(levelData) do
        if record.Identifier == identifier then
            local playerStats = json.decode(record.Stats) or {}
            return playerStats.paperboy or {}
        end
    end
    
    return {} -- Return empty table if player not found
end)