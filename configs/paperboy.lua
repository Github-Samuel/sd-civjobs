return {
    -- Paperboy ped configuration
    Ped = {
        model = 'a_m_y_hipster_01',
        coords = vector3(-604.84, -925.93, 23.35),
        heading =  178.1,
        scenario = 'PROP_HUMAN_SEAT_CHAIR_FOOD'
    },
    
    -- Blip configuration for paperboy location
    Blip = {
        enable = true,
        sprite = 590,
        display = 4,
        scale = 0.7,
        colour = 1,
        name = 'Paperboy Job'
    },
    
    -- Job locations for newspaper delivery
    JobLocations = {
        deliveryPoints = {
            vector3(-1037.8, -1396.87, 5.55),
            vector3(-1108.35, -1527.84, 6.78),
            vector3(-1405.74, -1308.73, 4.33),
            vector3(-1449.73, -1445.94, 5.13),
            vector3(-1308.05, -1525.25, 4.28),
            vector3(-1196.74, -1622.87, 4.37),
            vector3(-1065.05, -1159.36, 2.16),
            vector3(-1123.97, -1050.24, 2.16),
            vector3(-1277.94, -1123.26, 6.99),
            vector3(-1315.85, -1220.85, 4.84),
            vector3(-1392.74, -1279.85, 4.28),
            vector3(-1456.85, -1106.74, 4.28),
            vector3(-1523.74, -1387.85, 5.13),
            vector3(-1634.85, -1015.74, 13.12),
            vector3(-1789.74, -1193.85, 13.02)
        }
    },
    
    -- Distance constraints for job assignment
    Distance = {
        min = 50.0,  -- Minimum distance from player
        max = 800.0  -- Maximum distance from player
    },
    
    -- Time configuration based on player level (in seconds)
    Time = {
        [1] = 8,  -- Level 1: 8 seconds per delivery
        [2] = 6,  -- Level 2: 6 seconds per delivery
        [3] = 4   -- Level 3: 4 seconds per delivery
    },
    
    -- Payment configuration based on player level
    Payment = {
        [1] = {min = 15, max = 25},  -- Level 1: $15-25 per delivery
        [2] = {min = 20, max = 30},  -- Level 2: $20-30 per delivery
        [3] = {min = 25, max = 35}   -- Level 3: $25-35 per delivery
    },
    
    -- XP rewards per delivery
    XP = {
        [1] = 5,   -- Level 1: 5 XP per delivery
        [2] = 4,   -- Level 2: 4 XP per delivery
        [3] = 3    -- Level 3: 3 XP per delivery
    },
    
    -- Minigame configuration (if enabled)
    Minigame = {
        Enable = false,
        Start = function()
            -- Add your minigame logic here
            return true
        end
    },
    
    -- Job requirements
    Requirements = {
        minLevel = 1,
        maxActiveJobs = 1
    }
}