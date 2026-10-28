
local module = {}

module.Duration = 11.9

module.Keys = {
    { Time = 0.00, Brightness = 0.00, Color = Color3.fromRGB(0, 0, 0) },
    { Time = 0.12, Brightness = 0.25, Flicker = true, Color = Color3.fromRGB(160, 155, 165) },
    { Time = 0.50, Brightness = 1.00, Flicker = true, Color = Color3.fromRGB(210, 207, 214) },
    { Time = 0.75, Brightness = 0.10, Flicker = true, Color = Color3.fromRGB(82,  77,  85)  },
    { Time = 1.00, Brightness = 0.48, Flicker = true, Color = Color3.fromRGB(172, 168, 177) },
    { Time = 1.25, Brightness = 0.11, Flicker = true, Color = Color3.fromRGB(85,  82,  91)  },
    { Time = 1.45, Brightness = 0.47, Flicker = true, Color = Color3.fromRGB(169, 165, 174) },
    { Time = 1.75, Brightness = 0.13,                  Color = Color3.fromRGB(130, 126, 157) },
    { Time = 1.90, Brightness = 0.34,                  Color = Color3.fromRGB(45,  50,  200) },
    { Time = 2.00, Brightness = 0.58,                  Color = Color3.fromRGB(75,  87,  218) },
    { Time = 2.50, Brightness = 0.47,                  Color = Color3.fromRGB(61,  58,  199) },
    { Time = 4.00, Brightness = 0.49,                  Color = Color3.fromRGB(74,  72,  205) },
    { Time = 4.25, Brightness = 0.86,                  Color = Color3.fromRGB(131, 122, 218) },
    { Time = 4.40, Brightness = 0.86,                  Color = Color3.fromRGB(165, 155, 177) },
    { Time = 4.50, Brightness = 0.12,                  Color = Color3.fromRGB(61,  0,   1)   },
    { Time = 4.75, Brightness = 0.03,                  Color = Color3.fromRGB(48,  68,  38)  },
    { Time = 5.40, Brightness = 0.11,                  Color = Color3.fromRGB(41,  37,  42)  },
    { Time = 5.80, Brightness = 0.05,                  Color = Color3.fromRGB(51,  16,  42)  },
    { Time = 6.40, Brightness = 0.06,                  Color = Color3.fromRGB(26,  16,  70)  },
    { Time = 6.63, Brightness = 0.28, Flicker = true, Color = Color3.fromRGB(152, 143, 156) },
    { Time = 7.60, Brightness = 0.28, Flicker = true, Color = Color3.fromRGB(152, 146, 153) },
    { Time = 7.90, Brightness = 0.06,                  Color = Color3.fromRGB(180, 0,   2)   },
    { Time = 8.10, Brightness = 0.37,                  Color = Color3.fromRGB(203, 96,  122) },
    { Time = 8.90, Brightness = 0.40,                  Color = Color3.fromRGB(224, 100, 127) },
    { Time = 9.05, Brightness = 0.18,                  Color = Color3.fromRGB(198, 15,  18)  },
    { Time = 9.50, Brightness = 0.47,                  Color = Color3.fromRGB(232, 0,   1)   },
    { Time = 9.65, Brightness = 0.15,                  Color = Color3.fromRGB(255, 0,   6)   },
    { Time = 10.05, Brightness = 0.27,                 Color = Color3.fromRGB(250, 0,   4)   },
    { Time = 10.22, Brightness = 0.00,                 Color = Color3.fromRGB(0,   0,   0)   }
}

function module.sample(currentTime)
    local keys = module.Keys

    if currentTime <= keys[1].Time then
        local firstKey = keys[1]
        return firstKey.Color, firstKey.Brightness, firstKey.Flicker == true
    end

    for i = 1, #keys - 1 do
        local currentKey = keys[i]
        local nextKey = keys[i + 1]

        if currentTime >= currentKey.Time and currentTime < nextKey.Time then
            local alpha = (currentTime - currentKey.Time) / (nextKey.Time - currentKey.Time)
            
            local hasFlicker = currentKey.Flicker == true or nextKey.Flicker == true

            return currentKey.Color:Lerp(nextKey.Color, alpha),
                   currentKey.Brightness + (nextKey.Brightness - currentKey.Brightness) * alpha,
                   hasFlicker
        end
    end

    local lastKey = keys[#keys]
    return lastKey.Color, lastKey.Brightness, lastKey.Flicker == true
end

return module
