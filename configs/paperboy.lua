return {
    -- Base XP awarded for each successful newspaper delivery
    BaseXP = 5,
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
    -- Reward configuration based on player level
    Rewards = {
        [1] = { -- Level 1: $15-25 per delivery
            min = 15, 
            max = 25
        },
        [2] = { -- Level 2: $20-30 per delivery
            min = 20, 
            max = 30
        },
        [3] = { -- Level 3: $25-35 per delivery
            min = 25, 
            max = 35
        } 
    },
    -- Delivery routes with specific areas
    DeliveryRoutes = {
        { -- Mirror Park
            name = "Mirror Park Route",
            locations = {
                vector3(1223.03, -696.92, 60.8),
                vector3(1229.6, -725.48, 60.95),
                vector3(1264.76, -702.82, 64.91),
                vector3(1270.91, -683.36, 66.03),
                vector3(1265.47, -647.9, 67.92),
                vector3(1240.56, -601.61, 69.78),
                vector3(1303.11, -527.98, 71.46),
                vector3(1301.16, -574.13, 71.73),
                vector3(1348.26, -547.11, 73.89),
                vector3(1388.88, -569.62, 74.5),
                vector3(1367.37, -606.3, 74.71),
                vector3(999.65, -593.97, 59.64),
            }
        },
        { -- Little Seoul
            name = "Little Seoul Route",
            locations = {
                vector3(-668.41, -971.42, 22.35),
                vector3(-741.53, -982.28, 17.44),
                vector3(-766.38, -916.99, 21.3),
                vector3(-728.57, -879.93, 22.71),
                vector3(-716.42, -864.61, 23.2),
            }
        },
        { -- Grove Street
            name = "Grove Street Route",
            locations = {
                vector3(-20.61, -1858.66, 25.41),
                vector3(46.04, -1864.3, 23.28),
                vector3(56.45, -1922.61, 21.91),
                vector3(85.26, -1958.87, 21.12),
                vector3(114.14, -1960.96, 21.33),
                vector3(103.96, -1885.28, 24.32),
                vector3(170.2, -1871.74, 24.4),
            }
        },
        { -- Beach Area
            name = "Beach Area Route",
            locations = {
                vector3(-1246.52, -1182.79, 7.66),
                vector3(-1285.27, -1253.32, 4.52),
                vector3(-1225.62, -1208.05, 8.27),
                vector3(-1087.14, -1277.54, 5.84),
                vector3(-1084.37, -1559.32, 4.78),
                vector3(-988.85, -1575.71, 5.23),
            }
        },
        { -- Mirror Park 2
            name = "Mirror Park 2 Route",
            locations = {
                vector3(1060.63, -378.30, 67.24),
                vector3(1010.23, -423.59, 64.35),
                vector3(1028.81, -409.67, 64.95),
                vector3(1056.19, -449.07, 65.26),
                vector3(893.20, -540.62, 57.51),
                vector3(850.28, -532.66, 56.93),
                vector3(861.73, -583.54, 57.16),
                vector3(980.31, -627.75, 58.24),
                vector3(959.95, -669.93, 57.45),
                vector3(996.79, -729.64, 56.82)
            }
        }
    },
}