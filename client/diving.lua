local divingConfig = require('configs/diving')
local mainConfig = require('configs/main')

-- Diving ped variables
local divingBlip = nil
local divingPedSpawnDistance = 100.0

-- Diving job variables
local isDivingJobActive = false
local currentDivingJobBlip = nil
local currentDivingJobTarget = nil
local currentDivingLocation = nil
local currentTreasureSpots = {}

local cachedPlayerLevel = 1 -- Cache player level to avoid repeated callbacks
local rentedBoat = nil

-- Scuba gear variables
local currentGear = {
    mask = 0,
    tank = 0,
    enabled = false
}
local oxygenLevel = 0
local maxOxygenLevel = 0 -- Track maximum oxygen level for percentage calculation

--- Creates diving blip on resource start for permanent visibility
CreateThread(function()
    if divingConfig.Blip and divingConfig.Blip.enable then
        local divingPedCoords = divingConfig.Ped.coords
        divingBlip = AddBlipForCoord(divingPedCoords.x, divingPedCoords.y, divingPedCoords.z)
        SetBlipSprite(divingBlip, divingConfig.Blip.sprite)
        SetBlipDisplay(divingBlip, divingConfig.Blip.display)
        SetBlipScale(divingBlip, divingConfig.Blip.scale)
        SetBlipColour(divingBlip, divingConfig.Blip.colour)
        SetBlipAsShortRange(divingBlip, false) -- Make it always visible
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(divingConfig.Blip.name)
        EndTextCommandSetBlipName(divingBlip)
        
        print("^2[Civilian Jobs] Diving blip created^0")
    end
end)

--- Function to display diving job statistics menu
--- Shows player's diving work history and performance metrics
local ShowDivingStats = function()
    lib.callback('sd-civilianjobs:server:getDivingStats', false, function(divingStats)
        if divingStats then
            local divingStatsOptions = {
                {
                    title = 'Cash Earned',
                    description = '$' .. (divingStats.cash_earned or 0) .. ' total earned',
                    icon = 'fas fa-dollar-sign',
                    readOnly = true
                },
                {
                    title = 'Treasures Found',
                    description = (divingStats.treasures_found or 0) .. ' treasures recovered',
                    icon = 'fas fa-gem',
                    readOnly = true
                },
                {
                    title = 'Locations Completed',
                    description = (divingStats.locations_completed or 0) .. ' diving sites explored',
                    icon = 'fas fa-map-marker-alt',
                    readOnly = true
                },
                {
                    title = 'Back',
                    description = 'Return to main menu',
                    icon = 'fas fa-arrow-left',
                    onSelect = function()
                        OpenDivingMenu()
                    end
                }
            }
            
            lib.registerContext({
                id = 'diving_stats_menu',
                title = 'Diving Statistics',
                menu = 'diving_main_menu',
                options = divingStatsOptions
            })
            lib.showContext('diving_stats_menu')
        else
            ShowNotification('Failed to load diving statistics', 'error')
        end
    end)
end

--- Function to enable scuba gear functionality
local EnableScuba = function()
    SetEnableScuba(cache.ped, true)
    SetPedMaxTimeUnderwater(cache.ped, 2000.00)
end

--- Function to disable scuba gear functionality
local DisableScuba = function()
    SetEnableScuba(cache.ped, false)
    SetPedMaxTimeUnderwater(cache.ped, 1.00)
end

--- Function to delete scuba gear props
local DeleteGear = function()
    if currentGear.mask ~= 0 then
        DetachEntity(currentGear.mask, false, true)
        DeleteEntity(currentGear.mask)
        currentGear.mask = 0
    end

    if currentGear.tank ~= 0 then
        DetachEntity(currentGear.tank, false, true)
        DeleteEntity(currentGear.tank)
        currentGear.tank = 0
    end
end

--- Function to attach scuba gear props to player
local AttachGear = function()
    local maskModel = `p_d_scuba_mask_s`
    local tankModel = `p_s_scuba_tank_s`
    lib.requestModel(maskModel)
    lib.requestModel(tankModel)

    currentGear.tank = CreateObject(tankModel, 1.0, 1.0, 1.0, true, true, false)
    local bone1 = GetPedBoneIndex(cache.ped, 24818)
    AttachEntityToEntity(currentGear.tank, cache.ped, bone1, -0.25, -0.25, 0.0, 180.0, 90.0, 0.0, true, true, false, false, 2, true)

    currentGear.mask = CreateObject(maskModel, 1.0, 1.0, 1.0, true, true, false)
    local bone2 = GetPedBoneIndex(cache.ped, 12844)
    AttachEntityToEntity(currentGear.mask, cache.ped, bone2, 0.0, 0.0, 0.0, 180.0, 90.0, 0.0, true, true, false, false, 2, true)
end

--- Function to start oxygen level display thread
local StartOxygenLevelDrawTextThread = function()
    CreateThread(function()
        while currentGear.enabled do
            if IsPedSwimmingUnderWater(cache.ped) then
                -- Calculate oxygen percentage
                local oxygenPercentage = maxOxygenLevel > 0 and math.floor((oxygenLevel / maxOxygenLevel) * 100) or 0
                
                -- Get current depth (negative Z coordinate relative to water surface)
                local playerCoords = GetEntityCoords(cache.ped)
                local waterLevel = GetWaterHeight(playerCoords.x, playerCoords.y, playerCoords.z)
                local currentDepth = math.max(0, math.floor(waterLevel - playerCoords.z))
                
                -- Create display text with oxygen percentage and depth
                local displayText = string.format("🫁 Oxygen: %d%%\n🌊 Depth: %dm", 
                    oxygenPercentage, 
                    currentDepth
                )
                
                lib.showTextUI(displayText, {
                    position = "left-center",
                })
            else
                lib.hideTextUI()
            end
            Wait(100) -- Update every 100ms for smoother display
        end
        lib.hideTextUI() -- Ensure UI is hidden when gear is disabled
    end)
end

--- Function to start oxygen level decrementer thread
local StartOxygenLevelDecrementerThread = function()
    CreateThread(function()
        while currentGear.enabled do
            if IsPedSwimmingUnderWater(cache.ped) and oxygenLevel > 0 then
                oxygenLevel -= 1
                if oxygenLevel == 30 then
                    ShowNotification('You have 30 seconds of oxygen left!', 'error')
                end
                if oxygenLevel == 0 then
                    DisableScuba()
                    ShowNotification('You ran out of Oxygen! Get to the surface now!', 'error')
                end
            end
            Wait(1000)
        end
    end)
end

--- Function to put on diving suit
local PutOnSuit = function()
    if oxygenLevel <= 0 then
        ShowNotification('You need to refill your oxygen! Get a replacement air supply!', 'error')
        return
    end

    if IsPedSwimming(cache.ped) or cache.vehicle then
        ShowNotification('You need to be on solid ground to put this on.', 'error')
        return
    end

    if lib.progressBar({
        duration = divingConfig.Scuba.putOnSuitTimeMs,
        label = 'Putting on your diving suit...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = false,
            combat = true
        },
        anim = {
            dict = 'clothingshirt',
            clip = 'try_shirt_positive_d'
        }
    }) then
        DeleteGear()
        AttachGear()
        EnableScuba()
        currentGear.enabled = true
        StartOxygenLevelDecrementerThread()
        StartOxygenLevelDrawTextThread()
        ShowNotification('Diving suit equipped! You can now dive underwater safely.', 'success')
    else
        ShowNotification('Putting on diving suit cancelled', 'error')
    end
end

--- Function to take off diving suit
local TakeOffSuit = function()
    if lib.progressBar({
        duration = divingConfig.Scuba.takeOffSuitTimeMs,
        label = 'Taking off your diving suit...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = false,
            combat = true
        },
        anim = {
            dict = 'clothingshirt',
            clip = 'try_shirt_positive_d'
        }
    }) then
        SetEnableScuba(cache.ped, false)
        SetPedMaxTimeUnderwater(cache.ped, 50.00)
        currentGear.enabled = false
        DeleteGear()
        lib.hideTextUI()
        ShowNotification('You took your diving gear off', 'success')
    else
        ShowNotification('Taking off diving suit cancelled', 'error')
    end
end

--- Function to refill oxygen tank
local RefillTank = function()
    if IsPedSwimmingUnderWater(cache.ped) then
        ShowNotification('Cannot do this underwater', 'error')
        return
    end

    if lib.progressBar({
        duration = divingConfig.Scuba.refillTankTimeMs,
        label = 'Filling air tank...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = false,
            move = false,
            combat = true
        },
        anim = {
            dict = 'clothingshirt',
            clip = 'try_shirt_positive_d'
        }
    }) then
        oxygenLevel = maxOxygenLevel > 0 and maxOxygenLevel or divingConfig.Scuba.startingOxygenLevel
        ShowNotification("You've successfully refilled your air tank!", "success")
        if currentGear.enabled then
            EnableScuba()
        end
    else
        ShowNotification("Refilling air tank canceled", "error")
    end
end

--- Function to create diving job blip for diving locations
--- @param divingLocationData table Data for the diving location
local CreateDivingJobBlip = function(divingLocationData)
    if currentDivingJobBlip then
        if currentDivingJobBlip.point and DoesBlipExist(currentDivingJobBlip.point) then
            RemoveBlip(currentDivingJobBlip.point)
        end
        if currentDivingJobBlip.radius and DoesBlipExist(currentDivingJobBlip.radius) then
            RemoveBlip(currentDivingJobBlip.radius)
        end
    end
    
    -- Calculate dynamic radius based on treasure spot locations
    local maxDistance = 0.0
    local centerCoords = divingLocationData.coords
    
    for _, treasureSpot in ipairs(divingLocationData.treasureSpots) do
        local distance = #(centerCoords - treasureSpot)
        if distance > maxDistance then
            maxDistance = distance
        end
    end
    
    -- Add some padding to ensure all treasure spots are within the radius
    local dynamicRadius = maxDistance + 25.0
    
    -- Create main diving location blip (point)
    local divingBlip = AddBlipForCoord(divingLocationData.coords.x, divingLocationData.coords.y, divingLocationData.coords.z)
    SetBlipSprite(divingBlip, 404) -- Diving icon
    SetBlipColour(divingBlip, 3) -- Light blue color
    SetBlipDisplay(divingBlip, 4)
    SetBlipScale(divingBlip, 0.8)
    SetBlipAsShortRange(divingBlip, false)
    SetBlipRoute(divingBlip, true)
    SetBlipRouteColour(divingBlip, 3) -- Match the blip color
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Diving Location: " .. divingLocationData.name)
    EndTextCommandSetBlipName(divingBlip)
    
    -- Create radius blip around diving location to show treasure area
    local radiusBlip = AddBlipForRadius(divingLocationData.coords.x, divingLocationData.coords.y, divingLocationData.coords.z, dynamicRadius)
    SetBlipColour(radiusBlip, 3) -- Light blue color
    SetBlipAlpha(radiusBlip, 80) -- Semi-transparent
    
    -- Store both blips
    currentDivingJobBlip = {
        point = divingBlip,
        radius = radiusBlip
    }
end

--- Function to get random diving location
--- @return table randomDivingLocation Random diving location data
local GetRandomDivingLocation = function()
    return divingConfig.DivingLocations[math.random(#divingConfig.DivingLocations)]
end

--- Function to create treasure spot targets for diving
--- @param treasureSpots table Array of treasure spot coordinates
local CreateTreasureSpotTargets = function(treasureSpots)
    -- Clear existing targets
    if currentDivingJobTarget then
        for _, target in ipairs(currentDivingJobTarget) do
            exports.ox_target:removeZone(target)
        end
    end
    
    currentDivingJobTarget = {}
    
    for i, spot in ipairs(treasureSpots) do
        local treasureTarget = exports.ox_target:addSphereZone({
            coords = spot,
            radius = 3.0,
            options = {
                {
                    name = 'search_treasure_' .. i,
                    icon = 'fas fa-gem',
                    label = 'Search for Treasure',
                    onSelect = function()
                        SearchForTreasure(spot, i)
                    end
                }
            }
        })
        table.insert(currentDivingJobTarget, treasureTarget)
    end
end

--- Function to handle treasure searching at diving locations
--- @param treasureCoords vector3 Coordinates of the treasure spot
--- @param spotIndex number Index of the treasure spot
SearchForTreasure = function(treasureCoords, spotIndex)
    local playerPed = PlayerPedId()
    
    -- Check if player is underwater
    if not IsPedSwimmingUnderWater(playerPed) then
        ShowNotification('You need to be underwater to search for treasure!', 'error')
        return
    end
    
    TaskStartScenarioAtPosition(playerPed, 'WORLD_HUMAN_WELDING', treasureCoords.x, treasureCoords.y, treasureCoords.z, GetEntityHeading(playerPed), 8000, 0, 1)
    
    if lib.progressBar({
        duration = 8000,
        label = 'Searching for treasure...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        }
    }) then
        ClearPedTasksImmediately(playerPed)
        
        lib.callback('sd-civilianjobs:server:completeDivingTask', false, function(treasureFound, cashReward)
            if treasureFound then
                ShowNotification('Treasure found! $' .. cashReward .. ' added to your paycheck.', 'success')
                
                -- Remove this treasure spot target
                if currentDivingJobTarget and currentDivingJobTarget[spotIndex] then
                    exports.ox_target:removeZone(currentDivingJobTarget[spotIndex])
                    currentDivingJobTarget[spotIndex] = nil
                end
                
                -- Check if all treasure spots are completed
                local remainingSpots = 0
                for _, target in ipairs(currentDivingJobTarget) do
                    if target then
                        remainingSpots = remainingSpots + 1
                    end
                end
                
                if remainingSpots == 0 then
                    ShowNotification('All treasures found at this location! Check your map for the next diving site.', 'success')
                    
                    -- Clean up current location
                    if currentDivingJobBlip then
                        if currentDivingJobBlip.point and DoesBlipExist(currentDivingJobBlip.point) then
                            RemoveBlip(currentDivingJobBlip.point)
                        end
                        if currentDivingJobBlip.radius and DoesBlipExist(currentDivingJobBlip.radius) then
                            RemoveBlip(currentDivingJobBlip.radius)
                        end
                        currentDivingJobBlip = nil
                    end
                    
                    Wait(2000)
                    -- Get next diving location
                    local nextDivingLocation = GetRandomDivingLocation()
                    currentDivingLocation = nextDivingLocation
                    currentTreasureSpots = nextDivingLocation.treasureSpots
                    
                    CreateDivingJobBlip(nextDivingLocation)
                    CreateTreasureSpotTargets(nextDivingLocation.treasureSpots)
                end
            else
                ShowNotification('Failed to find treasure', 'error')
            end
        end)
    else
        ClearPedTasksImmediately(playerPed)
        ShowNotification('Treasure search cancelled', 'error')
    end
end

--- Function to start diving job session
--- Initializes diving work and creates first diving location
local StartDivingJob = function()
    lib.callback('sd-civilianjobs:server:startDivingJob', false, function(divingJobStarted, divingJobMessage)
        if divingJobStarted then
            isDivingJobActive = true
            ShowNotification(divingJobMessage, 'success')
            
            -- Cache player level when job starts to avoid repeated callbacks
            lib.callback('sd-civilianjobs:server:getPlayerInfo', false, function(data)
                cachedPlayerLevel = (data and data.level) or 1
                
                -- Initialize oxygen level
                oxygenLevel = divingConfig.Scuba.startingOxygenLevel
                maxOxygenLevel = divingConfig.Scuba.startingOxygenLevel
                
                local firstDivingLocation = GetRandomDivingLocation()
                currentDivingLocation = firstDivingLocation
                currentTreasureSpots = firstDivingLocation.treasureSpots
                
                CreateDivingJobBlip(firstDivingLocation)
                CreateTreasureSpotTargets(firstDivingLocation.treasureSpots)
            end, 'diving')
        else
            ShowNotification(divingJobMessage, 'error')
        end
    end)
end

--- Function to end diving job session and process final paycheck
--- Cleans up active job elements and displays earnings summary
local EndDivingJob = function()
    lib.callback('sd-civilianjobs:server:endDivingJob', false, function(divingJobEnded, divingJobSummary)
        if divingJobEnded then
            isDivingJobActive = false
            
            -- Clean up diving job elements
            if currentDivingJobBlip then
                if currentDivingJobBlip.point and DoesBlipExist(currentDivingJobBlip.point) then
                    RemoveBlip(currentDivingJobBlip.point)
                end
                if currentDivingJobBlip.radius and DoesBlipExist(currentDivingJobBlip.radius) then
                    RemoveBlip(currentDivingJobBlip.radius)
                end
                currentDivingJobBlip = nil
            end
            if currentDivingJobTarget then
                for _, target in ipairs(currentDivingJobTarget) do
                    if target then
                        exports.ox_target:removeZone(target)
                    end
                end
                currentDivingJobTarget = nil
            end
            
            -- Take off diving gear if equipped
            if currentGear.enabled then
                TakeOffSuit()
            end
            
            local divingWorkTimeMinutes = math.floor(divingJobSummary.workTime / 60)
            local divingTotalPayout = divingJobSummary.totalEarned
            
            lib.registerContext({
                id = 'diving_job_summary',
                title = 'Diving Job Complete - Final Paycheck',
                options = {
                    {
                        title = 'Work Summary',
                        description = 'Your diving work session results',
                        icon = 'fas fa-clipboard-check',
                        readOnly = true
                    },
                    {
                        title = 'Treasures Found',
                        description = divingJobSummary.treasuresFound .. ' treasures recovered',
                        icon = 'fas fa-gem',
                        readOnly = true
                    },
                    {
                        title = 'Locations Completed',
                        description = divingJobSummary.locationsCompleted .. ' diving sites explored',
                        icon = 'fas fa-map-marker-alt',
                        readOnly = true
                    },
                    {
                        title = 'Work Time',
                        description = divingWorkTimeMinutes .. ' minutes worked',
                        icon = 'fas fa-clock',
                        readOnly = true
                    },
                    {
                        title = 'Total Payout',
                        description = '$' .. divingTotalPayout .. ' total earned',
                        icon = 'fas fa-money-bill-wave',
                        readOnly = true
                    }
                }
            })
            lib.showContext('diving_job_summary')
            
            ShowNotification('Diving job completed! Total earned: $' .. divingTotalPayout, 'success')
        else
            ShowNotification('Failed to end diving job', 'error')
        end
    end)
end

--- Function to rent diving boat
local RentDivingBoat = function()
    lib.callback('sd-civilianjobs:server:rentDivingBoat', false, function(boatRented, message)
        if boatRented then
            ShowNotification(message, 'success')
        else
            ShowNotification(message, 'error')
        end
    end)
end

--- Function to return diving boat
local ReturnDivingBoat = function()
    if rentedBoat and DoesEntityExist(rentedBoat) then
        lib.callback('sd-civilianjobs:server:returnDivingBoat', false, function(boatReturned, message)
            if boatReturned then
                DeleteVehicle(rentedBoat)
                rentedBoat = nil
                ShowNotification(message, 'success')
            else
                ShowNotification(message, 'error')
            end
        end)
    else
        ShowNotification('No boat to return!', 'error')
    end
end

--- Function to open gear shop menu
local OpenGearShop = function()
    -- Get player level to show available gear
    lib.callback('sd-civilianjobs:server:getPlayerInfo', false, function(data)
        local playerLevel = (data and data.level) or 1
        local shopOptions = {}
        
        -- Add all scuba gear tiers from config
        for tierIndex, tierData in ipairs(divingConfig.ScubaTiers) do
            local isAvailable = playerLevel >= tierData.levelRequired
            local statusText = isAvailable and "Available" or ("Requires Level " .. tierData.levelRequired)
            local statusColor = isAvailable and "🟢" or "🔴"
            
            table.insert(shopOptions, {
                title = tierData.name,
                description = statusColor .. " " .. statusText .. " | $" .. tierData.price .. " | " .. tierData.oxygenLevel .. "s oxygen",
                icon = 'fas fa-mask',
                disabled = not isAvailable,
                onSelect = function()
                    if not isAvailable then
                        ShowNotification('You need to be level ' .. tierData.levelRequired .. ' to purchase this gear!', 'error')
                        return
                    end
                    
                    local input = lib.inputDialog('Purchase ' .. tierData.name, {
                        {type = 'number', label = 'Quantity', description = 'How many gear sets?', min = 1, max = 10, default = 1}
                    })
                    
                    if input and input[1] then
                        local quantity = tonumber(input[1])
                        local totalCost = quantity * tierData.price
                        
                        local alert = lib.alertDialog({
                            header = 'Confirm Purchase',
                            content = 'Purchase ' .. quantity .. 'x ' .. tierData.name .. ' for $' .. totalCost .. '?\n\nOxygen Duration: ' .. tierData.oxygenLevel .. ' seconds',
                            centered = true,
                            cancel = true
                        })
                        
                        if alert == 'confirm' then
                            lib.callback('sd-civilianjobs:server:purchaseGearItem', false, function(success, message)
                                if success then
                                    ShowNotification(message, 'success')
                                else
                                    ShowNotification(message, 'error')
                                end
                                OpenGearShop() -- Reopen shop
                            end, tierIndex, quantity, totalCost)
                        else
                            OpenGearShop() -- Reopen shop if cancelled
                        end
                    else
                        OpenGearShop() -- Reopen shop if input cancelled
                    end
                end
            })
        end
        
        -- Add oxygen refill option
        table.insert(shopOptions, {
            title = 'Oxygen Refill',
            description = 'Refill your oxygen tank - $50 each',
            icon = 'fas fa-wind',
            onSelect = function()
                local input = lib.inputDialog('Purchase Oxygen Refills', {
                    {type = 'number', label = 'Quantity', description = 'How many oxygen refills?', min = 1, max = 20, default = 1}
                })
                
                if input and input[1] then
                    local quantity = tonumber(input[1])
                    local totalCost = quantity * 50
                    
                    local alert = lib.alertDialog({
                        header = 'Confirm Purchase',
                        content = 'Purchase ' .. quantity .. ' oxygen refill(s) for $' .. totalCost .. '?',
                        centered = true,
                        cancel = true
                    })
                    
                    if alert == 'confirm' then
                        lib.callback('sd-civilianjobs:server:purchaseGearItem', false, function(success, message)
                            if success then
                                ShowNotification(message, 'success')
                            else
                                ShowNotification(message, 'error')
                            end
                            OpenGearShop() -- Reopen shop
                        end, 'diving_fill', quantity, totalCost)
                    else
                        OpenGearShop() -- Reopen shop if cancelled
                    end
                else
                    OpenGearShop() -- Reopen shop if input cancelled
                end
            end
        })
        
        -- Add back button
        table.insert(shopOptions, {
            title = 'Back',
            description = 'Return to main menu',
            icon = 'fas fa-arrow-left',
            onSelect = function()
                OpenDivingMenu()
            end
        })
        
        lib.registerContext({
            id = 'diving_gear_shop',
            title = 'Diving Gear Shop',
            menu = 'diving_main_menu',
            options = shopOptions
        })
        lib.showContext('diving_gear_shop')
    end, 'diving')
end

--- Main diving menu function
--- Displays diving job options, level progress, and statistics
OpenDivingMenu = function()
    lib.callback('sd-civilianjobs:server:hasActiveDivingJob', false, function(hasActiveDivingJob)
        isDivingJobActive = hasActiveDivingJob
        
        lib.callback('sd-civilianjobs:server:getPlayerInfo', false, function(data)
            local level = 1
            local xp = 0
            local currentLevelXP = 0
            local nextLevelXP = 100
            local progress = 0
            local isMaxLevel = false
            
            if data then
                level = data.level or 1
                xp = data.xp or 0
                
                local divingLevelConfig = mainConfig.Levels.diving or {}
                
                currentLevelXP = divingLevelConfig[level] and divingLevelConfig[level].xpRequired or 0
                
                local nextLevel = level + 1
                nextLevelXP = divingLevelConfig[nextLevel] and divingLevelConfig[nextLevel].xpRequired or currentLevelXP
                
                isMaxLevel = not divingLevelConfig[nextLevel]
                
                if not isMaxLevel and nextLevelXP > currentLevelXP then
                    local xpIntoCurrentLevel = xp - currentLevelXP
                    local xpNeededForNextLevel = nextLevelXP - currentLevelXP
                    progress = math.floor((xpIntoCurrentLevel / xpNeededForNextLevel) * 100)
                    progress = math.max(0, math.min(100, progress))
                else
                    progress = 100
                end
            end
            
            local divingJobOption = {
                title = isDivingJobActive and 'End Job & Get Paycheck' or 'Start Job',
                description = isDivingJobActive and 'Complete your work and receive final payment' or 'Begin a treasure diving job',
                icon = isDivingJobActive and 'fas fa-stop-circle' or 'fas fa-water',
                onSelect = function()
                    if isDivingJobActive then
                        EndDivingJob()
                    else
                        StartDivingJob()
                    end
                end
            }
            
            -- Build menu options dynamically
            local menuOptions = {
                {
                    title = 'Level & Progress',
                    description = isMaxLevel and ('Level: ' .. level .. ' (MAX LEVEL) | Total XP: ' .. xp) or ('Level: ' .. level .. ' | XP: ' .. xp .. ' / ' .. nextLevelXP .. ' | Progress: ' .. progress .. '% to next level'),
                    icon = 'fas fa-chart-line',
                    readOnly = true
                },
                {
                    title = 'Statistics',
                    description = 'View your diving job statistics',
                    icon = 'fas fa-chart-bar',
                    arrow = true,
                    onSelect = function()
                        ShowDivingStats()
                    end
                }
            }
            
            -- Add boat options conditionally
            if rentedBoat and DoesEntityExist(rentedBoat) then
                -- Player has a rented boat, show return option
                table.insert(menuOptions, {
                    title = 'Return Boat',
                    description = 'Return your rented boat (get $' .. divingConfig.Boat.returnAmount .. ' back)',
                    icon = 'fas fa-undo',
                    onSelect = function()
                        ReturnDivingBoat()
                    end
                })
            else
                -- Player doesn't have a rented boat, show rent option
                table.insert(menuOptions, {
                    title = 'Rent Boat',
                    description = 'Rent a boat for diving ($' .. divingConfig.Boat.depositAmount .. ' deposit)',
                    icon = 'fas fa-ship',
                    onSelect = function()
                        RentDivingBoat()
                    end
                })
            end
            
            -- Add gear shop option
            table.insert(menuOptions, {
                title = 'Gear Shop',
                description = 'Purchase diving equipment and supplies',
                icon = 'fas fa-shopping-cart',
                arrow = true,
                onSelect = function()
                    OpenGearShop()
                end
            })
            
            -- Add start job option at the bottom
            table.insert(menuOptions, divingJobOption)
            
            lib.registerContext({
                id = 'diving_main_menu',
                title = 'Diving Services',
                options = menuOptions
            })
            lib.showContext('diving_main_menu')
        end, 'diving')
    end)
end

--- Event handler for spawning diving boat
RegisterNetEvent('sd-civilianjobs:client:spawnDivingBoat', function()
    local spawnCoords = divingConfig.Boat.spawnCoords
    local spawnRadius = 3.0
    local closest = GetClosestVehicle(spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnRadius, 0, 70)

    if DoesEntityExist(closest) then
        ShowNotification('The area is crowded, try again later', 'error')
        return
    end

    local vehicleModel = GetHashKey(divingConfig.Boat.model)
    local myPed = PlayerPedId()

    lib.requestModel(vehicleModel, 5000)

    local plate = "DIVE" .. GetRandomIntInRange(100, 999)
    rentedBoat = CreateVehicle(vehicleModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, false)
    SetVehicleNumberPlateText(rentedBoat, plate)
    SetPedIntoVehicle(myPed, rentedBoat, -1)

    -- Wait for vehicle to fully initialize
    Wait(500)

    TriggerEvent("vehiclekeys:client:SetOwner", GetVehiclePlate(rentedBoat))
    SetVehicleFixed(rentedBoat)
    SetEntityAsMissionEntity(rentedBoat, true, true)
    SetVehicleEngineOn(rentedBoat, true, true)
    SetVehicleDirtLevel(rentedBoat, 0.0)
    
    -- Set fuel with additional delay to ensure ox_fuel compatibility
    CreateThread(function()
        Wait(1000) -- Give ox_fuel time to initialize the vehicle
        SetVehicleFuel(rentedBoat, 100.0)
        
        -- Double-check fuel was set correctly after another short delay
        Wait(500)
        local currentFuel = GetVehicleFuel(rentedBoat)
        if currentFuel < 90.0 then -- If fuel is still low, try setting it again
            print("^3[Civilian Jobs] Boat fuel low (" .. currentFuel .. "%), attempting to refuel...^0")
            SetVehicleFuel(rentedBoat, 100.0)
            
            -- Final check
            Wait(500)
            local finalFuel = GetVehicleFuel(rentedBoat)
            print("^2[Civilian Jobs] Boat fuel set to: " .. finalFuel .. "%^0")
        else
            print("^2[Civilian Jobs] Boat fuel successfully set to: " .. currentFuel .. "%^0")
        end
    end)
end)

-- [[ Diving Gear Item Events ]]

--- Event handler for using diving gear item
RegisterNetEvent('sd-civilianjobs:client:useDivingGear', function(itemData)
    if itemData and itemData.metadata and itemData.metadata.oxygenLevel then
        oxygenLevel = itemData.metadata.oxygenLevel
    else
        oxygenLevel = divingConfig.Scuba.startingOxygenLevel -- Fallback to default if no metadata
    end
    PutOnSuit()
end)

--- Event handler for using diving oxygen refill item
RegisterNetEvent('sd-civilianjobs:client:useDivingFill', function()
    RefillTank()
end)

--- Anchor system for boats
local boatAnchors = {}

--- Function to toggle boat anchor
local ToggleAnchor = function()
    local playerPed = PlayerPedId()
    if not IsPedInAnyBoat(playerPed) then
        ShowNotification("You can only do this while in a boat.", "error")
        return
    end

    local playerVeh = GetVehiclePedIsIn(playerPed, false)
    local vehPlate = GetVehicleNumberPlateText(playerVeh)

    if not boatAnchors[vehPlate] then
        boatAnchors[vehPlate] = false
    end

    if lib.progressBar({
        duration = 5000,
        label = 'Toggling Anchor...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = false,
            move = false,
            combat = true
        }
    }) then
        if CanAnchorBoatHere(playerVeh) then
            local anchorState = not boatAnchors[vehPlate]
            TriggerServerEvent("sd-civilianjobs:server:syncAnchorState", vehPlate, anchorState)
            local notifyMessage = anchorState and "Anchor Dropped!" or "Anchor Raised!"
            ShowNotification(notifyMessage, "success")
        else
            ShowNotification("Unable to anchor here.", "error")
        end
    else
        ShowNotification("Anchor toggling cancelled.", "error")
    end
end

--- Register anchor command
RegisterCommand('anchor', function()
    ToggleAnchor()
end, false)

--- Event handler for anchor state updates
RegisterNetEvent("sd-civilianjobs:client:updateAnchorState", function(vehPlate, anchorState)
    boatAnchors[vehPlate] = anchorState
    local playerVeh = GetVehiclePedIsIn(PlayerPedId(), false)
    if playerVeh and GetVehicleNumberPlateText(playerVeh) == vehPlate then
        SetBoatAnchor(playerVeh, anchorState)
        SetBoatFrozenWhenAnchored(playerVeh, anchorState)
    end
end)

-- Initialize diving ped spawning using shared system
InitializeJobPedSpawning('diving', divingConfig, OpenDivingMenu, divingPedSpawnDistance)

--- Client event to handle diving gear usage with specific oxygen level
--- @param customOxygenLevel number Custom oxygen level for this gear tier
RegisterNetEvent('sd-civilianjobs:client:useDivingGear', function(customOxygenLevel)
    -- Set oxygen level based on gear tier
    if customOxygenLevel and customOxygenLevel > 0 then
        oxygenLevel = customOxygenLevel
        maxOxygenLevel = customOxygenLevel -- Track max oxygen for percentage calculation
    else
        oxygenLevel = divingConfig.Scuba.startingOxygenLevel
        maxOxygenLevel = divingConfig.Scuba.startingOxygenLevel
    end
    
    -- Put on the diving suit
    PutOnSuit()
end)

--- Client event to handle diving oxygen refill usage
RegisterNetEvent('sd-civilianjobs:client:useDivingFill', function()
    RefillTank()
end)