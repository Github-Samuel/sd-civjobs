local config = require('configs/main')
local divingConfig = require('configs/diving')

-- Variables to track active diving jobs
local activeDivingJobs = {}
local rentedBoats = {} -- Track rented boats by identifier

--- Callback to start a diving job session
--- @param source number Player source ID
--- @return boolean success Whether the job was started successfully
--- @return string message Status message for the player
lib.callback.register('sd-civilianjobs:server:startDivingJob', function(source)
    local identifier = GetIdentifier(source)
    if not identifier then return false, "Failed to get player identifier" end
    
    -- Check if player already has an active diving job
    if activeDivingJobs[identifier] then
        return false, "You already have an active diving job!"
    end
    
    -- Initialize diving job tracking
    activeDivingJobs[identifier] = {
        source = source,
        startTime = os.time(),
        treasuresFound = 0,
        totalEarned = 0,
        currentLocationIndex = 1,
        completedLocations = {}
    }
    
    return true, "Diving job started! Check your map for diving locations. Come back to me when you want to finish your shift."
end)

--- Callback to complete a diving treasure find task
--- @param source number Player source ID
--- @return boolean success Whether the task was completed successfully
--- @return number cashReward Amount of cash added to paycheck
lib.callback.register('sd-civilianjobs:server:completeDivingTask', function(source)
    local identifier = GetIdentifier(source)
    if not identifier or not activeDivingJobs[identifier] then return false, 0 end
    
    local divingJobData = activeDivingJobs[identifier]
    
    -- Get player level to determine reward
    local playerLevel = GetPlayerLevel(identifier, "diving")
    local rewardConfig = divingConfig.Rewards[playerLevel] or divingConfig.Rewards[1]
    local cashReward = math.random(rewardConfig.min, rewardConfig.max)
    
    -- Don't give money immediately, just accumulate for final paycheck
    divingJobData.totalEarned = divingJobData.totalEarned + cashReward
    
    -- Ensure player entry exists before updating stats
    EnsurePlayerEntry(identifier)
    
    -- Update diving job tracking and stats
    divingJobData.treasuresFound = divingJobData.treasuresFound + 1
    UpdateStats(identifier, "diving", "treasures_found", 1)
    UpdateStats(identifier, "diving", "successes", 1)
    
    -- Award base XP for successful treasure find
    AwardXP(identifier, "diving", divingConfig.BaseXP)
    
    print("^2[Civilian Jobs] Diving treasure found for " .. identifier .. ": $" .. cashReward .. " added to paycheck^0")
    
    return true, cashReward
end)

--- Callback to end diving job session and process final paycheck
--- @param source number Player source ID
--- @return boolean success Whether the job was ended successfully
--- @return table summary Job completion summary with earnings and stats
lib.callback.register('sd-civilianjobs:server:endDivingJob', function(source)
    local identifier = GetIdentifier(source)
    if not identifier or not activeDivingJobs[identifier] then return false end
    
    local divingJobData = activeDivingJobs[identifier]
    local workTime = os.time() - divingJobData.startTime
    
    local totalPayout = divingJobData.totalEarned
    
    -- Give final paycheck
    local Player = GetPlayer(source)
    if Player then
        Player.Functions.AddMoney('cash', totalPayout)
        -- Update cash_earned stat with total amount
        UpdateStats(identifier, "diving", "cash_earned", totalPayout)
        
        -- Update locations completed
        local completedCount = 0
        for _ in pairs(divingJobData.completedLocations) do
            completedCount = completedCount + 1
        end
        UpdateStats(identifier, "diving", "locations_completed", completedCount)
    end
    
    local divingJobSummary = {
        treasuresFound = divingJobData.treasuresFound,
        locationsCompleted = completedCount or 0,
        totalEarned = divingJobData.totalEarned,
        workTime = workTime
    }
    
    -- Clean up active diving job
    activeDivingJobs[identifier] = nil
    
    return true, divingJobSummary
end)

--- Callback to check if player has an active diving job
--- @param source number Player source ID
--- @return boolean hasActiveJob Whether the player has an active diving job
lib.callback.register('sd-civilianjobs:server:hasActiveDivingJob', function(source)
    local identifier = GetIdentifier(source)
    if not identifier then return false end
    
    return activeDivingJobs[identifier] ~= nil
end)

--- Callback to retrieve diving job statistics
--- @param source number Player source ID
--- @return table divingStats Raw diving statistics from database
lib.callback.register('sd-civilianjobs:server:getDivingStats', function(source)
    local identifier = GetIdentifier(source)
    if not identifier then return {} end
    
    for _, record in ipairs(levelData) do
        if record.Identifier == identifier then
            local playerStats = json.decode(record.Stats) or {}
            return playerStats.diving or {}
        end
    end
    
    return {} -- Return empty table if player not found
end)

--- Callback to handle boat rental with deposit system
--- @param source number Player source ID
--- @return boolean success Whether the boat was rented successfully
--- @return string message Status message for the player
lib.callback.register('sd-civilianjobs:server:rentDivingBoat', function(source)
    local identifier = GetIdentifier(source)
    if not identifier then return false, "Failed to get player identifier" end
    
    local Player = GetPlayer(source)
    if not Player then return false, "Player not found" end
    
    -- Check if player already has a rented boat
    if rentedBoats[identifier] then
        return false, "You already have a rented boat! Return it first."
    end
    
    -- Check if player has enough money for deposit
    local playerCash = Player.PlayerData.money.cash or 0
    if playerCash < divingConfig.Boat.depositAmount then
        return false, "You need $" .. divingConfig.Boat.depositAmount .. " deposit to rent a boat!"
    end
    
    -- Take deposit
    Player.Functions.RemoveMoney('cash', divingConfig.Boat.depositAmount)
    
    -- Track rented boat
    rentedBoats[identifier] = {
        source = source,
        rentTime = os.time(),
        depositPaid = divingConfig.Boat.depositAmount
    }
    
    -- Trigger client event to spawn boat
    TriggerClientEvent('sd-civilianjobs:client:spawnDivingBoat', source)
    
    return true, "Boat rented! $" .. divingConfig.Boat.depositAmount .. " deposit taken. Return the boat to get $" .. divingConfig.Boat.returnAmount .. " back."
end)

--- Callback to handle boat return with partial deposit refund
--- @param source number Player source ID
--- @return boolean success Whether the boat was returned successfully
--- @return string message Status message for the player
lib.callback.register('sd-civilianjobs:server:returnDivingBoat', function(source)
    local identifier = GetIdentifier(source)
    if not identifier then return false, "Failed to get player identifier" end
    
    local Player = GetPlayer(source)
    if not Player then return false, "Player not found" end
    
    -- Check if player has a rented boat
    if not rentedBoats[identifier] then
        return false, "You don't have a rented boat!"
    end
    
    -- Give partial refund
    Player.Functions.AddMoney('cash', divingConfig.Boat.returnAmount)
    
    -- Remove from rented boats tracking
    rentedBoats[identifier] = nil
    
    return true, "Boat returned! $" .. divingConfig.Boat.returnAmount .. " refunded."
end)

--- Event to handle anchor state synchronization
--- @param vehPlate string Vehicle plate
--- @param anchorState boolean Whether anchor is dropped or raised
RegisterNetEvent("sd-civilianjobs:server:syncAnchorState", function(vehPlate, anchorState)
    local source = source
    TriggerClientEvent("sd-civilianjobs:client:updateAnchorState", -1, vehPlate, anchorState)
end)

-- [[ Diving Gear Exports ]]

--- Export to use diving gear item with ox_inventory event system
--- @param event string Event type ('usingItem', 'usedItem', 'buying')
--- @param item table Item data containing metadata
--- @param inventory table Inventory data containing player info
--- @param slot number Slot number of the item
--- @param data table Additional data
--- @return boolean success Whether the diving gear was used successfully
exports('useDivingGear', function(event, item, inventory, slot, data)
    -- Player is attempting to use the item
    if event == 'usingItem' then
        local source = inventory.id
        if not source then return false end
        
        -- Determine gear tier from item name
        local gearTier = 1 -- Default to tier 1
        if item and item.name then
            local tierMatch = string.match(item.name, "diving_gear_(%d+)")
            if tierMatch then
                gearTier = tonumber(tierMatch) or 1
            end
        end
        
        -- Get oxygen level from config based on tier
        local tierData = divingConfig.ScubaTiers[gearTier]
        local oxygenLevel = tierData and tierData.oxygenLevel or divingConfig.Scuba.startingOxygenLevel
        
        -- Trigger client event to put on diving suit with specific oxygen level
        TriggerClientEvent('sd-civilianjobs:client:useDivingGear', source, oxygenLevel)
        
        -- Return true to allow the item to be consumed/used
        return true
    end
    
    -- Player has finished using the item
    if event == 'usedItem' then
        local source = inventory.id
        local tierName = "Basic Scuba Gear"
        
        -- Get tier name for notification
        if item and item.name then
            local tierMatch = string.match(item.name, "diving_gear_(%d+)")
            if tierMatch then
                local gearTier = tonumber(tierMatch) or 1
                local tierData = divingConfig.ScubaTiers[gearTier]
                tierName = tierData and tierData.name or "Basic Scuba Gear"
            end
        end
        
        return TriggerClientEvent('ox_lib:notify', source, {
            type = 'success',
            description = 'You equipped your ' .. tierName .. ' and are ready to dive!'
        })
    end
    
    -- Player is attempting to purchase the item
    if event == 'buying' then
        local source = inventory.id
        return TriggerClientEvent('ox_lib:notify', source, {
            type = 'success',
            description = 'You purchased diving gear'
        })
    end
end)

--- Export to use diving oxygen refill item with ox_inventory event system
--- @param event string Event type ('usingItem', 'usedItem', 'buying')
--- @param item table Item data containing metadata
--- @param inventory table Inventory data containing player info
--- @param slot number Slot number of the item
--- @param data table Additional data
--- @return boolean success Whether the oxygen refill was used successfully
exports('useDivingFill', function(event, item, inventory, slot, data)
    -- Player is attempting to use the item
    if event == 'usingItem' then
        local source = inventory.id
        if not source then return false end
        
        -- Trigger client event to refill oxygen tank
        TriggerClientEvent('sd-civilianjobs:client:useDivingFill', source)
        
        -- Return true to allow the item to be consumed/used
        return true
    end
    
    -- Player has finished using the item
    if event == 'usedItem' then
        local source = inventory.id
        return TriggerClientEvent('ox_lib:notify', source, {
            type = 'success',
            description = 'Your oxygen tank has been refilled and is ready for diving!'
        })
    end
    
    -- Player is attempting to purchase the item
    if event == 'buying' then
        local source = inventory.id
        return TriggerClientEvent('ox_lib:notify', source, {
            type = 'success',
            description = 'You purchased an oxygen refill'
        })
    end
end)

--- Callback to purchase gear items from the diving shop
--- @param source number Player source ID
--- @param itemType string|number Type of item to purchase (tier index for gear or 'diving_fill')
--- @param quantity number Quantity to purchase
--- @param totalCost number Total cost of the purchase
--- @return boolean success Whether the purchase was successful
--- @return string message Status message for the player
lib.callback.register('sd-civilianjobs:server:purchaseGearItem', function(source, itemType, quantity, totalCost)
    local Player = GetPlayer(source)
    if not Player then return false, "Player not found" end
    
    local identifier = GetIdentifier(source)
    local playerLevel = GetPlayerLevel(identifier, "diving") -- Get player's diving level
    
    -- Validate quantity is reasonable
    if not quantity or quantity < 1 or quantity > 99 then
        return false, "Invalid quantity. Must be between 1 and 99"
    end
    
    local itemToGive = nil
    local expectedPrice = 0
    local purchaseMessage = ""
    
    if itemType == 'diving_fill' then
        local refillPrice = 50
        if totalCost ~= (quantity * refillPrice) then
            return false, "Price mismatch detected for oxygen refill"
        end
        itemToGive = 'diving_fill'
        expectedPrice = quantity * refillPrice
    else
        -- Handle scuba gear tiers
        local tierIndex = tonumber(itemType)
        if not tierIndex or tierIndex < 1 or tierIndex > 5 then
            return false, "Invalid scuba gear tier"
        end
        
        local tierData = divingConfig.ScubaTiers[tierIndex]
        if not tierData then
            return false, "Invalid scuba gear tier configuration"
        end
        
        -- Validate player level
        if playerLevel < tierData.levelRequired then
            return false, "Your diving level is too low for this gear. Requires level " .. tierData.levelRequired
        end
        
        -- Validate total cost matches expected price for the tier
        if totalCost ~= (quantity * tierData.price) then
            return false, "Price mismatch detected for scuba gear tier"
        end
        
        -- Use specific item name for each tier
        itemToGive = 'diving_gear_' .. tierIndex
        expectedPrice = quantity * tierData.price
    end
    
    -- Check if player is near the diving ped
    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    local pedCoords = divingConfig.Ped.coords
    local distance = #(playerCoords - pedCoords)
    
    if distance > 10.0 then -- Allow 10 unit radius around the ped
        return false, "You must be near the diving instructor to purchase items"
    end
    
    -- Check if player has enough money
    local playerCash = Player.PlayerData.money.cash or 0
    if playerCash < expectedPrice then
        return false, "You need $" .. expectedPrice .. " to make this purchase!"
    end
    
    -- Check if item exists in ox_inventory
    local itemData = exports.ox_inventory:Items(itemToGive)
    if not itemData then
        return false, "Item '" .. itemToGive .. "' not found in inventory system"
    end
    
    -- Remove money and add items
    Player.Functions.RemoveMoney('cash', expectedPrice)
    Player.Functions.AddItem(itemToGive, quantity)
    
    -- Create purchase message
    if itemType == 'diving_fill' then
        purchaseMessage = "Purchased " .. quantity .. "x " .. itemData.label .. " for $" .. expectedPrice
    else
        local tierData = divingConfig.ScubaTiers[tonumber(itemType)]
        purchaseMessage = "Purchased " .. quantity .. "x " .. tierData.name .. " for $" .. expectedPrice
    end
    
    -- Trigger inventory notification
    TriggerClientEvent('inventory:client:ItemBox', source, itemData, "add", quantity)
    
    print("^2[Civilian Jobs] " .. GetFullName(source) .. " " .. purchaseMessage .. "^0")
    
    return true, purchaseMessage
end)