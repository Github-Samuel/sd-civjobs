return {
    Stats = {
        Enable = true,
    },
    -- Sprite interaction system configuration
    Sprites = {
        -- Sprite visual settings
        colors = {
            background = {r = 255, g = 255, b = 255, a = 200}, -- White background with transparency
            text = {r = 0, g = 0, b = 0, a = 255} -- Black text
        },
        -- Sprite behavior settings
        defaultRange = 10.0, -- Default interaction range in units
        closeRange = 1.5, -- Range for detailed sprite display
        screenBounds = { -- Screen area bounds for sprite visibility
            minX = 0.2,
            minY = 0.2,
            maxX = 0.8,
            maxY = 0.8
        },
        -- Sprite sizing
        circleSize = 0.0155, -- Size of circle sprite
        hexScaleMultiplier = 0.05, -- Base scale for hex sprite
        textScaleMultiplier = 6, -- Text scale multiplier
        textOffset = 0.25 -- Text vertical offset
    },
    Levels = {
        electrician = {
            [1] = {
                -- Starting level - no XP threshold required
                xpRequired = 0,
            },
            [2] = {
                xpRequired = 100,
            },
            [3] = {
                xpRequired = 250,
            }
        },
        payphone = {
            [1] = {
                xpRequired = 0,
            },
            [2] = {
                xpRequired = 120,
            },
            [3] = {
                xpRequired = 250,
            }
        },
        parkingmeter = {
            [1] = {
                xpRequired = 0,
            },
            [2] = {
                xpRequired = 180,
            },
            [3] = {
                xpRequired = 350,
            }
        },
        pickpocket = {
            [1] = {
                xpRequired = 0,
            },
            [2] = {
                xpRequired = 100,
            },
            [3] = {
                xpRequired = 200,
            }
        },
        robaped = {
            [1] = {
                xpRequired = 0,
            },
            [2] = {
                xpRequired = 200,
            },
            [3] = {
                xpRequired = 400,
            }
        },
        shoplift = {
            [1] = {
                xpRequired = 0,
            },
            [2] = {
                xpRequired = 80,
            },
            [3] = {
                xpRequired = 160,
            }
        },
        paperboy = {
            [1] = {
                xpRequired = 0,
            },
            [2] = {
                xpRequired = 150,
            },
            [3] = {
                xpRequired = 300,
            }
        },
        diving = {
            [1] = {
                xpRequired = 0,
            },
            [2] = {
                xpRequired = 200,
            },
            [3] = {
                xpRequired = 400,
            }
        }
    }
}