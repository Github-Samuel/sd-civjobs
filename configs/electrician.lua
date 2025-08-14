return {
    Time = { -- Time in seconds to repair the electrical thing (progressbar time) by level
        [1] = 15, -- Level 1: 15 seconds (slower for beginners)
        [2] = 12, -- Level 2: 12 seconds (getting faster)
        [3] = 8,  -- Level 3: 8 seconds (experienced workers)
    },
    BaseXP = 20, -- Base XP awarded for every successful repair
    Logging = true, -- Enables lib.logger usage for this action. Will log a players source, character name and identifier as well as the action they took and the items and cash they received from it.
    Distance = { -- Distance from player to job location
        min = 200, -- Minimum distance from player for job locations (in units)
        max = 1200  -- Maximum distance from player for job locations (in units)
    },
    Ped = {
        model = "s_m_y_construct_01", -- Ped model for electrician job
        coords = vec3(735.22, 131.13, 80.72), -- Ped spawn coordinates
        heading = 243.41, -- Ped heading
        scenario = "WORLD_HUMAN_CLIPBOARD" -- Ped scenario/animation
    },
    Blip = {
        enable = true, -- Enable/disable blip for electrician
        sprite = 402, -- Blip sprite (electrician icon)
        display = 4, -- Blip display type
        scale = 0.8, -- Blip scale
        colour = 5, -- Blip colour (yellow)
        shortRange = true, -- Short range blip
        name = "Electrician Job" -- Blip name
    },
    Minigame = {
        Enable = true, -- Enable/disable custom minigame (if false, no minigame will be used)
        Start = function()
            -- Default minigame using lib.skillCheck
            -- You can replace this with any custom minigame that returns true/false
            return lib.skillCheck({ 'easy', 'easy', 'medium' }, { 'w', 'a', 's', 'd' })
        end,
    },
    Rewards = { -- Level-based cash rewards per lightpole/electricalbox
        [1] = { -- Level 1 rewards (basic)
            min = 3,
            max = 12
        },
        [2] = { -- Level 2 rewards (improved)
            min = 8,
            max = 20
        },
        [3] = { -- Level 3 rewards (advanced)
            min = 15,
            max = 35
        },
    },
    JobLocations = {
        electricalBoxes = {
            vector3(758.71, 136.91, 78.94),
            vector3(705.6367, 58.8237, 83.8642),
            vector3(534.3323, 64.3275, 96.2131),
            vector3(351.8224, -224.1157, 54.8941),
            vector3(287.4722, -443.9739, 43.6027),
            vector3(215.2995, -651.6578, 38.5628),
            vector3(171.3939, -767.0478, 32.2576),
            vector3(145.4662, -825.2324, 31.1370),
            vector3(100.5653, -969.2227, 29.3729),
            vector3(138.0711, -1027.7700, 29.3535),
            vector3(195.3668, -801.1793, 31.2464),
            vector3(101.0982, -1082.7650, 29.1924),
            vector3(-295.5944, -645.4796, 33.1992),
            vector3(-517.7743, -860.3887, 30.0168),
            vector3(-547.1727, -942.7381, 23.7900),
            vector3(-614.5042, -942.8254, 21.9555),
            vector3(391.6350, -998.5460, 29.4171),
            vector3(679.7724, -32.8730, 82.9715),
            vector3(891.1613, 41.8322, 78.7264),
            vector3(857.2255, -140.1125, 78.7231),
            vector3(147.6695, -1035.4513, 29.3431),
            vector3(295.5568, -896.0820, 29.2120),
            vector3(214.1687, -853.6418, 30.3870),
            vector3(301.1392, -1269.1143, 29.5181),
            vector3(-609.5130, -1091.6191, 22.3248),
            vector3(875.4760, -2092.6594, 30.5137),
            vector3(-32.9868, -1106.1160, 27.2744),
            vector3(-544.8131, -158.9713, 38.4763),
            vector3(-800.2009, -106.3099, 37.5652),
            vector3(-1231.0833, -327.7384, 37.4014),
        },
        lightPoles = {
            vector3(-551.6588, -1129.0857, 20.8235),
            vector3(-560.1828, -1170.5237, 18.8761),
            vector3(-548.5363, -1208.3710, 17.6060),
            vector3(-579.4396, -1249.6023, 13.0037),
            vector3(-492.0852, -886.3688, 28.8845),
            vector3(-518.3329, -898.7413, 26.7313),
            vector3(-545.9804, -848.8099, 28.6592),
            vector3(-591.7209, -822.8557, 26.0033),
            vector3(-625.5317, -789.5486, 25.5014),
            vector3(-649.6006, -765.9601, 25.5850),
            vector3(-626.6401, -743.8611, 27.1205),
            vector3(-625.8245, -705.2137, 29.9380),
            vector3(-649.1384, -523.7983, 34.7674),
            vector3(-648.4252, -454.8808, 34.7649),
            vector3(-648.3713, -427.6740, 34.7549),
            vector3(-366.9386, -214.9729, 36.7975),
            vector3(-322.5505, -205.3966, 38.2691),
            vector3(-295.5547, -128.0553, 44.3919),
            vector3(-254.8237, -102.4358, 47.3396),
            vector3(-189.8193, -86.4054, 52.0333),
            vector3(-149.9428, -99.6607, 54.8732),
            vector3(-118.3674, -115.9455, 57.0033),
            vector3(-100.3593, -135.1026, 57.1066),
            vector3(-105.5723, -163.0617, 52.3789),
            vector3(-84.0146, -204.0816, 46.0969),
            vector3(-62.8353, -233.0617, 45.2898),
            vector3(-20.7149, -249.4622, 46.4903),
            vector3(-11.0396, -278.7969, 47.0434),
            vector3(0.9895, -314.1552, 45.2844),
            vector3(-4.6938, -329.0912, 43.8214),
            vector3(-12.5725, -346.5074, 41.9250),
            vector3(-19.7043, -363.2916, 40.1392),
            vector3(-25.4335, -379.1754, 39.5803),
            vector3(-30.8930, -398.7482, 39.5821),
            vector3(-36.5694, -416.7940, 39.6487),
            vector3(-42.3636, -434.2610, 40.3077),
            vector3(234.3007, -344.0471, 44.3199),
            vector3(226.9315, -368.5648, 44.2571),
            vector3(249.2173, -376.7182, 44.5358),
            vector3(258.0720, -352.8329, 44.4264),
            vector3(275.2447, -357.7439, 44.9925),
            vector3(278.9476, -343.7706, 44.9199),
            vector3(283.1227, -333.6680, 45.0491),
            vector3(310.3891, -354.2664, 45.4989),
            vector3(320.4309, -324.2214, 49.9597),
            vector3(343.3829, -330.7163, 49.9429),
            vector3(352.9800, -302.4514, 53.6743),
            vector3(395.4480, -300.4277, 52.1029),
            vector3(434.8914, -316.0513, 49.1843),
            vector3(572.8895, -375.1989, 43.5427),
            vector3(556.4952, -366.9649, 43.5417),
            vector3(572.3959, -341.7330, 43.4141),
            vector3(629.8209, -366.4006, 43.4208),
            vector3(720.9906, -360.1858, 42.6311),
            vector3(789.4375, -335.1167, 51.0315),
            vector3(829.4061, -342.9150, 56.2015),
            vector3(869.2142, -326.6812, 61.8344),
            vector3(904.4443, -336.3840, 64.9340),
            vector3(930.9659, -314.3035, 66.7756),
            vector3(960.7884, -305.2511, 66.9758),
            vector3(922.7101, -272.3502, 67.9130),
            vector3(899.3472, -251.5761, 69.5527),
            vector3(881.2527, -238.9129, 69.5372),
            vector3(913.6987, -217.1942, 70.4682),
            vector3(911.6899, -194.4211, 72.6875),
            vector3(930.8046, -188.2672, 74.0616),
            vector3(958.2450, -174.6536, 73.7773),
            vector3(978.9091, -186.7567, 72.4108),
            vector3(998.1495, -199.6317, 70.9793),
            vector3(1002.0509, -214.7593, 70.1512),
            vector3(987.3096, -238.8771, 68.9383),
            vector3(992.3483, -256.9861, 68.0900),
            vector3(1005.2258, -235.5376, 69.6089),
            vector3(1025.6699, -221.9148, 70.2009),
            vector3(1041.5714, -198.0505, 70.1406),
            vector3(1022.5196, -185.2644, 70.1983),
            vector3(981.5439, -160.0752, 72.9779),
            vector3(950.1949, -140.6213, 74.4625),
            vector3(918.9393, -120.7635, 76.5311),
            vector3(890.5701, -102.4383, 79.0756),
            vector3(865.5899, -87.8903, 79.4315),
            vector3(830.0264, -60.2019, 80.5899),
            vector3(816.4561, -40.4184, 80.6036),
            vector3(839.7277, -6.4254, 80.2441),
            vector3(879.3683, 34.1863, 78.5994),
            vector3(905.7643, 64.5363, 79.0624),
            vector3(934.7473, 99.7601, 79.3104),
            vector3(1091.4597, -400.3493, 67.0405),
            vector3(1090.4558, -423.9743, 66.9569),
            vector3(1084.8285, -454.4443, 65.4485),
            vector3(1080.3566, -478.3326, 64.1822),
            vector3(1079.5923, -505.6194, 62.7974),
            vector3(1066.2421, -479.8404, 63.9208),
            vector3(1070.6561, -453.3162, 65.4492),
            vector3(1076.3809, -421.5247, 67.0852),
            vector3(321.7246, -1832.8213, 27.2255),
            vector3(341.0716, -1811.1515, 28.2244),
            vector3(372.2851, -1773.4904, 29.2456),
            vector3(402.4979, -1783.4458, 29.1283),
            vector3(147.7627, -1775.0447, 29.0993),
            vector3(150.7830, -1735.7582, 29.1990),
            vector3(86.3073, -1680.2175, 29.3127),
            vector3(94.5071, -1630.7369, 29.3100),
            vector3(126.8563, -1638.9791, 29.2760),
            vector3(119.8446, -1611.0109, 29.2973),
            vector3(145.7514, -1563.8248, 29.3656),
            vector3(112.3588, -1559.4120, 29.2595),
            vector3(106.1467, -1530.0858, 29.3096)
        }
    }
}