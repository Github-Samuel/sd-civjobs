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
    lib.callback('sd-civilianjobs:server:getPaperboyStats', false, function(paperboyStats)
        if paperboyStats then
            local paperboyStatsOptions = {
                {
                    title = 'Cash Earned',
                    description = '$' .. (paperboyStats.cash_earned or 0) .. ' total earned',
                    icon = 'fas fa-dollar-sign',
                    readOnly = true
                },
                {
                    title = 'Newspapers Delivered',
                    description = (paperboyStats.newspapers_delivered or 0) .. ' newspapers delivered',
                    icon = 'fas fa-newspaper',
                    readOnly = true
                },
                {
                    title = 'Routes Completed',
                    description = (paperboyStats.routes_completed or 0) .. ' delivery routes completed',
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
    end)
end



-- Paperboy job state variables
local paperboyWorkZones = {}
local paperboyBlipStore = {}
local paperboyDelay = false
local paperboyNetId = nil

--- Function to reset paperboy job zones and blips
local ResetPaperboyJob = function()
    if next(paperboyWorkZones) then
        for i = 1, #paperboyWorkZones do
            if paperboyWorkZones[i] then
                paperboyWorkZones[i]:remove()
            end
        end
    end
    if next(paperboyBlipStore) then
        for k, _ in pairs(paperboyBlipStore) do
            if DoesBlipExist(paperboyBlipStore[k]) then
                RemoveBlip(paperboyBlipStore[k])
                paperboyBlipStore[k] = nil
            end
        end
    end
    table.wipe(paperboyWorkZones)
    table.wipe(paperboyBlipStore)
end

--- Function to validate newspaper drop at delivery point
--- @param point table The delivery point that was hit
local ValidatePaperboyDrop = function(point)
    lib.callback('sd-civilianjobs:server:validatePaperboyDrop', false, function(success, remainingDeliveries)
        if success then
            point:remove()
            if next(paperboyBlipStore) then
                if DoesBlipExist(paperboyBlipStore[point.blip]) then
                    RemoveBlip(paperboyBlipStore[point.blip])
                    paperboyBlipStore[point.blip] = nil
                end
            end
            
            if remainingDeliveries > 0 then
                ShowNotification(('Newspaper delivered! %s deliveries remaining'):format(remainingDeliveries), 'success')
            else
                ShowNotification('All newspapers delivered! Return to the paperboy to finish your shift.', 'success')
                ResetPaperboyJob()
            end
        else
            ShowNotification('Failed to deliver newspaper', 'error')
        end
        Wait(1000)
        paperboyDelay = false
    end, point.coords, paperboyNetId)
end

--- Function to create paperboy delivery route with throwing mechanics
--- @param deliveryData table Data containing delivery locations and netid
local CreatePaperboyRoute = function(deliveryData)
    if not deliveryData or not deliveryData.locations then return end
    
    paperboyNetId = deliveryData.netid
    
    for k, v in pairs(deliveryData.locations) do
        local zone = lib.points.new({
            coords = vec3(v.x, v.y, v.z),
            distance = 30,
            blip = k,
            nearby = function(point)
                -- Draw marker at delivery location
                DrawMarker(1, point.coords.x, point.coords.y, point.coords.z - 1.5, 0, 0, 0, 0, 0, 0, 4.0, 4.0, 2.0, 227, 14, 88, 165, 0, 0, 0, 0)
                
                -- Check if newspaper projectile is within range
                if point.isClosest and IsProjectileTypeWithinDistance(point.coords.x, point.coords.y, point.coords.z, `WEAPON_ACIDPACKAGE`, 3.0, true) and not paperboyDelay then
                    paperboyDelay = true
                    ValidatePaperboyDrop(point)
                end
            end,
        })
        paperboyWorkZones[#paperboyWorkZones + 1] = zone
        
        -- Create blip for delivery location
        paperboyBlipStore[k] = AddBlipForCoord(v.x, v.y, v.z)
        SetBlipSprite(paperboyBlipStore[k], 40)
        SetBlipDisplay(paperboyBlipStore[k], 4)
        SetBlipScale(paperboyBlipStore[k], 0.65)
        SetBlipAsShortRange(paperboyBlipStore[k], true)
        SetBlipColour(paperboyBlipStore[k], 61)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName('Delivery')
        EndTextCommandSetBlipName(paperboyBlipStore[k])
    end
    
    -- ShowNotification('Route assigned: ' .. (deliveryData.routeName or 'Unknown Route') .. '. Throw newspapers at the marked locations!', 'success')
end

-- Event handler to monitor newspaper inventory
if GetResourceState('es_extended') == 'started' then
    RegisterNetEvent('esx:removeInventoryItem', function(item, count)
        if item == 'WEAPON_ACIDPACKAGE' and isPaperboyJobActive and count == 0 then
            ShowNotification('You are all out of newspapers. Return to the paperboy to finish your shift.', 'info')
            ResetPaperboyJob()
        end
    end)
else
    AddEventHandler('ox_inventory:itemCount', function(item, count)
        if item == 'WEAPON_ACIDPACKAGE' and isPaperboyJobActive and count == 0 then
            ShowNotification('You are all out of newspapers. Return to the paperboy to finish your shift.', 'info')
            ResetPaperboyJob()
        end
    end)
end

--- Function to start paperboy job session
--- Initializes paperboy work and creates delivery route with throwing mechanics
local StartPaperboyJob = function()
    lib.callback('sd-civilianjobs:server:startPaperboyJob', false, function(paperboyJobStarted, paperboyJobMessage, deliveryData)
        if paperboyJobStarted then
            isPaperboyJobActive = true
            ShowNotification(paperboyJobMessage, 'success')
            
            -- Cache player level when job starts to avoid repeated callbacks
            lib.callback('sd-civilianjobs:server:getPlayerInfo', false, function(data)
                cachedPlayerLevel = (data and data.level) or 1
                
                -- Create the delivery route with throwing mechanics
                if deliveryData then
                    CreatePaperboyRoute(deliveryData)
                end
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
            
            -- Clean up delivery zones and blips
            ResetPaperboyJob()
            
            local paperboyWorkTimeMinutes = math.floor(paperboyJobSummary.workTime / 60)
            local paperboyTotalPayout = paperboyJobSummary.totalEarned
            
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