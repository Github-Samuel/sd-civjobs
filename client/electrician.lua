local electricianConfig = require('configs/electrician')
local mainConfig = require('configs/main')

-- Electrician ped variables
local electricianBlip = nil
local electricianPedSpawnDistance = 100.0

-- Electrician job variables
local isElectricianJobActive = false
local currentElectricianJobBlip = nil
local currentElectricianJobTarget = nil
local currentElectricianJobLocation = nil
local currentElectricianRepairType = nil
local recentElectricianLocations = {} -- Track recent locations to avoid repeats
local cachedPlayerLevel = 1 -- Cache player level to avoid repeated callbacks

--- Creates electrician blip on resource start for permanent visibility
CreateThread(function()
    if electricianConfig.Blip and electricianConfig.Blip.enable then
        local electricianPedCoords = electricianConfig.Ped.coords
        electricianBlip = AddBlipForCoord(electricianPedCoords.x, electricianPedCoords.y, electricianPedCoords.z)
        SetBlipSprite(electricianBlip, electricianConfig.Blip.sprite)
        SetBlipDisplay(electricianBlip, electricianConfig.Blip.display)
        SetBlipScale(electricianBlip, electricianConfig.Blip.scale)
        SetBlipColour(electricianBlip, electricianConfig.Blip.colour)
        SetBlipAsShortRange(electricianBlip, false) -- Make it always visible
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(electricianConfig.Blip.name)
        EndTextCommandSetBlipName(electricianBlip)
        
        print("^2[Civilian Jobs] Electrician blip created^0")
    end
end)

--- Function to display electrician job statistics menu
--- Shows player's electrician work history and performance metrics
local ShowElectricianStats = function()
    lib.callback('sd-civilianjobs:server:getJobTypeStats', false, function(electricianStatsData)
        if electricianStatsData then
            local electricianGeneralStats = electricianStatsData.general or {}
            local electricianStatsOptions = {
                {
                    title = 'Cash Earned',
                    description = '$' .. (electricianGeneralStats.cash_earned or 0) .. ' total earned',
                    icon = 'fas fa-dollar-sign',
                    readOnly = true
                },
                {
                    title = 'Light Poles Repaired',
                    description = (electricianGeneralStats.light_poles_fixed or 0) .. ' light poles repaired',
                    icon = 'fas fa-lightbulb',
                    readOnly = true
                },
                {
                    title = 'Electrical Boxes Repaired',
                    description = (electricianGeneralStats.electrical_boxes_fixed or 0) .. ' electrical boxes repaired',
                    icon = 'fas fa-plug',
                    readOnly = true
                },
                {
                    title = 'Back',
                    description = 'Return to main menu',
                    icon = 'fas fa-arrow-left',
                    onSelect = function()
                        OpenElectricianMenu()
                    end
                }
            }
            
            lib.registerContext({
                id = 'electrician_stats_menu',
                title = 'Electrician Statistics',
                menu = 'electrician_main_menu',
                options = electricianStatsOptions
            })
            lib.showContext('electrician_stats_menu')
        else
            ShowNotification('Failed to load electrician statistics', 'error')
        end
    end, 'electrician')
end

--- Function to create electrician job blip for repair locations
--- @param electricianJobCoords vector3 Coordinates for the repair location
--- @param electricianRepairType string Type of repair ("lightPole" or "electricalBox")
local CreateElectricianJobBlip = function(electricianJobCoords, electricianRepairType)
    if currentElectricianJobBlip then
        RemoveBlip(currentElectricianJobBlip)
    end
    
    currentElectricianJobBlip = AddBlipForCoord(electricianJobCoords.x, electricianJobCoords.y, electricianJobCoords.z)
    
    if electricianRepairType == "lightPole" then
        SetBlipSprite(currentElectricianJobBlip, 354) -- Light bulb icon
        SetBlipColour(currentElectricianJobBlip, 46) -- Light blue
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Light Pole Repair")
        EndTextCommandSetBlipName(currentElectricianJobBlip)
    else -- electricalBox
        SetBlipSprite(currentElectricianJobBlip, 354) -- Electrical icon
        SetBlipColour(currentElectricianJobBlip, 5) -- Yellow
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Electrical Box Repair")
        EndTextCommandSetBlipName(currentElectricianJobBlip)
    end
    
    SetBlipDisplay(currentElectricianJobBlip, 4)
    SetBlipScale(currentElectricianJobBlip, 0.8)
    SetBlipAsShortRange(currentElectricianJobBlip, false)
    SetBlipRoute(currentElectricianJobBlip, true)
    SetBlipRouteColour(currentElectricianJobBlip, 3)
end

--- Function to check if location was recently used
--- @param location vector3 Location to check
--- @return boolean wasRecentlyUsed Whether the location was recently used
local IsLocationRecentlyUsed = function(location)
    for _, recentLocation in ipairs(recentElectricianLocations) do
        if #(location - recentLocation) < 5.0 then -- Within 5 units is considered same location
            return true
        end
    end
    return false
end

--- Function to add location to recent locations list
--- @param location vector3 Location to add to recent list
local AddToRecentLocations = function(location)
    table.insert(recentElectricianLocations, location)
    
    -- Keep only the last 4-5 locations
    if #recentElectricianLocations > 5 then
        table.remove(recentElectricianLocations, 1) -- Remove oldest location
    end
end

--- Function to get random electrician repair location within distance constraints
--- @return vector3 randomElectricianLocation Random coordinates for repair work within distance range
--- @return string electricianRepairType Type of repair needed ("lightPole" or "electricalBox")
local GetRandomElectricianLocation = function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local electricianRepairTypes = {"lightPole", "electricalBox"}
    local selectedElectricianRepairType = electricianRepairTypes[math.random(#electricianRepairTypes)]
    local electricianRepairLocations
    
    if selectedElectricianRepairType == "lightPole" then
        electricianRepairLocations = electricianConfig.JobLocations.lightPoles
    else
        electricianRepairLocations = electricianConfig.JobLocations.electricalBoxes
    end
    
    -- Filter locations by distance and exclude recent locations
    local validElectricianLocations = {}
    for _, location in ipairs(electricianRepairLocations) do
        local distance = #(playerCoords - location)
        if distance >= electricianConfig.Distance.min and distance <= electricianConfig.Distance.max then
            if not IsLocationRecentlyUsed(location) then
                table.insert(validElectricianLocations, location)
            end
        end
    end
    
    -- If no valid locations found within distance range (excluding recent), try with recent locations included
    if #validElectricianLocations == 0 then
        for _, location in ipairs(electricianRepairLocations) do
            local distance = #(playerCoords - location)
            if distance >= electricianConfig.Distance.min and distance <= electricianConfig.Distance.max then
                table.insert(validElectricianLocations, location)
            end
        end
        print("^3[Civilian Jobs] No new electrician locations found within distance range, including recent locations^0")
    end
    
    -- If still no valid locations, use random location from all available
    if #validElectricianLocations == 0 then
        validElectricianLocations = electricianRepairLocations
        print("^3[Civilian Jobs] No electrician locations found within distance range, using random location^0")
    end
    
    local randomElectricianLocation = validElectricianLocations[math.random(#validElectricianLocations)]
    
    -- Add this location to recent locations list
    AddToRecentLocations(randomElectricianLocation)
    
    return randomElectricianLocation, selectedElectricianRepairType
end

--- Function to create electrician job target for repair interactions
--- @param electricianJobCoords vector3 Coordinates for the repair target
--- @param electricianRepairType string Type of repair ("lightPole" or "electricalBox")
local CreateElectricianJobTarget = function(electricianJobCoords, electricianRepairType)
    if currentElectricianJobTarget then
        exports.ox_target:removeZone(currentElectricianJobTarget)
    end
    
    local electricianTargetOptions = {
        {
            name = 'repair_electrician_' .. electricianRepairType,
            icon = electricianRepairType == "lightPole" and 'fas fa-lightbulb' or 'fas fa-plug',
            label = electricianRepairType == "lightPole" and 'Repair Light Pole' or 'Repair Electrical Box',
            onSelect = function()
                RepairElectricalItem(electricianRepairType)
            end
        }
    }
    
    currentElectricianJobTarget = exports.ox_target:addSphereZone({
        coords = electricianJobCoords,
        radius = 2.0,
        options = electricianTargetOptions
    })
end

--- Function to handle electrician repair work on electrical items
--- @param repairType string Type of repair work ("lightPole" or "electricalBox")
RepairElectricalItem = function(repairType)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local repairTargetCoords = currentElectricianJobLocation
    
    local minigameSuccess = true
    if electricianConfig.Minigame.Enable then
        minigameSuccess = electricianConfig.Minigame.Start()
        if not minigameSuccess then
            ShowNotification('Repair failed! Try again.', 'error')
            return
        end
    end
    
    -- Use cached player level to determine progress bar time (no callback needed)
    local repairTime = electricianConfig.Time[cachedPlayerLevel] or electricianConfig.Time[1] -- Fallback to level 1 time
    
    TaskStartScenarioInPlace(playerPed, "WORLD_HUMAN_WELDING", 0, true)
    
    if lib.progressBar({
        duration = repairTime * 1000,
        label = repairType == "lightPole" and 'Repairing light pole...' or 'Repairing electrical box...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        }
    }) then
            local playerCoords = GetEntityCoords(playerPed)
            local blowtorchProp = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, 3.0, GetHashKey('prop_weld_torch'), false, false, false)
            if blowtorchProp and blowtorchProp ~= 0 then
                DeleteObject(blowtorchProp)
            end
            
            -- Now clear the tasks
            ClearPedTasks(playerPed)
            
            lib.callback('sd-civilianjobs:server:completeElectricianTask', false, function(electricianTaskCompleted, electricianCashReward)
                if electricianTaskCompleted then
                    local electricianRepairTypeText = repairType == "lightPole" and "light pole" or "electrical box"
                    ShowNotification('Repair completed! $' .. electricianCashReward .. ' added to your paycheck for fixing the ' .. electricianRepairTypeText .. ', next location will be marked.', 'success')
                    
                    if currentElectricianJobBlip then
                        RemoveBlip(currentElectricianJobBlip)
                        currentElectricianJobBlip = nil
                    end
                    if currentElectricianJobTarget then
                        exports.ox_target:removeZone(currentElectricianJobTarget)
                        currentElectricianJobTarget = nil
                    end
                    
                    Wait(2000)
                    local nextElectricianLocation, nextElectricianRepairType = GetRandomElectricianLocation()
                    currentElectricianJobLocation = nextElectricianLocation
                    currentElectricianRepairType = nextElectricianRepairType
                    
                    CreateElectricianJobBlip(nextElectricianLocation, nextElectricianRepairType)
                    CreateElectricianJobTarget(nextElectricianLocation, nextElectricianRepairType)
                else
                    ShowNotification('Failed to complete electrician repair', 'error')
                end
            end, repairType)
        else
            -- Find and delete the blowtorch prop before clearing tasks
            local playerCoords = GetEntityCoords(playerPed)
            local blowtorchProp = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, 3.0, GetHashKey('prop_weld_torch'), false, false, false)
            if blowtorchProp and blowtorchProp ~= 0 then
                DeleteObject(blowtorchProp)
            end
            
            -- Now clear the tasks
            ClearPedTasks(playerPed)
            ShowNotification('Electrician repair cancelled', 'error')
        end
end

-- Function to start electrician job session
--- Initializes electrician work and creates first repair location
local StartElectricianJob = function()
    lib.callback('sd-civilianjobs:server:startElectricianJob', false, function(electricianJobStarted, electricianJobMessage)
        if electricianJobStarted then
            isElectricianJobActive = true
            ShowNotification(electricianJobMessage, 'success')
            
            -- Cache player level when job starts to avoid repeated callbacks
            lib.callback('sd-civilianjobs:server:getPlayerInfo', false, function(data)
                cachedPlayerLevel = (data and data.level) or 1
                
                local firstElectricianLocation, firstElectricianRepairType = GetRandomElectricianLocation()
                currentElectricianJobLocation = firstElectricianLocation
                currentElectricianRepairType = firstElectricianRepairType
                
                CreateElectricianJobBlip(firstElectricianLocation, firstElectricianRepairType)
                CreateElectricianJobTarget(firstElectricianLocation, firstElectricianRepairType)
            end, 'electrician')
        else
            ShowNotification(electricianJobMessage, 'error')
        end
    end)
end

--- Function to end electrician job session and process final paycheck
--- Cleans up active job elements and displays earnings summary
local EndElectricianJob = function()
    lib.callback('sd-civilianjobs:server:endElectricianJob', false, function(electricianJobEnded, electricianJobSummary)
        if electricianJobEnded then
            isElectricianJobActive = false
            
            if currentElectricianJobBlip then
                RemoveBlip(currentElectricianJobBlip)
                currentElectricianJobBlip = nil
            end
            if currentElectricianJobTarget then
                exports.ox_target:removeZone(currentElectricianJobTarget)
                currentElectricianJobTarget = nil
            end
            
            local electricianWorkTimeMinutes = math.floor(electricianJobSummary.workTime / 60)
            local electricianTotalPayout = electricianJobSummary.totalEarned + electricianJobSummary.bonusPayment
            
            lib.registerContext({
                id = 'electrician_job_summary',
                title = 'Electrician Job Complete - Final Paycheck',
                options = {
                    {
                        title = 'Work Summary',
                        description = 'Your electrician work session results',
                        icon = 'fas fa-clipboard-check',
                        readOnly = true
                    },
                    {
                        title = 'Light Poles Fixed',
                        description = electricianJobSummary.lightPolesFixed .. ' light poles repaired',
                        icon = 'fas fa-lightbulb',
                        readOnly = true
                    },
                    {
                        title = 'Electrical Boxes Fixed',
                        description = electricianJobSummary.electricalBoxesFixed .. ' electrical boxes repaired',
                        icon = 'fas fa-plug',
                        readOnly = true
                    },
                    {
                        title = 'Work Time',
                        description = electricianWorkTimeMinutes .. ' minutes worked',
                        icon = 'fas fa-clock',
                        readOnly = true
                    },
                    {
                        title = 'Base Earnings',
                        description = '$' .. electricianJobSummary.totalEarned .. ' from repairs',
                        icon = 'fas fa-dollar-sign',
                        readOnly = true
                    },
                    {
                        title = 'Bonus Payment',
                        description = electricianJobSummary.bonusPayment > 0 and ('$' .. electricianJobSummary.bonusPayment .. ' (10% bonus for 5+ tasks)') or 'No bonus earned',
                        icon = 'fas fa-gift',
                        readOnly = true
                    },
                    {
                        title = 'Total Payout',
                        description = '$' .. electricianTotalPayout .. ' total earned',
                        icon = 'fas fa-money-bill-wave',
                        readOnly = true
                    }
                }
            })
            lib.showContext('electrician_job_summary')
            
            ShowNotification('Electrician job completed! Total earned: $' .. electricianTotalPayout, 'success')
        else
            ShowNotification('Failed to end electrician job', 'error')
        end
    end)
end

--- Main electrician menu function
--- Displays electrician job options, level progress, and statistics
OpenElectricianMenu = function()
    lib.callback('sd-civilianjobs:server:hasActiveElectricianJob', false, function(hasActiveElectricianJob)
        isElectricianJobActive = hasActiveElectricianJob
        
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
                
                local electricianLevelConfig = mainConfig.Levels.electrician or {}
                
                currentLevelXP = electricianLevelConfig[level] and electricianLevelConfig[level].xpRequired or 0
                
                local nextLevel = level + 1
                nextLevelXP = electricianLevelConfig[nextLevel] and electricianLevelConfig[nextLevel].xpRequired or currentLevelXP
                
                isMaxLevel = not electricianLevelConfig[nextLevel]
                
                if not isMaxLevel and nextLevelXP > currentLevelXP then
                    local xpIntoCurrentLevel = xp - currentLevelXP
                    local xpNeededForNextLevel = nextLevelXP - currentLevelXP
                    progress = math.floor((xpIntoCurrentLevel / xpNeededForNextLevel) * 100)
                    progress = math.max(0, math.min(100, progress))
                else
                    progress = 100
                end
                
                local levelDescription = isMaxLevel and ('Level: ' .. level .. ' (MAX LEVEL) | Total XP: ' .. xp) or ('Level: ' .. level .. ' | XP: ' .. xp .. ' / ' .. nextLevelXP .. ' | Progress: ' .. progress .. '% to next level')
            end
            
            local electricianJobOption = {
                title = isElectricianJobActive and 'End Job & Get Paycheck' or 'Start Job',
                description = isElectricianJobActive and 'Complete your work and receive final payment' or 'Begin an electrician repair job',
                icon = isElectricianJobActive and 'fas fa-stop-circle' or 'fas fa-bolt',
                onSelect = function()
                    if isElectricianJobActive then
                        EndElectricianJob()
                    else
                        StartElectricianJob()
                    end
                end
            }
            
            lib.registerContext({
                id = 'electrician_main_menu',
                title = 'Electrician Services',
                options = {
                    {
                        title = 'Level & Progress',
                        description = isMaxLevel and ('Level: ' .. level .. ' (MAX LEVEL) | Total XP: ' .. xp) or ('Level: ' .. level .. ' | XP: ' .. xp .. ' / ' .. nextLevelXP .. ' | Progress: ' .. progress .. '% to next level'),
                        icon = 'fas fa-chart-line',
                        readOnly = true
                    },
                    {
                        title = 'Statistics',
                        description = 'View your electrician job statistics',
                        icon = 'fas fa-chart-bar',
                        arrow = true,
                        onSelect = function()
                            ShowElectricianStats()
                        end
                    },
                    electricianJobOption
                }
            })
            lib.showContext('electrician_main_menu')
        end, 'electrician')
    end)
end

-- Initialize electrician ped spawning using shared system
InitializeJobPedSpawning('electrician', electricianConfig, OpenElectricianMenu, electricianPedSpawnDistance)