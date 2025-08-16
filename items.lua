-- Add this item to your weapons.lua, not items.lua.
['WEAPON_ACIDPACKAGE'] = {
    label = 'Newspaper',
    weight = 0,
    throwable = true,
},

-- Add this to your regular items.lua (or replace if they already exist)
["diving_gear"] = {
    label = "Diving Gear",
    weight = 1000,
    stack = false,
    close = true,
    consume = 0,
    description = "An oxygen tank and a rebreather. Use to put on diving suit.",
    client = {
        image = "diving_gear.png",
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