-- Job ped management variables
local jobPeds = {}
local jobBlips = {}
local playerNearPeds = {}

--- Function to show notification to player using lib.notify
--- @param message string The notification message to display
--- @param type string The notification type ('success', 'error', 'info', 'warning')
--- @param duration number Optional duration in milliseconds (default: 5000)
ShowNotification = function(message, type, duration)
    lib.notify({
        title = 'Civilian Jobs',
        description = message,
        type = type or 'info',
        duration = duration or 5000
    })
end

--- Function to spawn a job ped with proper configuration
--- @param jobType string The type of job (e.g., "electrician")
--- @param config table Job configuration containing ped details
--- @param menuFunction function Function to call when interacting with the ped
SpawnJobPed = function(jobType, config, menuFunction)
    if jobPeds[jobType] and DoesEntityExist(jobPeds[jobType]) then return end
    
    if not config or not config.Ped then return end
    
    CreateThread(function()
        local pedModel = lib.requestModel(config.Ped.model, 5000)
        if not pedModel then
            print("^1[Civilian Jobs] Failed to load " .. jobType .. " ped model: " .. config.Ped.model .. "^0")
            return
        end
        
        local pedCoords = config.Ped.coords
        jobPeds[jobType] = CreatePed(4, pedModel, pedCoords.x, pedCoords.y, pedCoords.z - 1.0, config.Ped.heading, false, true)
        
        SetEntityInvincible(jobPeds[jobType], true)
        SetBlockingOfNonTemporaryEvents(jobPeds[jobType], true)
        FreezeEntityPosition(jobPeds[jobType], true)
        
        TaskStartScenarioInPlace(jobPeds[jobType], config.Ped.scenario, 0, true)
        
        -- Add ox_target to the job ped
        exports.ox_target:addLocalEntity(jobPeds[jobType], {
            {
                name = jobType .. '_menu_interaction',
                icon = 'fas fa-bolt',
                label = 'Talk to ' .. jobType:gsub("^%l", string.upper),
                onSelect = menuFunction
            }
        })
        
        print("^2[Civilian Jobs] " .. jobType:gsub("^%l", string.upper) .. " ped spawned successfully^0")
    end)
end

--- Function to despawn a job ped when player leaves area
--- @param jobType string The type of job (e.g., "electrician")
DespawnJobPed = function(jobType)
    if jobPeds[jobType] and DoesEntityExist(jobPeds[jobType]) then
        DeleteEntity(jobPeds[jobType])
        jobPeds[jobType] = nil
        print("^3[Civilian Jobs] " .. jobType:gsub("^%l", string.upper) .. " ped despawned^0")
    end
end

--- Function to initialize job ped proximity spawning
--- @param jobType string The type of job (e.g., "electrician")
--- @param config table Job configuration containing ped details
--- @param menuFunction function Function to call when interacting with the ped
--- @param spawnDistance number Distance at which to spawn/despawn the ped
InitializeJobPedSpawning = function(jobType, config, menuFunction, spawnDistance)
    playerNearPeds[jobType] = false
    
    CreateThread(function()
        while true do
            Wait(1000)
            
            if config and config.Ped then
                local playerPed = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)
                local pedCoords = config.Ped.coords
                local pedDistance = #(playerCoords - pedCoords)
                
                -- Check if player is within spawn distance
                if pedDistance <= spawnDistance then
                    if not playerNearPeds[jobType] then
                        playerNearPeds[jobType] = true
                        SpawnJobPed(jobType, config, menuFunction)
                    end
                else
                    if playerNearPeds[jobType] then
                        playerNearPeds[jobType] = false
                        DespawnJobPed(jobType)
                    end
                end
            end
        end
    end)
end

--- Function to get vehicle license plate text
--- @param vehicle number Vehicle entity handle
--- @return string plate Vehicle license plate text (trimmed)
GetVehiclePlate = function(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return "" end
    return string.gsub(GetVehicleNumberPlateText(vehicle), "^%s*(.-)%s*$", "%1") -- Trim whitespace
end

--- Function to get vehicle fuel level
--- @param vehicle number Vehicle entity handle
--- @return number fuelLevel Current fuel level (0-100)
GetVehicleFuel = function(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return 0 end
    
    -- Try to get fuel from statebag first (ox_fuel)
    local fuelLevel = Entity(vehicle).state.fuel
    if fuelLevel then
        return fuelLevel
    end
    
    -- Fallback to native function
    return GetVehicleFuelLevel(vehicle)
end

--- Function to set vehicle fuel level (client-side)
--- @param vehicle number Vehicle entity handle
--- @param fuelAmount number Fuel amount to set (0-100)
SetVehicleFuel = function(vehicle, fuelAmount)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    
    print('setting fuel to', fuelAmount)
    -- Set using native function (client-side)
    SetVehicleFuelLevel(vehicle, fuelAmount)
    
    -- Trigger server event to set statebag for ox_fuel compatibility
    local plate = GetVehiclePlate(vehicle)
    TriggerServerEvent('sd-civilianjobs:server:setVehicleFuel', NetworkGetNetworkIdFromEntity(vehicle), fuelAmount, plate)
end

--- Function to cleanup all job peds on resource stop
CleanupAllJobPeds = function()
    for jobType, ped in pairs(jobPeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    jobPeds = {}
    
    for jobType, blip in pairs(jobBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    jobBlips = {}
end

-- [[ Commands ]]

--- Command to check current vehicle fuel level
RegisterCommand('fuel', function(source, args, rawCommand)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if vehicle == 0 then
        ShowNotification('You are not in a vehicle!', 'error')
        return
    end
    
    local fuelLevel = GetVehicleFuel(vehicle)
    local vehicleName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    local plate = GetVehiclePlate(vehicle)
    
    ShowNotification(string.format('%s (%s) - Fuel: %.1f%%', vehicleName, plate, fuelLevel), 'info', 7000)
end, false)