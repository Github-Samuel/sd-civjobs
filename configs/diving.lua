return {
    -- Base XP awarded for each successful treasure find
    BaseXP = 15,
    -- Diving instructor ped configuration
    Ped = {
        model = 's_m_y_uscg_01', -- Coast Guard model for diving instructor
        coords = vector3(-1606.8, 5257.64, 3.97),
        heading = 112.56,
        scenario = 'WORLD_HUMAN_CLIPBOARD'
    },
    -- Blip configuration for diving location
    Blip = {
        enable = true,
        sprite = 729, -- Diving/water icon
        display = 4,
        scale = 0.8,
        colour = 3, -- Light blue
        name = 'Diving Job'
    },
    -- Reward configuration based on player level
    Rewards = {
        [1] = { -- Level 1: $50-100 per treasure
            min = 50, 
            max = 100
        },
        [2] = { -- Level 2: $75-150 per treasure
            min = 75, 
            max = 150
        },
        [3] = { -- Level 3: $100-200 per treasure
            min = 100, 
            max = 200
        } 
    },
    -- Boat rental configuration
    Boat = {
        model = 'dinghy4',
        spawnCoords = vector4(-1601.53, 5259.23, 0.13, 22.21), -- x, y, z, heading
        depositAmount = 500, -- Deposit required to rent boat
        returnAmount = 500   -- Amount returned when boat is returned
    },
    -- Diving locations with treasure spots
    DivingLocations = {
        [1] = {
            name = 'Plane Crash',
            coords = vector3(-942.35, 6608.75, -20.91),
            treasureSpots = {
                vector3(-898.54, 6647.70, -29.87),
                vector3(-914.73, 6668.00, -30.87),
                vector3(-990.02, 6704.83, -38.87),
                vector3(-843.70, 6665.69, -25.85)
            }
        },
        [2] = {
            name = 'UFO Crash',
            coords = vector3(759.68, 7393.15, -110.35),
            treasureSpots = {
                vector3(758.86, 7400.53, -114.82),
                vector3(773.90, 7364.62, -124.84),
                vector3(753.22, 7406.71, -130.96),
                vector3(758.31, 7383.98, -114.26)
            }
        },
        [3] = {
            name = 'WW2 Tank',
            coords = vector3(4201.63, 3643.82, -39.02),
            treasureSpots = {
                vector3(4213.61, 3652.73, -43.60),
                vector3(4213.90, 3641.90, -43.60),
                vector3(4206.03, 3647.48, -43.60),
                vector3(4209.17, 3639.26, -43.51)
            }
        },
        [4] = {
            name = 'Sunken Tug',
            coords = vector3(3413.27, 6305.62, -84.82),
            treasureSpots = {
                vector3(3413.27, 6305.62, -50.86),
                vector3(3402.68, 6313.88, -48.50),
                vector3(3394.03, 6334.40, -51.85),
                vector3(3403.59, 6327.88, -53.29)
            }
        },
        [5] = {
            name = 'Sunken Sub',
            coords = vector3(2676.36, 6659.03, -22.60),
            treasureSpots = {
                vector3(2676.36, 6659.03, -22.60),
                vector3(2666.44, 6643.21, -17.55),
                vector3(2647.23, 6682.92, -22.49),
                vector3(2640.56, 6691.36, -21.58)
            }
        },
        [6] = {
            name = 'Sunken Cargo Ship',
            coords = vector3(3199.75, -379.02, -22.50),
            treasureSpots = {
                vector3(3176.24, -332.58, -27.49),
                vector3(3156.46, -310.12, -21.49),
                vector3(3198.97, -374.25, -23.49),
                vector3(3149.90, -330.07, -25.49),
                vector3(3179.74, -352.23, -29.45),
                vector3(3203.57, -386.38, -17.75)
            }
        }
    },
    -- Scuba gear configuration
    Scuba = {
        startingOxygenLevel = 120, -- Starting oxygen in seconds
        refillTankTimeMs = 5000,   -- Time to refill tank
        putOnSuitTimeMs = 8000,    -- Time to put on suit
        takeOffSuitTimeMs = 6000   -- Time to take off suit
    },
    ScubaTiers = {
        [1] = {
            name = "Basic Scuba Gear",
            price = 150,
            levelRequired = 1,
            oxygenLevel = 120
        },
        [2] = {
            name = "Improved Scuba Gear",
            price = 250,
            levelRequired = 5,
            oxygenLevel = 180
        },
        [3] = {
            name = "Advanced Scuba Gear",
            price = 400,
            levelRequired = 10,
            oxygenLevel = 240
        },
        [4] = {
            name = "Professional Scuba Gear",
            price = 600,
            levelRequired = 15,
            oxygenLevel = 300
        },
        [5] = {
            name = "Elite Scuba Gear",
            price = 850,
            levelRequired = 20,
            oxygenLevel = 360
        }
    }
}