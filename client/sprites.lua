-- Load main configuration for sprite settings
local mainConfig = require('configs/main')
local spriteConfig = mainConfig.Sprites

-- Cache sprite colors from config
local spriteColor = spriteConfig.colors.background
local textColor = spriteConfig.colors.text

-- Cache native functions for performance optimization
local DoesEntityExist = DoesEntityExist
local GetOffsetFromEntityInWorldCoords = GetOffsetFromEntityInWorldCoords
local GetWorldPositionOfEntityBone = GetWorldPositionOfEntityBone
local GetEntityCoords = GetEntityCoords
local SetDrawOrigin = SetDrawOrigin
local GetScreenCoordFromWorldCoord = GetScreenCoordFromWorldCoord
local DrawSprite = DrawSprite
local BeginTextCommandDisplayText = BeginTextCommandDisplayText
local AddTextComponentSubstringPlayerName = AddTextComponentSubstringPlayerName
local SetTextScale = SetTextScale
local SetTextCentre = SetTextCentre
local SetTextColour = SetTextColour
local EndTextCommandDisplayText = EndTextCommandDisplayText
local ClearDrawOrigin = ClearDrawOrigin
local IsControlJustReleased = IsControlJustReleased
local GetAspectRatio = GetAspectRatio

-- Cache math functions for performance
local math_exp = math.exp

-- Initialize runtime texture dictionary for sprites
local txd = CreateRuntimeTxd(cache.resource)
CreateRuntimeTextureFromImage(txd, 'hex', 'assets/hex.png')
CreateRuntimeTextureFromImage(txd, 'circle', 'assets/circle.png')

--- Function to create a sprite interaction object
--- @param data table Sprite configuration data
--- @return table|nil sprite Sprite object with draw method or nil if invalid data
CreateSprite = function(data)
    if not data or type(data) ~= 'table' then 
        print("^1[Civilian Jobs] Invalid sprite data provided^0")
        return nil
    end

    -- Set default values from config
    data.text = data.text or ''
    data.range = data.range or spriteConfig.defaultRange
    data.ratio = GetAspectRatio(true)

    --- Draw method for the sprite
    --- @param pedCoords vector3 Player coordinates (optional)
    --- @param options table Drawing options (optional)
    data.draw = function(self, pedCoords, options)
        local coords = nil
        
        -- Determine sprite coordinates based on available data
        if self.coords then
            coords = self.coords
        elseif options and options.targetCoords then
            coords = options.targetCoords
        elseif self.entity and DoesEntityExist(self.entity) then
            if self.boneIndex then
                coords = GetWorldPositionOfEntityBone(self.entity, self.boneIndex)
            elseif self.offset then
                coords = GetOffsetFromEntityInWorldCoords(self.entity, self.offset.x, self.offset.y, self.offset.z)
            else
                coords = GetEntityCoords(self.entity)
            end
        else
            return -- No valid coordinates found
        end

        -- Get player coordinates and calculate distance
        pedCoords = pedCoords or GetEntityCoords(cache.ped)
        local distance = #(pedCoords - coords)

        -- Only draw sprite if within interaction range
        if distance <= self.range then
            SetDrawOrigin(coords.x, coords.y, coords.z)

            -- Check if text should be hidden
            if options and options.hideText then
                -- Draw simple circle sprite without text
                DrawSprite(
                    cache.resource, 
                    'circle', 
                    0, 0, 
                    spriteConfig.circleSize, 
                    spriteConfig.circleSize * self.ratio, 
                    0.0, 
                    spriteColor.r, spriteColor.g, spriteColor.b, spriteColor.a
                )
            else
                -- Get screen coordinates for visibility check
                local _, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
                local inScreen = x > spriteConfig.screenBounds.minX and y > spriteConfig.screenBounds.minY and 
                               x < spriteConfig.screenBounds.maxX and y < spriteConfig.screenBounds.maxY
                
                -- Draw detailed sprite with text if close and on screen
                if inScreen and distance < spriteConfig.closeRange then
                    local scale = spriteConfig.hexScaleMultiplier * math_exp(-0.2 * distance)
                    
                    -- Draw hex sprite background
                    DrawSprite(
                        cache.resource, 
                        'hex', 
                        0, 0, 
                        scale, 
                        scale * self.ratio, 
                        0.0, 
                        spriteColor.r, spriteColor.g, spriteColor.b, spriteColor.a
                    )

                    -- Draw text on sprite
                    BeginTextCommandDisplayText('STRING')
                    AddTextComponentSubstringPlayerName(self.text)
                    SetTextScale(1.0, scale * spriteConfig.textScaleMultiplier)
                    SetTextCentre(true)
                    SetTextColour(textColor.r, textColor.g, textColor.b, textColor.a)
                    EndTextCommandDisplayText(0, -(scale * spriteConfig.textOffset))

                    -- Handle interaction if configured
                    if self.onInteract and self.onInteract.controlId and self.onInteract.cb and 
                       IsControlJustReleased(0, self.onInteract.controlId) then
                        self.onInteract.cb(self)
                    end
                else
                    -- Draw simple circle sprite when far or off-screen
                    DrawSprite(
                        cache.resource, 
                        'circle', 
                        0, 0, 
                        spriteConfig.circleSize, 
                        spriteConfig.circleSize * self.ratio, 
                        0.0, 
                        spriteColor.r, spriteColor.g, spriteColor.b, spriteColor.a
                    )
                end
            end

            ClearDrawOrigin()
        end
    end

    return data
end
