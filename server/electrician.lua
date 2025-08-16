local config = require('configs/main')
local electricianConfig = require('configs/electrician')

-- Variables to track active electrician jobs
local activeElectricianJobs = {}

--- Function to process reward distribution with level-based rewards and XP system
--- @param src number Player source
--- @param rewards table Level-based rewards table or simple rewards table
--- @param config table Config table to check for logging
--- @param eventName string Event name for logging
--- @param jobType string The type of job for stats tracking
local GiveRewards = function(src, rewards, config, eventName, jobType)
    local Player = GetPlayer(src)
    local identifier = GetIdentifier(src)
    
    local playerLevel = 1
    if jobType and identifier then
        playerLevel = GetPlayerLevel(identifier, jobType)
    end
    
    local rewardTable = rewards
    if rewards[playerLevel] then
        rewardTable = rewards[playerLevel]
    elseif rewards[1] then
        rewardTable = rewards[1]
    end

    if rewardTable then
        local cashAmount = math.random(rewardTable.min, rewardTable.max)
        
        -- Give money to player
        Player.Functions.AddMoney('cash', cashAmount)
        
        -- Update stats
        if jobType and identifier then
            UpdateStats(identifier, jobType, "cash_earned", cashAmount)
            UpdateStats(identifier, jobType, "successes", 1)
            
            -- Award base XP
            if config.BaseXP then
                AwardXP(identifier, jobType, config.BaseXP)
            end
        end
        
        -- Log the reward
        if config and config.Logging then
            lib.logger(src, eventName, string.format('%s received $%d cash (Level %d)', GetFullName(src), cashAmount, playerLevel), identifier, 'cash', tostring(cashAmount))
        end
    end
end

--- Callback to retrieve a specific player's level and XP data based on their identifier
--- @param source number Player source ID
--- @param jobType string The type of job to get info for
--- @return table playerInfo Player's level and XP information
lib.callback.register('sd-civilianjobs:server:getPlayerInfo', function(source, jobType)
    local identifier = GetIdentifier(source)
    if not identifier then
        if jobType then
            return {level = 1, xp = 0, jobType = jobType}
        else
            return {}
        end
    end
    
    for _, record in ipairs(levelData) do
        if record.Identifier == identifier then
            local playerData = json.decode(record.levelData) or {}
            
            if jobType then
                local xp = playerData[jobType] or 0
                local level = CalculateLevel(xp, jobType)
                return {level = level, xp = xp, jobType = jobType}
            else
                local allData = {}
                for job, xpAmount in pairs(playerData) do
                    allData[job] = {
                        level = CalculateLevel(xpAmount, job),
                        xp = xpAmount
                    }
                end
                return allData
            end
        end
    end

    if jobType then
        return {level = 1, xp = 0, jobType = jobType}
    else
        return {}
    end
end)

--- Callback to start an electrician job session
--- @param source number Player source ID
--- @return boolean success Whether the job was started successfully
--- @return string message Status message for the player
lib.callback.register('sd-civilianjobs:server:startElectricianJob', function(source)
    local identifier = GetIdentifier(source)
    if not identifier then return false end
    
    -- Check if player already has an active electrician job
    if activeElectricianJobs[identifier] then
        return false, "You already have an active electrician job!"
    end
    
    -- Initialize electrician job tracking
    activeElectricianJobs[identifier] = {
        source = source,
        startTime = os.time(),
        lightPolesFixed = 0,
        electricalBoxesFixed = 0,
        totalEarned = 0
    }
    
    return true, "Electrician job started! Check your map for work locations. Come back to me once you don't want to continue." 
end)

--- Callback to complete an electrician repair task
--- @param source number Player source ID
--- @param repairType string Type of repair ("lightPole" or "electricalBox")
--- @return boolean success Whether the task was completed successfully
--- @return number cashReward Amount of cash added to paycheck
lib.callback.register('sd-civilianjobs:server:completeElectricianTask', function(source, repairType)
    local identifier = GetIdentifier(source)
    if not identifier or not activeElectricianJobs[identifier] then return false end
    
    local electricianJobData = activeElectricianJobs[identifier]
    local cashReward = math.random(electricianConfig.Rewards[1].min, electricianConfig.Rewards[1].max)
    
    -- Don't give money immediately, just accumulate for final paycheck
    electricianJobData.totalEarned = electricianJobData.totalEarned + cashReward
    
    -- Ensure player entry exists before updating stats
    EnsurePlayerEntry(identifier)
    
    -- Update electrician job tracking and stats
    if repairType == "lightPole" then
        electricianJobData.lightPolesFixed = electricianJobData.lightPolesFixed + 1
        UpdateStats(identifier, "electrician", "light_poles_fixed", 1)
    elseif repairType == "electricalBox" then
        electricianJobData.electricalBoxesFixed = electricianJobData.electricalBoxesFixed + 1
        UpdateStats(identifier, "electrician", "electrical_boxes_fixed", 1)
    end
    
    -- Update general stats (but don't add cash_earned until final paycheck)
    UpdateStats(identifier, "electrician", "successes", 1)
    
    -- Award XP
    AwardXP(identifier, "electrician", electricianConfig.BaseXP)
    
    print("^2[Civilian Jobs] Electrician stats updated for " .. identifier .. ": " .. repairType .. " completed, $" .. cashReward .. " added to paycheck^0")
    
    return true, cashReward
end)

--- Callback to end electrician job session and process final paycheck
--- @param source number Player source ID
--- @return boolean success Whether the job was ended successfully
--- @return table summary Job completion summary with earnings and stats
lib.callback.register('sd-civilianjobs:server:endElectricianJob', function(source)
    local identifier = GetIdentifier(source)
    if not identifier or not activeElectricianJobs[identifier] then return false end
    
    local electricianJobData = activeElectricianJobs[identifier]
    local workTime = os.time() - electricianJobData.startTime
    local bonusPayment = 0
    
    -- Calculate bonus based on work completed
    local totalTasksCompleted = electricianJobData.lightPolesFixed + electricianJobData.electricalBoxesFixed
    if totalTasksCompleted >= 5 then
        bonusPayment = math.floor(electricianJobData.totalEarned * 0.1) -- 10% bonus for 5+ tasks
    end
    
    local totalPayout = electricianJobData.totalEarned + bonusPayment
    
    -- Give final paycheck (base earnings + bonus)
    local Player = GetPlayer(source)
    if Player then
        Player.Functions.AddMoney('cash', totalPayout)
        -- Update cash_earned stat with total amount
        UpdateStats(identifier, "electrician", "cash_earned", totalPayout)
    end
    
    -- Prepare electrician job summary
    local electricianJobSummary = {
        lightPolesFixed = electricianJobData.lightPolesFixed,
        electricalBoxesFixed = electricianJobData.electricalBoxesFixed,
        totalEarned = electricianJobData.totalEarned,
        bonusPayment = bonusPayment,
        workTime = workTime
    }
    
    -- Clean up active electrician job
    activeElectricianJobs[identifier] = nil
    
    return true, electricianJobSummary
end)

--- Callback to check if player has an active electrician job
--- @param source number Player source ID
--- @return boolean hasActiveJob Whether the player has an active electrician job
lib.callback.register('sd-civilianjobs:server:hasActiveElectricianJob', function(source)
    local identifier = GetIdentifier(source)
    if not identifier then return false end
    
    return activeElectricianJobs[identifier] ~= nil
end)

--- Callback to retrieve electrician job statistics
--- @param source number Player source ID
--- @return table electricianStats Raw electrician statistics from database
lib.callback.register('sd-civilianjobs:server:getElectricianStats', function(source)
    local identifier = GetIdentifier(source)
    if not identifier then return {} end
    
    for _, record in ipairs(levelData) do
        if record.Identifier == identifier then
            local playerStats = json.decode(record.Stats) or {}
            return playerStats.electrician or {}
        end
    end
    
    return {} -- Return empty table if player not found
end)

-- [[ Welding Torch Export ]]

--- Export to use welding torch item
--- @param source number Player source ID
--- @return boolean success Whether the welding torch was used successfully
exports('useWeldingTorch', function(source)
    if not source then return false end
    
    -- Trigger client event to activate welding torch
    TriggerClientEvent('sd-civilianjobs:client:useWeldingTorch', source)
    return true
end)