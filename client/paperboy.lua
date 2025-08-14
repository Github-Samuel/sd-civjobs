local paperboyConfig = require('configs/paperboy')
local mainConfig = require('configs/main')

-- Paperboy ped variables
local paperboyBlip = nil
local paperboyPedSpawnDistance = 100.0

-- Paperboy job variables
local isPaperboyJobActive = false
local currentPaperboyJobBlip = nil
local currentPaperboyJobTarget = nil
local currentPaperboyJobLocation = nil
local recentPaperboyLocations = {} -- Track recent locations to avoid repeats
local cachedPlayerLevel = 1 -- Cache player level to avoid repeated callbacks

--- Creates paperboy blip on resource start for permanent visibility
CreateThread(function()
    if paperboyConfig.Blip and paperboyConfig.Blip.enable then
        local paperboyPedCoords = paperboyConfig.Ped.coords
        paperboyBlip = AddBlipForCoord(paperboyPedCoords.x, paperboyPedCoords.y, paperboyPedCoords.z)
        SetBlipSprite(paperboyBlip, paperboyConfig.Blip.sprite)
        SetBlipDisplay(paperboyBlip, paperboyConfig.Blip.display)
        SetBlipScale(paperboyBlip, paperboyConfig.Blip.scale)
        SetBlipColour(paperboyBlip, paperboyConfig.Blip.colour)
        SetBlipAsShortRange(paperboyBlip, false) -- Make it always visible
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(paperboyConfig.Blip.name)
        EndTextCommandSetBlipName(paperboyBlip)
        
        print("^2[Civilian Jobs] Paperboy blip created^0")
    end
end)

--- Function to display paperboy job statistics menu
--- Shows player's paperboy work history and performance metrics
local ShowPaperboyStats = function()
    lib.callback('sd-civilianjobs:server:getJobTypeStats', false, function(paperboyStatsData)
        if paperboyStatsData then
            local paperboyGeneralStats = paperboyStatsData.general or {}
            local paperboyStatsOptions = {
                {
                    title = 'Cash Earned',
                    description = '$' .. (paperboyGeneralStats.cash_earned or 0) .. ' total earned',
                    icon = 'fas fa-dollar-sign',
                    readOnly = true
                },
                {
                    title = 'Newspapers Delivered',
                    description = (paperboyGeneralStats.newspapers_delivered or 0) .. ' newspapers delivered',
                    icon = 'fas fa-newspaper',
                    readOnly = true
                },
                {
                    title = 'Routes Completed',
                    description = (paperboyGeneralStats.routes_completed or 0) .. ' delivery routes completed',
                    icon = 'fas fa-route',
                    readOnly = true
                },
                {
                    title = 'Back',
                    description = 'Return to main menu',
                    icon = 'fas fa-arrow-left',
                    onSelect = function()
                        OpenPaperboyMenu()
                    end
                }
            }
            
            lib.registerContext({
                id = 'paperboy_stats_menu',
                title = 'Paperboy Statistics',
                menu = 'paperboy_main_menu',
                options = paperboyStatsOptions
            })
            lib.showContext('paperboy_stats_menu')
        else
            ShowNotification('Failed to load paperboy statistics', 'error')
        end
    end, 'paperboy')
end

-- Function to create paperboy job blip for delivery locations
--- @param paperboyJobCoords vector3 Coordinates for the delivery location
local CreatePaperboyJobBlip = function(paperboyJobCoords)
    if currentPaperboyJobBlip then
        RemoveBlip(currentPaperboyJobBlip)
    end
    
    currentPaperboyJobBlip = AddBlipForCoord(paperboyJobCoords.x, paperboyJobCoords.y, paperboyJobCoords.z)
    SetBlipSprite(currentPaperboyJobBlip, 40) -- Delivery icon
    SetBlipColour(currentPaperboyJobBlip, 61) -- Light blue
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Newspaper Delivery")
    EndTextCommandSetBlipName(currentPaperboyJobBlip)
    
    SetBlipDisplay(currentPaperboyJobBlip, 4)
    SetBlipScale(currentPaperboyJobBlip, 0.8)
    SetBlipAsShortRange(currentPaperboyJobBlip, false)
    SetBlipRoute(currentPaperboyJobBlip, true)
    SetBlipRouteColour(currentPaperboyJobBlip, 3)
end

--- Function to check if location was recently used
--- @param location vector3 Location to check
--- @return boolean wasRecentlyUsed Whether the location was recently used
local IsLocationRecentlyUsed = function(location)
    for _, recentLocation in ipairs(recentPaperboyLocations) do
        if #(location - recentLocation) < 5.0 then -- Within 5 units is considered same location
            return true
        end
    end
    return false
end

--- Function to add location to recent locations list
--- @param location vector3 Location to add to recent list
local AddToRecentLocations = function(location)
    table.insert(recentPaperboyLocations, location)
    
    -- Keep only the last 4-5 locations
    if #recentPaperboyLocations > 5 then
        table.remove(recentPaperboyLocations, 1) -- Remove oldest location
    end
end

--- Function to get random paperboy delivery location within distance constraints
--- @return vector3 randomPaperboyLocation Random coordinates for delivery work within distance range
local GetRandomPaperboyLocation = function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local paperboyDeliveryLocations = paperboyConfig.JobLocations.deliveryPoints
    
    -- Filter locations by distance and exclude recent locations
    local validPaperboyLocations = {}
    for _, location in ipairs(paperboyDeliveryLocations) do
        local distance = #(playerCoords - location)
        if distance >= paperboyConfig.Distance.min and distance <= paperboyConfig.Distance.max then
            if not IsLocationRecentlyUsed(location) then
                table.insert(validPaperboyLocations, location)
            end
        end
    end
    
    -- If no valid locations found within distance range (excluding recent), try with recent locations included
    if #validPaperboyLocations == 0 then
        for _, location in ipairs(paperboyDeliveryLocations) do
            local distance = #(playerCoords - location)
            if distance >= paperboyConfig.Distance.min and distance <= paperboyConfig.Distance.max then
                table.insert(validPaperboyLocations, location)
            end
        end
        print("^3[Civilian Jobs] No new paperboy locations found within distance range, including recent locations^0")
    end
    
    -- If still no valid locations, use random location from all available
    if #validPaperboyLocations == 0 then
        validPaperboyLocations = paperboyDeliveryLocations
        print("^3[Civilian Jobs] No paperboy locations found within distance range, using random location^0")
    end
    
    local randomPaperboyLocation = validPaperboyLocations[math.random(#validPaperboyLocations)]
    
    -- Add this location to recent locations list
    AddToRecentLocations(randomPaperboyLocation)
    
    return randomPaperboyLocation
end

--- Function to create paperboy job target for delivery interactions
--- @param paperboyJobCoords vector3 Coordinates for the delivery target
local CreatePaperboyJobTarget = function(paperboyJobCoords)
    if currentPaperboyJobTarget then
        exports.ox_target:removeZone(currentPaperboyJobTarget)
    end
    
    local paperboyTargetOptions = {
        {
            name = 'deliver_newspaper',
            icon = 'fas fa-newspaper',
            label = 'Deliver Newspaper',
            onSelect = function()
                DeliverNewspaper()
            end
        }
    }
    
    currentPaperboyJobTarget = exports.ox_target:addSphereZone({
        coords = paperboyJobCoords,
        radius = 2.0,
        options = paperboyTargetOptions
    })
end

--- Function to handle newspaper delivery work
local DeliverNewspaper = function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local deliveryTargetCoords = currentPaperboyJobLocation
    
    local minigameSuccess = true
    if paperboyConfig.Minigame.Enable then
        minigameSuccess = paperboyConfig.Minigame.Start()
        if not minigameSuccess then
            ShowNotification('Delivery failed! Try again.', 'error')
            return
        end
    end
    
    -- Use cached player level to determine progress bar time (no callback needed)
    local deliveryTime = paperboyConfig.Time[cachedPlayerLevel] or paperboyConfig.Time[1] -- Fallback to level 1 time
    
    TaskStartScenarioInPlace(playerPed, "WORLD_HUMAN_CLIPBOARD", 0, true)
    
    if lib.progressBar({
        duration = deliveryTime * 1000,
        label = 'Delivering newspaper...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        }
    }) then
        ClearPedTasks(playerPed)
        
        lib.callback('sd-civilianjobs:server:completePaperboyTask', false, function(paperboyTaskCompleted, paperboyCashReward)
            if paperboyTaskCompleted then
                ShowNotification('Newspaper delivered! $' .. paperboyCashReward .. ' added to your paycheck, next location will be marked.', 'success')
                
                if currentPaperboyJobBlip then
                    RemoveBlip(currentPaperboyJobBlip)
                    currentPaperboyJobBlip = nil
                end
                if currentPaperboyJobTarget then
                    exports.ox_target:removeZone(currentPaperboyJobTarget)
                    currentPaperboyJobTarget = nil
                end
                
                Wait(2000)
                local nextPaperboyLocation = GetRandomPaperboyLocation()
                currentPaperboyJobLocation = nextPaperboyLocation
                
                CreatePaperboyJobBlip(nextPaperboyLocation)
                CreatePaperboyJobTarget(nextPaperboyLocation)
            else
                ShowNotification('Failed to complete newspaper delivery', 'error')
            end
        end)
    else
        ClearPedTasks(playerPed)
        ShowNotification('Newspaper delivery cancelled', 'error')
    end
end

--- Function to start paperboy job session
--- Initializes paperboy work and creates first delivery location
local StartPaperboyJob = function()
    lib.callback('sd-civilianjobs:server:startPaperboyJob', false, function(paperboyJobStarted, paperboyJobMessage)
        if paperboyJobStarted then
            isPaperboyJobActive = true
            ShowNotification(paperboyJobMessage, 'success')
            
            -- Cache player level when job starts to avoid repeated callbacks
            lib.callback('sd-civilianjobs:server:getPlayerInfo', false, function(data)
                cachedPlayerLevel = (data and data.level) or 1
                
                local firstPaperboyLocation = GetRandomPaperboyLocation()
                currentPaperboyJobLocation = firstPaperboyLocation
                
                CreatePaperboyJobBlip(firstPaperboyLocation)
                CreatePaperboyJobTarget(firstPaperboyLocation)
            end, 'paperboy')
        else
            ShowNotification(paperboyJobMessage, 'error')
        end
    end)
end

--- Function to end paperboy job session and process final paycheck
--- Cleans up active job elements and displays earnings summary
local EndPaperboyJob = function()
    lib.callback('sd-civilianjobs:server:endPaperboyJob', false, function(paperboyJobEnded, paperboyJobSummary)
        if paperboyJobEnded then
            isPaperboyJobActive = false
            
            if currentPaperboyJobBlip then
                RemoveBlip(currentPaperboyJobBlip)
                currentPaperboyJobBlip = nil
            end
            if currentPaperboyJobTarget then
                exports.ox_target:removeZone(currentPaperboyJobTarget)
                currentPaperboyJobTarget = nil
            end
            
            local paperboyWorkTimeMinutes = math.floor(paperboyJobSummary.workTime / 60)
            local paperboyTotalPayout = paperboyJobSummary.totalEarned + paperboyJobSummary.bonusPayment
            
            lib.registerContext({
                id = 'paperboy_job_summary',
                title = 'Paperboy Job Complete - Final Paycheck',
                options = {
                    {
                        title = 'Work Summary',
                        description = 'Your paperboy work session results',
                        icon = 'fas fa-clipboard-check',
                        readOnly = true
                    },
                    {
                        title = 'Newspapers Delivered',
                        description = paperboyJobSummary.newspapersDelivered .. ' newspapers delivered',
                        icon = 'fas fa-newspaper',
                        readOnly = true
                    },
                    {
                        title = 'Work Time',
                        description = paperboyWorkTimeMinutes .. ' minutes worked',
                        icon = 'fas fa-clock',
                        readOnly = true
                    },
                    {
                        title = 'Base Earnings',
                        description = '$' .. paperboyJobSummary.totalEarned .. ' from deliveries',
                        icon = 'fas fa-dollar-sign',
                        readOnly = true
                    },
                    {
                        title = 'Bonus Payment',
                        description = paperboyJobSummary.bonusPayment > 0 and ('$' .. paperboyJobSummary.bonusPayment .. ' (10% bonus for 10+ deliveries)') or 'No bonus earned',
                        icon = 'fas fa-gift',
                        readOnly = true
                    },
                    {
                        title = 'Total Payout',
                        description = '$' .. paperboyTotalPayout .. ' total earned',
                        icon = 'fas fa-money-bill-wave',
                        readOnly = true
                    }
                }
            })
            lib.showContext('paperboy_job_summary')
            
            ShowNotification('Paperboy job completed! Total earned: $' .. paperboyTotalPayout, 'success')
        else
            ShowNotification('Failed to end paperboy job', 'error')
        end
    end)
end

--- Main paperboy menu function
--- Displays paperboy job options, level progress, and statistics
OpenPaperboyMenu = function()
    lib.callback('sd-civilianjobs:server:hasActivePaperboyJob', false, function(hasActivePaperboyJob)
        isPaperboyJobActive = hasActivePaperboyJob
        
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
                
                local paperboyLevelConfig = mainConfig.Levels.paperboy or {}
                
                currentLevelXP = paperboyLevelConfig[level] and paperboyLevelConfig[level].xpRequired or 0
                
                local nextLevel = level + 1
                nextLevelXP = paperboyLevelConfig[nextLevel] and paperboyLevelConfig[nextLevel].xpRequired or currentLevelXP
                
                isMaxLevel = not paperboyLevelConfig[nextLevel]
                
                if not isMaxLevel and nextLevelXP > currentLevelXP then
                    local xpIntoCurrentLevel = xp - currentLevelXP
                    local xpNeededForNextLevel = nextLevelXP - currentLevelXP
                    progress = math.floor((xpIntoCurrentLevel / xpNeededForNextLevel) * 100)
                    progress = math.max(0, math.min(100, progress))
                else
                    progress = 100
                end
            end
            
            local paperboyJobOption = {
                title = isPaperboyJobActive and 'End Job & Get Paycheck' or 'Start Job',
                description = isPaperboyJobActive and 'Complete your work and receive final payment' or 'Begin a newspaper delivery job',
                icon = isPaperboyJobActive and 'fas fa-stop-circle' or 'fas fa-newspaper',
                onSelect = function()
                    if isPaperboyJobActive then
                        EndPaperboyJob()
                    else
                        StartPaperboyJob()
                    end
                end
            }
            
            lib.registerContext({
                id = 'paperboy_main_menu',
                title = 'Paperboy Services',
                options = {
                    {
                        title = 'Level & Progress',
                        description = isMaxLevel and ('Level: ' .. level .. ' (MAX LEVEL) | Total XP: ' .. xp) or ('Level: ' .. level .. ' | XP: ' .. xp .. ' / ' .. nextLevelXP .. ' | Progress: ' .. progress .. '% to next level'),
                        icon = 'fas fa-chart-line',
                        readOnly = true
                    },
                    {
                        title = 'Statistics',
                        description = 'View your paperboy job statistics',
                        icon = 'fas fa-chart-bar',
                        arrow = true,
                        onSelect = function()
                            ShowPaperboyStats()
                        end
                    },
                    paperboyJobOption
                }
            })
            lib.showContext('paperboy_main_menu')
        end, 'paperboy')
    end)
end

-- Initialize paperboy ped spawning using shared system
InitializeJobPedSpawning('paperboy', paperboyConfig, OpenPaperboyMenu, paperboyPedSpawnDistance)