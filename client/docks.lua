-- Global variables
local Targets, Blips = {}, {}
JobActive = false
payOut, maxJobs, count = 0, 0, 0
pickUp, dropOff = false, false
CurrentLocation = {}
CurrentBlip, CurrentBlip2 = nil, nil
ObjectSpawned = false
isAttached = false
pallet = nil
drawDropOff = false
currentJob = nil
onSpecialJob = false
ContainersCompleted, PalletsCompleted = false, false
containerJobs, palletJobs = 0, 0
containerCount, palletCount = 0, 0
ContainersNotNeeded, PalletsNotNeeded = false, false
SpecialOrderId = nil

RegisterCommand('attach', function()
    local currentVehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    local framePos = GetWorldPositionOfEntityBone(currentVehicle, 15)
    local obj = GetClosestObjectOfType(framePos, 1.80, GetHashKey('prop_contr_03b_ld'))
    local objPos = GetEntityCoords(obj)
    local targetObj = GetEntityCoords(container)
    if obj ~= 0 and GetEntityModel(currentVehicle) == `handler` then
        if isAttached then
            DetachEntity(attachedContainer, true, true)
            attachedContainer = nil
            isAttached = false
        else
            isAttached = true
            attachedContainer = obj
            AttachEntityToEntity(obj, currentVehicle, 15, 0.0, 1.8, -2.8, 0.0, 0, 90.0, false, false, false, false, 2, true)
            if #(objPos - targetObj) < 3 and pickUp then
                TriggerEvent('fs-dockjob:client:collectContainer')
            end
        end
    end
end, false)

RegisterKeyMapping('attach', 'Attach container', 'keyboard', 'E') -- Default keymapping 'E', can be changed in keybinds

-- LOCAL FUNCTIONS
local function isJobVehicle(vehicle)
    if GetEntityModel(vehicle) == GetHashKey("forklift") or GetEntityModel(vehicle) == GetHashKey("handler") then
        return true
    end
    return false
end

local function canTakeJob()
    return GetGameTimer() >= (nextJobTime or 0)
end

local function ResetJob()
    payOut = 0
    pickUp = false
    dropOff = false
    JobActive = false
    containerJobs, palletJobs = 0, 0
    containerCount, palletCount = 0, 0
    ClearBlips()
    ClearProps()
    SpecialOrderId = nil
    onSpecialJob = false
    ContainersCompleted, PalletsCompleted = false, false
    ContainersNotNeeded, PalletsNotNeeded = false, false

end

RegisterNetEvent("fs-dockjob:client:cancelJob", function()
    TriggerServerEvent("jixel-logistics:server:unassignJob", SpecialOrderId)
    ResetJob()
    TriggerServerEvent('fs-dockjob:server:decreaseCounter')
end)

local function countTable(table)
    local count = 0
    for k, v in pairs(table) do
        count = count + 1
    end
    return count
end

local function getItemCount(order)
    local numItems = 0
    for k, v in pairs(order.items) do
        numItems = v.quantity + numItems
    end
    return numItems
end

-- GLOBAL FUNCTIONS

function ClearBlips()
    if DoesBlipExist(CurrentBlip) then RemoveBlip(CurrentBlip) CurrentBlip = nil end
    if DoesBlipExist(CurrentBlip2) then RemoveBlip(CurrentBlip2) CurrentBlip2 = nil end
end

function ClearProps()
    if DoesEntityExist(pallet) then DeleteObject(pallet) end
    if DoesEntityExist(container) then DeleteObject(container) end
    ObjectSpawned = false
end

function getRandomPickup(jobType)
    local randomPickup = math.random(1, #Config.Locations[jobType]["pickup"])
    while (randomPickup == lastPickup) do
        Wait(10)
        randomPickup = math.random(1, #Config.Locations[jobType]["pickup"])
    end
    lastPickup = randomPickup
    return randomPickup
end

function getRandomDropoff(jobType)
    local randomDropoff = math.random(1, #Config.Locations[jobType]["dropoff"])
    while (randomDropoff == lastDropoff) do
        Wait(10)
        randomDropoff = math.random(1, #Config.Locations[jobType]["dropoff"])
    end
    lastDropoff = randomDropoff
    return randomDropoff
end

-- MENUS

local function SpecialOrders()
    local specialJobs = lib.callback.await('fs-dockjob:server:getOrders', 200)
    local jobOptions = {}
    local countJobs = countTable(specialJobs)
    local PlayerData = QBCore.Functions.GetPlayerData()
    local cid = PlayerData.citizenid
    if countJobs > 0 then
        for k, v in pairs(specialJobs) do
            local jobs = v.maxStops
            local pay = v.dockpay
            local decodeAssigned = v.assigned and json.decode(v.assigned)
            if decodeAssigned ~= nil and decodeAssigned?.citizenid == cid and not JobActive then
                jobOptions[#jobOptions+1] = {
                    title = "Restart Assigned Job",
                    description = "Pay $" .. pay .. "/ Number of Stops:" .. jobs .. "\n Assigned: " .. (decodeAssigned?.name and decodeAssigned.name or "Unassigned"),
                    arrow = true,
                    event = 'fs-dockjob:client:startSpecialOrder',
                    args = {
                        key = k,
                        id = v.id,
                        maxStops = jobs
                    }
                }
            end
            jobOptions[#jobOptions + 1] = {
                title = v.title,
                description = "Pay $" .. pay .. "/ Number of Stops:" .. jobs .. "\n Assigned: " .. (decodeAssigned?.name and decodeAssigned.name or "Unassigned"),
                icon = 'trailer',
                event = 'fs-dockjob:client:startSpecialOrder',
                arrow = decodeAssigned?.name and false or true,
                disabled = decodeAssigned?.name and true or false,
                args = {
                    key = k,
                    id = v.id,
                    maxStops = jobs
                }
            }
        end
    else
        jobOptions[1] = {
            title = "No jobs currently available.",
            description = "Please wait till later...",
            icon = 'trailer',
            disabled = true
        }
    end
    lib.registerContext({ menu = 'job_menu', id = 'special_orders', title = 'Available Jobs', options = jobOptions })
    lib.showContext('special_orders')
end

local function getMaxJobsFromGrade(grade)
    local gradeToMaxJobs = {
        [0] = 10,
        [1] = 10,
        [2] = 10,
        [3] = 10,
        [4] = 10,
        [5] = 10
    }
    return gradeToMaxJobs[grade] or 3
end

local function JobMenu()
    lib.callback('fs-dockjob:server:getPlayerCounter', false, function(playerCounter)
        local menu = {}
        local PlayerData = QBCore.Functions.GetPlayerData()
        local grade = PlayerData.job.grade.level
        local maxJobs = getMaxJobsFromGrade(grade)
        local disabled = (playerCounter >= maxJobs) or JobActive

        menu[#menu + 1] = {
            title = "Orders Completed: " .. playerCounter .. ", Remaining: " .. (maxJobs - playerCounter),
            description = "Make the most of your shift before the daily limit is reached!",
            readOnly = true,
        }

        if JobActive then
            menu[#menu + 1] = {
                title = "Cancel Current Job",
                arrow = true,
                event = 'fs-dockjob:client:cancelJob',
            }
        end

        menu[#menu + 1] = {
            title = 'Deliver Pallets',
            description = 'Use a forklift to deliver pallets',
            icon = 'box',
            event = 'fs-dockjob:client:startPallets',
            arrow = true,
            disabled = disabled,
        }

        menu[#menu + 1] = {
            title = 'Deliver Containers',
            description = 'Use a dock handler to deliver containers',
            icon = 'boxes',
            event = 'fs-dockjob:client:startContainers',
            arrow = true,
            disabled = disabled,
        }

        if grade >= 1 then
            menu[#menu + 1] = {
                title = 'Special Orders',
                description = 'Pick up a Special Order Job',
                icon = 'boxes',
                disabled = disabled,
                onSelect = function()
                    SpecialOrders()
                end,
                arrow = true,
            }
        end

        lib.registerContext({ id = 'job_menu', title = 'Available Jobs', menu = 'main_menu', options = menu })
        lib.showContext('job_menu')
    end)
end

local function GarageMenu()
    local menu = {}
    menu[#menu+1] = {
        title = "Forklift",
        description = "For lifting and moving pallets",
        icon = 'tractor',
        event = 'fs-dockjob:client:retrieveForklift',
    }
    menu[#menu+1] = {
        title = "Handler",
        description = "For lifting and moving Shipping containers",
        icon = 'tractor',
        event = 'fs-dockjob:client:retrieveHandler',
    }
    lib.registerContext({ id = 'garage_menu', title = 'Job Vehicles', menu = 'main_menu', options = menu })
    lib.showContext('garage_menu')
end

local function PayChequeMenu()
    local menu = {}
    if payOut > 0 and JobActive then
        menu[#menu+1] = {
            title = 'Collect your Pay Check early',
            description = 'You will be getting a pay cut',
            icon = 'money-check-alt',
            event = 'fs-dockjob:client:PaySlip',
        }
    elseif JobActive then
        menu[#menu+1] = {
            title = 'You\'ve Completed no work',
            description = "You will not be getting paid",
            icon = 'money-check-alt',
            event = 'fs-dockjob:client:PaySlip',
        }
    elseif payOut > 0 and not JobActive then
        menu[#menu+1] = {
            title = 'Collect your Pay Check',
            description = 'Good Job!',
            icon = 'money-check-alt',
            event = 'fs-dockjob:client:PaySlip',
        }
    elseif onSpecialJob and PalletsNotNeeded and ContainersCompleted then
        menu[#menu+1] = {
            title = 'Collect your Pay Check',
            description = 'Good Job!',
            icon = 'money-check-alt',
            event = 'fs-dockjob:client:PaySlip',
        }
    elseif onSpecialJob and ContainersNotNeeded and PalletsCompleted then
        menu[#menu+1] = {
            title = 'Collect your Pay Check',
            description = 'Good Job!',
            icon = 'money-check-alt',
            event = 'fs-dockjob:client:PaySlip',
        }
    elseif onSpecialJob and PalletsCompleted and ContainersCompleted then
        menu[#menu+1] = {
            title = 'Collect your Pay Check',
            description = 'Good Job!',
            icon = 'money-check-alt',
            event = 'fs-dockjob:client:PaySlip',
        }
    else
        menu[#menu+1] = {
            title = 'We\'re not going to pay you for doing nothing...',
            disabled = true,
        }
    end
    lib.registerContext({ id = 'pay_menu', title = 'Pay Menu', options = menu })
    lib.showContext('pay_menu')
end

local function MainMenu()
    local menu = {}
    menu[#menu+1] = {
        title = 'Available Jobs',
        description = 'Check available jobs',
        icon = 'warehouse',
        arrow = true,
        onSelect = function()
            JobMenu()
        end
    }
    menu[#menu+1] =  {
        title = 'Garage',
        description = 'Open Garage',
        icon = 'warehouse',
        arrow = true,
        onSelect = function()
            GarageMenu()
        end
    }
    menu[#menu+1] =  {
        title = 'Receive Paycheck',
        description = 'Receive your paycheck or finish working',
        icon = 'money-check-alt',
        onSelect = function()
            PayChequeMenu()
        end
    }
    menu[#menu+1] =  {
        title = 'Return Vehicle',
        description = 'Return your job vehicle',
        icon = 'tractor',
        event = 'fs-dockjob:client:returnVehicle',
    }
    lib.registerContext({ id = 'main_menu', title = 'Pier 400 Dock', options = menu })
    lib.showContext('main_menu')
end
-- ZONES
function CreateZone(type, number)
    local coords, heading, boxName, event, label, size
    if type == "pallets" then
        event = "fs-dockjob:client:spawnPallet"
        label = "Pallet"
        coords = vector3(Config.Locations[type]["pickup"][number].coords.x, Config.Locations[type]["pickup"][number].coords.y, Config.Locations[type]["pickup"][number].coords.z)
        heading = Config.Locations[type]["pickup"][number].coords.h
        boxName = Config.Locations[type]["pickup"][number].name
        size = 100
    elseif type == "containers" then
        event = "fs-dockjob:client:spawnContainer"
        label = "Container"
        coords = vector3(Config.Locations[type]["pickup"][number].coords.x, Config.Locations[type]["pickup"][number].coords.y, Config.Locations[type]["pickup"][number].coords.z)
        heading = Config.Locations[type]["pickup"][number].coords.h
        boxName = Config.Locations[type]["pickup"][number].name
        size = 100
    end

    local zone = BoxZone:Create(
        coords, size, size, {
            minZ = coords.z - 5.0,
            maxZ = coords.z + 5.0,
            name = boxName,
            debugPoly = false,
            heading = heading,
        })
    zone:onPlayerInOut(function(isPointInside)
        if isPointInside then
            if type == "pallets" then
                if currentJob ~= number then return end
                TriggerEvent('fs-dockjob:client:spawnPallet', number)
                zone:destroy()
            elseif type == "containers" then
                if currentJob ~= number then return end
                TriggerEvent('fs-dockjob:client:spawnContainer', number)
                zone:destroy()
            end
        end
    end)
end

-- Targets

local elements_initialized = false
local function CreateElements()
    if elements_initialized then return end
    elements_initialized = true
    Blips[#Blips+1] = makeBlip({
        coords = Config.Locations["main"].coords,
        sprite = 569,
        colour = 3,
        scale = 0.7,
        disp = 4,
        name = Config.Locations["main"].label
    })
    -- Computer
    Targets[#Targets+1] = exports['qb-target']:AddBoxZone("DockPC", Config.Locations["main"].coords, 1, 1,
    { name = "DockPC", minZ = Config.Locations["main"].coords.z - 0.5, maxZ = Config.Locations["main"].coords.z + 0.5, heading = Config.Locations["main"].coords.w, debugPoly = Config.Debug, },
    { options = {
            {
                type = "client",
                action = function()
                    MainMenu()
                end,
                icon = 'fas fa-hard-hat',
                label = "Open Job Menu",
                job = "dock",
            },
            {
                type = "client",
                event = 'qb-bossmenu:client:OpenMenu',
                icon = 'fas fa-list',
                label = "Open Management Menu",
                job = {["dock"] = 3},
            },
        },
        distance = 3.0
    })

    -- Stash
    Targets[#Targets+1] = exports['qb-target']:AddBoxZone("DockStash", vector3(Config.Locations["main"].stash.x, Config.Locations["main"].stash.y, Config.Locations["main"].stash.z), 0.5, 2.0,
    { name = "DockStash", heading = Config.Locations["main"].stash.w, debugPoly = false, minZ = Config.Locations["main"].stash.z - 1.0, maxZ = Config.Locations["main"].stash.z + 1.0,},
    { options = {
            {
                type = "client",
                event = "fs-dockjob:client:Stash",
                icon = "fas fa-box-open",
                label = "Open Job Storage",
                stash = "DockStash_Storage"
            },
            {
                type = "client",
                action = function()
                    TriggerEvent("qb-clothing:client:openOutfitMenu")
                end,
                icon = "fas fa-tshirt",
                label = "Open Wardrobe",
            },
        },
        distance = 2.5
    })
end

-- Events
RegisterNetEvent('fs-dockjob:client:Stash', function(data)
    json.encode(data)
	if Config.Inv == "ox" then exports.ox_inventory:openInventory('stash', data.stash)
	else TriggerEvent("inventory:client:SetCurrentStash", data.stash)
	TriggerServerEvent("inventory:server:OpenInventory", "stash", data.stash) end
end)

RegisterNetEvent('fs-dockjob:client:deleteVehicle', function()
    vehicle = GetVehiclePedIsIn(PlayerPedId(), true)
    DeleteVehicle(vehicle)
end)

RegisterNetEvent('fs-dockjob:client:returnVehicle', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), true)
    local garage = Config.Locations["main"].garage
    local plate = GetVehicleNumberPlateText(vehicle)
    local returnPos = vector3(garage.x, garage.y, garage.z)
    if #(GetEntityCoords(vehicle) - returnPos) >= 100 then
        QBCore.Functions.Notify( "Where is your vehicle?", "error")
    elseif isJobVehicle(vehicle) and vehPlate == plate then
        if Config.UseDeposit then
            TriggerServerEvent('fs-dockjob:server:payDeposit', false)
        else
            TriggerEvent("fs-dockjob:client:deleteVehicle")
            QBCore.Functions.Notify( "Vehicle Returned!", "success")
        end
    else
        QBCore.Functions.Notify( "This is not the vehicle you received", "error")
    end
end)

RegisterNetEvent('fs-dockjob:client:retrieveForklift', function()
    local garage = Config.Locations["main"].garage
    local coords = vector3(garage.x, garage.y, garage.z)
    local maxDist = 10
    local isVehClose = zutils.GetClosestVehicle(maxDist)
    local _, distance = QBCore.Functions.GetClosestVehicle(coords)
    if distance <= maxDist then
        QBCore.Functions.Notify("There is a vehicle in the way!", "error")
        return
    else
        if Config.UseDeposit then
            TriggerServerEvent('fs-dockjob:server:payDeposit', true, "forklift")
        else
            TriggerEvent("fs-dockjob:client:spawnForklift")
        end
    end
end)

RegisterNetEvent('fs-dockjob:client:retrieveHandler', function()
    local garage = Config.Locations["main"].garage
    local coords = vector3(garage.x, garage.y, garage.z)
    local maxDist = 10
    local isVehClose = zutils.GetClosestVehicle(maxDist)
    local _, distance = QBCore.Functions.GetClosestVehicle(coords)
    if distance <= maxDist then
        QBCore.Functions.Notify( "There is a vehicle in the way!", "error")
        return
    else
        if Config.UseDeposit then
            TriggerServerEvent('fs-dockjob:server:payDeposit', true, "handler")
        else
            TriggerEvent("fs-dockjob:client:spawnHandler")
        end
    end
end)

RegisterNetEvent('fs-dockjob:client:spawnForklift', function()
    local coords = Config.Locations["main"].garage
    QBCore.Functions.SpawnVehicle("forklift", function(veh)
        SetVehicleNumberPlateText(veh, 'DOCK'.. tostring(math.random(1000,9999)))
        SetEntityHeading(veh, coords.w)
        exports[Config.Fuel]:SetFuel(veh, 100.0)
        TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
        vehPlate = GetVehicleNumberPlateText(veh)
    end, coords, true)
end)

RegisterNetEvent('fs-dockjob:client:spawnHandler', function()
    local coords = Config.Locations["main"].garage
    QBCore.Functions.SpawnVehicle("handler", function(veh)
        SetVehicleNumberPlateText(veh, 'DOCK'.. tostring(math.random(1000,9999)))
        SetEntityHeading(veh, coords.w)
        exports[Config.Fuel]:SetFuel(veh, 100.0)
        TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
        vehPlate = GetVehicleNumberPlateText(veh)
    end, coords, true)
end)

RegisterNetEvent('fs-dockjob:client:PaySlip', function()
    local istextuiopen = lib.isTextUIOpen()
    if istextuiopen then lib.hideTextUI() end
    if payOut > 0 and JobActive then
        QBCore.Functions.Notify("You finished the job early.", "error")
        TriggerServerEvent("fs-dockjob:server:givePay", payOut)
        ResetJob()
    elseif JobActive then
        QBCore.Functions.Notify("No work was completed", "error")
        ResetJob()
    elseif payOut > 0 and not JobActive then
        TriggerServerEvent("fs-dockjob:server:givePay", payOut)
        payOut = 0
        ResetJob()
    elseif onSpecialJob and JobActive then
        TriggerServerEvent("fs-dockjob:server:givePay", SpecialOrderId, onSpecialJob, false)
        ResetJob()
    elseif onSpecialJob and not JobActive then
        TriggerServerEvent("fs-dockjob:server:givePay", SpecialOrderId, onSpecialJob, true)
        ResetJob()
    else
        QBCore.Functions.Notify( "We aren't going to pay you for doing nothing..", "error")
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    PlayerJob = QBCore.Functions.GetPlayerData().job
    if PlayerJob.name == "dock" then
        CreateElements()
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, v in pairs(Targets) do exports['qb-target']:RemoveZone(v) end
    for _, v in pairs(Blips) do RemoveBlip(v) end
    ClearProps()
    ClearBlips()
    lib.hideTextUI()
    --for k, v in pairs(Peds) do DeleteEntity(v) end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerJob = QBCore.Functions.GetPlayerData().job
    if PlayerJob.name == "dock" then CreateElements() end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = QBCore.Functions.GetPlayerData().job
    if PlayerJob.name == "dock" then CreateElements() end
end)


 RegisterCommand("dockjobprints", function()
    print("OnSpecialJob: "..json.encode(onSpecialJob))
    print("JobActive: "..json.encode(JobActive))
    print("ContainersCompleted: "..json.encode(ContainersCompleted))
    print("PalletsCompleted: "..json.encode(PalletsCompleted))
    print("count: "..json.encode(count))
    print("maxJobs: "..json.encode(maxJobs))
    print("containerCount: "..json.encode(containerCount))
    print("palletCount: "..json.encode(palletCount))
    print("containerJobs: "..json.encode(containerJobs))
    print("palletJobs: "..json.encode(palletJobs))
    print("ContainersNotNeeded: "..json.encode(ContainersNotNeeded))
    print("PalletsNotNeeded: "..json.encode(PalletsNotNeeded))
    print("SpecialOrderId: "..json.encode(SpecialOrderId))
end)

-- Variables
local lastPallet = 0
local pallet = nil
-- Functions

local function isPalletCollected()
    CreateThread(function()
        while pickUp do
            local currentVehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            local targetPosition = GetEntityCoords(pallet)
            local vehiclePositon = GetEntityCoords(currentVehicle)
            if #(targetPosition - vehiclePositon) < 2.5 then
                TriggerEvent('fs-dockjob:client:collectPallet')
            end
            Wait(1000)
        end
    end)
end

local function isPalletDelivered()
    CreateThread(function()
        while dropOff do
            local palletPos = GetEntityCoords(pallet)
            local deliveryPos = vector3(CurrentLocation.x, CurrentLocation.y, CurrentLocation.z)
            local groundPos = GetEntityHeightAboveGround(pallet)
            if #(vector2(deliveryPos.x,deliveryPos.y) - vector2(palletPos.x,palletPos.y)) < 1 and groundPos <= 0.02  then
                TriggerEvent('fs-dockjob:client:deliverPallet')
                FreezeEntityPosition(pallet, true)
            end
            Wait(1000)
        end
    end)
end

local function drawPickupMarker(pallet)
    CreateThread(function()
        while pickUp do
            local palletPosition = GetEntityCoords(pallet)
            DrawMarker(0, palletPosition.x, palletPosition.y, palletPosition.z + 2.2, 0.0, 0.0, 0.0, 0.0, 0.0, w, 0.8, 0.8, 0.5, 255, 191, 0, 222, true, false, false, false, false, false, false)
            Wait(1)
        end
    end)
end

local function drawDropOffMarker(x, y, z, w)
    CreateThread(function()
        while drawDropOff do
            local palletPosition = GetEntityCoords(pallet)
            if #(vector2(palletPosition.x,palletPosition.y) - vector2(x,y)) < 1 then
                DrawMarker(43, x, y, z - 1, 0.0, 0.0, 0.0, 0.0, 0.0, w, 2.0, 2.0, 0.5, 50, 205, 50, 222, false, false, false, false, false, false, false)
            else
                DrawMarker(43, x, y, z - 1, 0.0, 0.0, 0.0, 0.0, 0.0, w, 2.0, 2.0, 0.5, 255, 191, 0, 222, false, false, false, false, false, false, false)
            end
            Wait(1)
        end
    end)
end

-- Events

RegisterNetEvent('fs-dockjob:client:startPallets', function()
    if JobActive then QBCore.Functions.Notify("You are already working..", "error") return end
    local istextuiopen = lib.isTextUIOpen()
    if istextuiopen then lib.hideTextUI() end
    if not onSpecialJob then
        maxJobs = math.random(Config.Pay["pallets"].min, Config.Pay["pallets"].max)
        palletJobs = maxJobs
    end
    currentJob = getRandomPickup("pallets")
    CurrentLocation.x = Config.Locations["pallets"]["pickup"][currentJob].coords.x
    CurrentLocation.y = Config.Locations["pallets"]["pickup"][currentJob].coords.y
    CurrentLocation.z = Config.Locations["pallets"]["pickup"][currentJob].coords.z
    CurrentLocation.w = Config.Locations["pallets"]["pickup"][currentJob].coords.w
    CurrentLocation.id = currentJob
    CreateZone("pallets", currentJob)
    lib.showTextUI("Pallets: "..palletCount .."/"..palletJobs, { position = 'right-center'})
    QBCore.Functions.Notify("Start picking up pallets..", "success")
    CurrentBlip = AddBlipForCoord(CurrentLocation.x, CurrentLocation.y, CurrentLocation.z)
    SetBlipSprite(CurrentBlip, 478)
    SetBlipColour(CurrentBlip, 3)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Pallet")
    EndTextCommandSetBlipName(CurrentBlip)
    SetBlipRoute(CurrentBlip, true)
    SetBlipRouteColour(CurrentBlip, 3)
    JobActive = true
    TriggerServerEvent('fs-dockjob:server:incrementCounter')
end)

RegisterNetEvent('fs-dockjob:client:spawnPallet', function(number)
    if DoesEntityExist(pallet) then
        Wait(1)
        while DoesEntityExist(pallet) do -- Waits for the previous entity to be deleted
            Wait(1)
        end
    end
    if JobActive and not ObjectSpawned then
        local palletModel = GetHashKey("prop_boxpile_06b")
        if not HasModelLoaded(palletModel) then
            RequestModel(palletModel)
            while not HasModelLoaded(palletModel) do
                Wait(1)
            end
        end
        pallet = CreateObject(
            palletModel,
            CurrentLocation.x,
            CurrentLocation.y,
            CurrentLocation.z,
        true)
        PlaceObjectOnGroundProperly(pallet)
        SetEntityHeading(pallet, CurrentLocation.w)
        ObjectSpawned = true
        pickUp = true
        isPalletCollected()
        drawPickupMarker(pallet)
    end
end)

RegisterNetEvent('fs-dockjob:client:collectPallet', function()
    QBCore.Functions.Notify( "Deliver the pallet to the delivery location", "success")
    currentJob = getRandomDropoff("pallets")
    CurrentLocation.x = Config.Locations["pallets"]["dropoff"][currentJob].coords.x
    CurrentLocation.y = Config.Locations["pallets"]["dropoff"][currentJob].coords.y
    CurrentLocation.z = Config.Locations["pallets"]["dropoff"][currentJob].coords.z
    CurrentLocation.w = Config.Locations["pallets"]["dropoff"][currentJob].coords.w
    if DoesBlipExist(CurrentBlip) then RemoveBlip(CurrentBlip) CurrentBlip = nil end
    CurrentBlip2 = AddBlipForCoord(CurrentLocation.x, CurrentLocation.y, CurrentLocation.z)
    SetBlipSprite(CurrentBlip2, 478)
    SetBlipColour(CurrentBlip2, 3)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Dropoff")
    EndTextCommandSetBlipName(CurrentBlip)
    SetBlipRoute(CurrentBlip2, true)
    SetBlipRouteColour(CurrentBlip2, 3)
    pickUp = false
    drawDropOff = true
    dropOff = true
    isPalletDelivered()
    drawDropOffMarker(CurrentLocation.x, CurrentLocation.y, CurrentLocation.z, CurrentLocation.w)
end)

RegisterNetEvent('fs-dockjob:client:deliverPallet', function()
    if dropOff then
        dropOff = false
        RemoveBlip(CurrentBlip2)
        if not onSpecialJob then
            payOut = payOut + Config.Pay["pallets"].pay
        end
        QBCore.Functions.Notify("Pallet delivered", "success")
        drawDropOff = false
        count = count + 1
        palletCount = palletCount + 1

        if (not onSpecialJob and count < maxJobs) or (onSpecialJob and palletCount < palletJobs) then
            local istextuiopen = lib.isTextUIOpen()
            if istextuiopen then lib.hideTextUI() end
            lib.showTextUI("Pallets: "..palletCount .."/"..palletJobs, { position = 'right-center'})
            currentJob = getRandomPickup("pallets")
            CurrentLocation.x = Config.Locations["pallets"]["pickup"][currentJob].coords.x
            CurrentLocation.y = Config.Locations["pallets"]["pickup"][currentJob].coords.y
            CurrentLocation.z = Config.Locations["pallets"]["pickup"][currentJob].coords.z
            CurrentLocation.w = Config.Locations["pallets"]["pickup"][currentJob].coords.w
            CurrentLocation.id = currentJob
            CreateZone("pallets", currentJob)
            CurrentBlip = AddBlipForCoord(CurrentLocation.x, CurrentLocation.y, CurrentLocation.z)
            SetBlipSprite(CurrentBlip, 478)
            SetBlipColour(CurrentBlip, 3)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName("Pallet")
            EndTextCommandSetBlipName(CurrentBlip)
            SetBlipRoute(CurrentBlip, true)
            SetBlipRouteColour(CurrentBlip, 3)
        else
            PalletsCompleted = true
            lib.hideTextUI()
            QBCore.Functions.Notify("We have no more pallets for you to deliver", "success")
            Wait(1500)
            if (not onSpecialJob) or (onSpecialJob and count == maxJobs and ContainersCompleted and (PalletsCompleted or PalletsNotNeeded)) then
                QBCore.Functions.Notify("Return to the HQ to get your paycheck", "success")
                lib.showTextUI("Return to HQ to get your Paycheck", { position = 'right-center'})
                ClearBlips()
                count = 0
                JobActive = false
                currentJob = nil
            elseif onSpecialJob and palletCount == palletJobs and not ContainersCompleted then
                QBCore.Functions.Notify("Go Pick Up Some Containers", "success")
                JobActive = false
                currentJob = nil
                TriggerEvent("fs-dockjob:client:startContainers")
            end
        end
        Wait(3000)
        DeleteObject(pallet)
        ObjectSpawned = false
    end
end)

local function startSpecialOrder(data)
    maxJobs = data.maxStops
    SpecialOrderId = data.id
    if JobActive then QBCore.Functions.Notify("You are already working on a job.", "error") return end
    containerJobs = math.random(1, maxJobs)
    palletJobs = maxJobs - containerJobs
    QBCore.Functions.Notify("Starting a special order with "..containerJobs.." containers and "..palletJobs.." pallets.", "success")
    TriggerEvent('fs-dockjob:client:startSpecialOrderJob', containerJobs, palletJobs)
    if containerJobs == 0 then
        ContainersNotNeeded = true
    elseif palletJobs == 0 then
        PalletsNotNeeded = true
    end
    JobActive = true
end

local function getRandomJobType(containerJobs, palletJobs)
    if containerJobs > 0 and palletJobs > 0 then
        local type = math.random(1, 2)
        return type == 1 and "containers" or "pallets"
    elseif containerJobs > 0 then
        return "containers"
    elseif palletJobs > 0 then
        return "pallets"
    end
end

RegisterNetEvent('fs-dockjob:client:startSpecialOrderJob', function(containerJobs, palletJobs)
    if JobActive then QBCore.Functions.Notify("You are already working on a job.", "error") return end
    onSpecialJob = true
    jobType = getRandomJobType(containerJobs, palletJobs)
    currentJob = getRandomPickup(jobType)
    CreateZone(jobType, currentJob)
    CurrentLocation.x = Config.Locations[jobType]["pickup"][currentJob].coords.x
    CurrentLocation.y = Config.Locations[jobType]["pickup"][currentJob].coords.y
    CurrentLocation.z = Config.Locations[jobType]["pickup"][currentJob].coords.z
    CurrentLocation.w = Config.Locations[jobType]["pickup"][currentJob].coords.w
    CurrentLocation.id = currentJob
    local istextuiopen = lib.isTextUIOpen()
    if istextuiopen then lib.hideTextUI() end
    lib.showTextUI("Start Delivering "..jobType, { position = 'right-center'})
    CurrentBlip = AddBlipForCoord(CurrentLocation.x, CurrentLocation.y, CurrentLocation.z)
    if jobType == "containers" then
        SetBlipSprite(CurrentBlip, 677)
    elseif jobType == "pallets" then
        SetBlipSprite(CurrentBlip, 478)
    end
    SetBlipColour(CurrentBlip, 3)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(jobType)
    EndTextCommandSetBlipName(CurrentBlip)
    SetBlipRoute(CurrentBlip, true)
    SetBlipRouteColour(CurrentBlip, 3)
    JobActive = true
    TriggerServerEvent('fs-dockjob:server:incrementCounter')
end)

RegisterNetEvent('fs-dockjob:client:startSpecialOrder', function(data)
    startSpecialOrder(data)
    TriggerServerEvent("jixel-logistics:server:assignJob", data)
end)

local function isContainerDelivered()
    CreateThread(function()
        while dropOff do
            local containerPos = GetEntityCoords(container)
            local deliveryPos = vector3(CurrentLocation.x, CurrentLocation.y, CurrentLocation.z)
            if #(deliveryPos - containerPos) <= 1.5 and not isAttached then
                TriggerEvent('fs-dockjob:client:deliverContainer')
            end
            Wait(1000)
        end
    end)
end

local function drawPickupMarker(container)
    CreateThread(function()
        while pickUp do
            local containerPosition = GetEntityCoords(container)
            DrawMarker(0, containerPosition.x, containerPosition.y, containerPosition.z + 3.5, 0.0, 0.0, 0.0, 0.0, 0.0, w, 0.8, 0.8, 0.8, 255, 191, 0, 222, true, false, false, false, false, false, false)
            Wait(1)
        end
    end)
end

local function drawDropOffMarker(x, y, z, w)
    CreateThread(function()
        while drawDropOff do
            local containerPosition = GetEntityCoords(container)
            if #(containerPosition - vector3(x,y,z)) <= 1.5 then
                DrawMarker(43, x, y, z - 1, 0.0, 0.0, 0.0, 0.0, 0.0, w, 2.8, 7.0, 0.5, 50, 205, 50, 222, false, false, false, false, false, false, false)
            else
                DrawMarker(43, x, y, z - 1, 0.0, 0.0, 0.0, 0.0, 0.0, w, 2.8, 7.0, 0.5, 255, 191, 0, 222, false, false, false, false, false, false, false)
            end
            Wait(1)
        end
    end)
end

-- Events

RegisterNetEvent('fs-dockjob:client:startContainers', function()
    if JobActive then QBCore.Functions.Notify("You are already working..","error") return end
    local istextuiopen = lib.isTextUIOpen()
    if istextuiopen then lib.hideTextUI() end
    if not onSpecialJob then
        maxJobs = math.random(Config.Pay["containers"].min, Config.Pay["containers"].max) -- Determines a random number of jobs
        containerJobs = maxJobs
    end
    currentJob = getRandomPickup("containers")
    CurrentLocation.x = Config.Locations["containers"]["pickup"][currentJob].coords.x
    CurrentLocation.y = Config.Locations["containers"]["pickup"][currentJob].coords.y
    CurrentLocation.z = Config.Locations["containers"]["pickup"][currentJob].coords.z
    CurrentLocation.w = Config.Locations["containers"]["pickup"][currentJob].coords.w
    CurrentLocation.id = currentJob
    CreateZone("containers", currentJob)
    lib.showTextUI("Containers: "..containerCount .."/"..containerJobs, { position = 'right-center'})
    QBCore.Functions.Notify("Start delivering containers.","success")
    CurrentBlip = AddBlipForCoord(CurrentLocation.x, CurrentLocation.y, CurrentLocation.z)
    SetBlipSprite(CurrentBlip, 677)
    SetBlipColour(CurrentBlip, 3)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Container")
    EndTextCommandSetBlipName(CurrentBlip)
    SetBlipRoute(CurrentBlip, true)
    SetBlipRouteColour(CurrentBlip, 3)
    JobActive = true
    TriggerServerEvent('fs-dockjob:server:incrementCounter')
end)

RegisterNetEvent('fs-dockjob:client:spawnContainer', function(number)
    if DoesEntityExist(container) then
        Wait(1)
        while DoesEntityExist(container) do -- Waits for the previous entity to be deleted
            Wait(1)
        end
    end
    if JobActive and not ObjectSpawned then
        local contProp = GetHashKey('prop_contr_03b_ld')
        if not HasModelLoaded(contProp) then
            RequestModel(contProp)
            while not HasModelLoaded(contProp) do
                Wait(1)
            end
        end
        container = CreateObject(
            contProp,
            CurrentLocation.x,
            CurrentLocation.y,
            CurrentLocation.z - 1,
        true)
        SetEntityHeading(container, CurrentLocation.w + 90)
        ObjectSpawned = true
        pickUp = true
        drawPickupMarker(container)
    end
end)

RegisterNetEvent('fs-dockjob:client:collectContainer', function()
    QBCore.Functions.Notify("Deliver the container to the delivery location.", "success")
    currentJob = getRandomDropoff("containers")
    CurrentLocation.x = Config.Locations["containers"]["dropoff"][currentJob].coords.x
    CurrentLocation.y = Config.Locations["containers"]["dropoff"][currentJob].coords.y
    CurrentLocation.z = Config.Locations["containers"]["dropoff"][currentJob].coords.z
    CurrentLocation.w = Config.Locations["containers"]["dropoff"][currentJob].coords.w
    if DoesBlipExist(CurrentBlip) then RemoveBlip(CurrentBlip) CurrentBlip = nil end
    CurrentBlip2 = AddBlipForCoord(CurrentLocation.x, CurrentLocation.y, CurrentLocation.z)
    SetBlipSprite(CurrentBlip2, 677)
    SetBlipColour(CurrentBlip2, 3)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Dropoff")
    EndTextCommandSetBlipName(CurrentBlip)
    SetBlipRoute(CurrentBlip2, true)
    SetBlipRouteColour(CurrentBlip2, 3)
    pickUp = false
    drawDropOff = true
    dropOff = true
    isContainerDelivered()
    drawDropOffMarker(CurrentLocation.x, CurrentLocation.y, CurrentLocation.z, CurrentLocation.w + 90)
end)

RegisterNetEvent('fs-dockjob:client:deliverContainer', function()
    if dropOff then
        dropOff = false
        RemoveBlip(CurrentBlip2)
        if not onSpecialJob then
            payOut = payOut + Config.Pay["containers"].pay
        end
        QBCore.Functions.Notify("Container delivered", "success")
        count = count + 1
        containerCount = containerCount + 1
        drawDropOff = false
        if (not onSpecialJob and count < maxJobs) or (onSpecialJob and containerCount < containerJobs) then
            local istextuiopen = lib.isTextUIOpen()
            if istextuiopen then lib.hideTextUI() end
            lib.showTextUI("Containers: "..containerCount .."/"..containerJobs, { position = 'right-center'})
            --QBCore.Functions.Notify("Collect the next container "..containerCount .."/"..containerJobs, "success")
            currentJob = getRandomPickup("containers")
            CurrentLocation.x = Config.Locations["containers"]["pickup"][currentJob].coords.x
            CurrentLocation.y = Config.Locations["containers"]["pickup"][currentJob].coords.y
            CurrentLocation.z = Config.Locations["containers"]["pickup"][currentJob].coords.z
            CurrentLocation.w = Config.Locations["containers"]["pickup"][currentJob].coords.w
            CurrentLocation.id = currentJob
            CreateZone("containers", currentJob)
            CurrentBlip = AddBlipForCoord(CurrentLocation.x, CurrentLocation.y, CurrentLocation.z)
            SetBlipSprite(CurrentBlip, 677)
            SetBlipColour(CurrentBlip, 3)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName("Container")
            EndTextCommandSetBlipName(CurrentBlip)
            SetBlipRoute(CurrentBlip, true)
            SetBlipRouteColour(CurrentBlip, 3)

        else
            QBCore.Functions.Notify("We have no more containers for you to deliver", "success")
            Wait(1500)
            lib.hideTextUI()
            ContainersCompleted = true
            if (not onSpecialJob) or (onSpecialJob and count == maxJobs and ContainersCompleted and PalletsCompleted) or (onSpecialJob and count == maxJobs and PalletsNotNeeded and ContainersCompleted) then
                QBCore.Functions.Notify("Return to the HQ to get your paycheck", "success")
                lib.showTextUI("Return to HQ to get your Paycheck", { position = 'right-center'})
                ClearBlips()
                count = 0
                JobActive = false
                currentJob = nil
            elseif onSpecialJob and containerCount == containerJobs and not PalletsCompleted then
                QBCore.Functions.Notify("Go Pick Up Some Pallets", "success")
                JobActive = false
                currentJob = nil
                TriggerEvent("fs-dockjob:client:startPallets")
            end
        end
        Wait(3000)
        DeleteObject(container)
        ObjectSpawned = false
    end
end)