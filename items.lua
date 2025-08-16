-- Add this item to your weapons.lua, not items.lua.
['WEAPON_ACIDPACKAGE'] = {
    label = 'Newspaper',
    weight = 0,
    throwable = true,
},

-- Add this to your regular items.lua (or replace if they already exist)
["diving_gear_1"] = {
    label = "Basic Scuba Gear",
    weight = 1000,
    stack = false,
    close = true,
    consume = 0,
    description = "Basic diving equipment with 120 seconds of oxygen. Use to put on diving suit.",
    client = {
        image = "diving_gear_1.png",
    },
    server = {
        export = 'sd-civjobs.useDivingGear'
    }
},

["diving_gear_2"] = {
    label = "Improved Scuba Gear",
    weight = 1000,
    stack = false,
    close = true,
    consume = 0,
    description = "Improved diving equipment with 180 seconds of oxygen. Use to put on diving suit.",
    client = {
        image = "diving_gear_2.png",
    },
    server = {
        export = 'sd-civjobs.useDivingGear'
    }
},

["diving_gear_3"] = {
    label = "Advanced Scuba Gear",
    weight = 1000,
    stack = false,
    close = true,
    consume = 0,
    description = "Advanced diving equipment with 240 seconds of oxygen. Use to put on diving suit.",
    client = {
        image = "diving_gear_3.png",
    },
    server = {
        export = 'sd-civjobs.useDivingGear'
    }
},

["diving_gear_4"] = {
    label = "Professional Scuba Gear",
    weight = 1000,
    stack = false,
    close = true,
    consume = 0,
    description = "Professional diving equipment with 300 seconds of oxygen. Use to put on diving suit.",
    client = {
        image = "diving_gear_4.png",
    },
    server = {
        export = 'sd-civjobs.useDivingGear'
    }
},

["diving_gear_5"] = {
    label = "Elite Scuba Gear",
    weight = 1000,
    stack = false,
    close = true,
    consume = 0,
    description = "Elite diving equipment with 360 seconds of oxygen. Use to put on diving suit.",
    client = {
        image = "diving_gear_5.png",
    },
    server = {
        export = 'sd-civjobs.useDivingGear'
    }
},

["diving_fill"] = {
    label = "Diving Tube",
    weight = 1000,
    stack = false,
    close = true,
    consume = 0,
    description = "Refill your oxygen tank with this diving tube.",
    client = {
        image = "diving_tube.png",
    },
    server = {
        export = 'sd-civjobs.useDivingFill'
    }
},