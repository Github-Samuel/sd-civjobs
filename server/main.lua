local QBCore = exports['qb-core']:GetCoreObject()
local config = require('configs/main')

-- [[ Utility Functions ]]
--- Function to create coordinate key string
--- @param v vector3 Coordinate vector
--- @return string coordKey Formatted coordinate string
CoordsKey = function(v)
    return string.format('%.2f,%.2f,%.2f', v.x, v.y, v.z)
end

--- Function to get player's full name from character info
--- Function to get player object from QBCore
--- @param src number Player source ID
--- @return table player QBCore player object
GetPlayer = function(src)
    return QBCore.Functions.GetPlayer(src)
end

--- Function to get player identifier from source
--- @param src number Player source ID
--- @return string identifier Player's citizenid
GetIdentifier = function(src)
    local player = GetPlayer(src)
    if player and player.PlayerData and player.PlayerData.citizenid then
        return player.PlayerData.citizenid
    end
end

--- Function to get player's full name from character info
--- @param src number Player source ID
--- @return string fullName Player's first and last name
GetFullName = function(src)
    local player = GetPlayer(src)
    if player and player.PlayerData and player.PlayerData.charinfo then
        return player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
    end
end

--- Calculates a weighted chance selection based on the provided table of choices.
---@param tbl table The table containing choices with their associated weights.
---@return any The key of the chosen item based on weighted probability.
--- Function to calculate weighted chance selection
--- @param tbl table The table containing choices with their associated weights
--- @return any selectedKey The key of the chosen item based on weighted probability
WeightedChance = function(tbl)
    local total = 0
    for _, reward in pairs(tbl) do
        total = total + reward.chance
    end

    local rand = math.random() * total
    for k, reward in pairs(tbl) do
        rand = rand - reward.chance
        if rand <= 0 then
            return k
        end
    end
end

--- Function to get item label from ox_inventory
--- @param item string Item name
--- @return string label Item's display label
ItemLabel = function(item)
    return exports.ox_inventory:Items(item).label
end

-- [[ Level Logic ]]

-- Thread that queries the database for level information and populates the data table with the results
CreateThread(function()
    local success, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS civilianjobs (
                Identifier VARCHAR(255) NOT NULL,
                levelData JSON NOT NULL,
                Stats JSON NOT NULL,
                PRIMARY KEY (Identifier)
            );
        ]])
    end)
    if not success then
        print("Error creating database:", err)
    end

    local result = MySQL.query.await('SELECT * FROM civilianjobs', {})
    if result then
        levelData = result
    else
        print('^1Error: No records found or failed to query `civilianjobs` table.')
    end
end)

-- Function to calculate level based on XP for a specific job type
CalculateLevel = function(xp, jobType)
    xp = tonumber(xp) or 0
    
    if not config.Levels[jobType] then
        return 1
    end
    
    local jobConfig = config.Levels[jobType]
    local currentLevel = 1
    
    for level, settings in pairs(jobConfig) do
        if xp >= settings.xpRequired then
            currentLevel = math.max(currentLevel, level)
        end
    end
    
    return currentLevel
end

-- Function to retrieve level for a specific job type and identifier
GetPlayerLevel = function(identifier, jobType)
    for _, record in ipairs(levelData) do
        if record.Identifier == identifier then
            local playerData = json.decode(record.levelData) or {}
            local xp = playerData[jobType] or 0
            return CalculateLevel(xp, jobType)
        end
    end
    return 1 -- Default to level 1 if no data found
end

-- [[ Stats Logic ]]

--- Function to ensure a player has an entry in levelData, creates one if missing
--- @param identifier string The player's identifier
--- @return boolean success Whether the entry exists or was created successfully
EnsurePlayerEntry = function(identifier)
    for _, record in ipairs(levelData) do
        if record.Identifier == identifier then
            return true
        end
    end
    
    local newPlayerData = {
        Identifier = identifier,
        levelData = json.encode({}),
        Stats = json.encode({})
    }
    
    local success = pcall(function()
        MySQL.insert.await('INSERT INTO civilianjobs (Identifier, levelData, Stats) VALUES (?, ?, ?)', {
            identifier,
            json.encode({}),
            json.encode({})
        })
    end)
    
    if success then
        table.insert(levelData, newPlayerData)
        return true
    else
        return false
    end
end

--- Function to award XP to a player for a specific job type
--- @param identifier string The player's identifier
--- @param jobType string The type of job
--- @param xpAmount number The amount of XP to award
AwardXP = function(identifier, jobType, xpAmount)
    if not identifier or not jobType or not xpAmount then return false end
    
    for i, record in ipairs(levelData) do
        if record.Identifier == identifier then
            local playerLevelData = json.decode(record.levelData) or {}
            
            local currentXP = playerLevelData[jobType] or 0
            
            playerLevelData[jobType] = currentXP + xpAmount
            
            record.levelData = json.encode(playerLevelData)

            local dbSuccess = pcall(function()
                MySQL.update.await('UPDATE civilianjobs SET levelData = ? WHERE Identifier = ?', {
                    json.encode(playerLevelData),
                    identifier
                })
            end)
            
            return dbSuccess
        end
    end
    
    return false
end

--- Function to update the player's stats for a specific job type.
--- Increments a specific stat by a given amount under the specified job type.
--- @param identifier string The player's identifier.
--- @param jobType string The type of job (e.g., "electrician", "mechanic", etc.).
--- @param statName string The name of the stat to increment.
--- @param amount number The amount to increment.
UpdateStats = function(identifier, jobType, statName, amount)
    if not identifier or identifier == "" then
        return false
    end
    
    if not jobType or jobType == "" then
        return false
    end
    
    if not statName or statName == "" then
        return false
    end
    
    if not amount or type(amount) ~= "number" then
        return false
    end
    
    if not EnsurePlayerEntry(identifier) then
        return false
    end
    
    for i, record in ipairs(levelData) do
        if record.Identifier == identifier then
            local playerStats = json.decode(record.Stats) or {}
            
            if not playerStats[jobType] then
                playerStats[jobType] = {}
            end
            
            local currentValue = playerStats[jobType][statName] or 0
            
            playerStats[jobType][statName] = currentValue + amount
            
            record.Stats = json.encode(playerStats)

            local dbSuccess = pcall(function()
                MySQL.update.await('UPDATE civilianjobs SET Stats = ? WHERE Identifier = ?', {
                    json.encode(playerStats),
                    identifier
                })
            end)
            
            return true
        end
    end
    return false
end