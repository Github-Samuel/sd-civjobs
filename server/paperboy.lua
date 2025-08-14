local config = require('configs/main')
local paperboyConfig = require('configs/paperboy')

-- Variables to track active paperboy jobs
local activePaperboyJobs = {}

--- Callback to start a paperboy job session
--- @param source number Player source ID
--- @return boolean success Whether the job was started successfully
--- @return string message Status message for the player
lib.callback.register('sd-civilianjobs:server:startPaperboyJob', function(source)
    local identifier = GetIdentifier(source)
    if not identifier then return false end
    
    -- Check if player already has an active paperboy job
    if activePaperboyJobs[identifier] then
        return false, "You already have an active paperboy job!"
    end
    
    -- Initialize paperboy job tracking
    activePaperboyJobs[identifier] = {
        source = source,
        startTime = os.time(),
        newspapersDelivered = 0,
        totalEarned = 0
    }
    
    return true, "Paperboy job started! Check your map for delivery locations. Come back to me once you don't want to continue." 
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
    local paymentConfig = paperboyConfig.Payment[playerLevel] or paperboyConfig.Payment[1]
    local cashReward = math.random(paymentConfig.min, paymentConfig.max)
    
    -- Don't give money immediately, just accumulate for final paycheck
    paperboyJobData.totalEarned = paperboyJobData.totalEarned + cashReward
    
    -- Ensure player entry exists before updating stats
    EnsurePlayerEntry(identifier)
    
    -- Update paperboy job tracking and stats
    paperboyJobData.newspapersDelivered = paperboyJobData.newspapersDelivered + 1
    UpdateStats(identifier, "paperboy", "newspapers_delivered", 1)
    UpdateStats(identifier, "paperboy", "successes", 1)
    
    -- Award XP based on level
    local xpReward = paperboyConfig.XP[playerLevel] or paperboyConfig.XP[1]
    AwardXP(identifier, "paperboy", xpReward)
    
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
    local bonusPayment = 0
    
    -- Calculate bonus based on deliveries completed
    if paperboyJobData.newspapersDelivered >= 10 then
        bonusPayment = math.floor(paperboyJobData.totalEarned * 0.1) -- 10% bonus for 10+ deliveries
    end
    
    local totalPayout = paperboyJobData.totalEarned + bonusPayment
    
    -- Give final paycheck (base earnings + bonus)
    local Player = GetPlayer(source)
    if Player then
        Player.Functions.AddMoney('cash', totalPayout)
        -- Update cash_earned stat with total amount
        UpdateStats(identifier, "paperboy", "cash_earned", totalPayout)
        
        -- Update routes completed (every 5 deliveries counts as a route)
        local routesCompleted = math.floor(paperboyJobData.newspapersDelivered / 5)
        if routesCompleted > 0 then
            UpdateStats(identifier, "paperboy", "routes_completed", routesCompleted)
        end
    end
    
    -- Prepare paperboy job summary
    local paperboyJobSummary = {
        newspapersDelivered = paperboyJobData.newspapersDelivered,
        totalEarned = paperboyJobData.totalEarned,
        bonusPayment = bonusPayment,
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