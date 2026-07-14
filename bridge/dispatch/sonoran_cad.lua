
if Config.Dispatch ~= 'sonoran_cad' and Config.Dispatch ~= 'auto' then return end
if Config.Dispatch == 'auto' and GetResourceState('sonorancad') ~= 'started' then return end

Dispatch = Dispatch or {}

local contractMeta = {
    car_theft           = { label = 'Car Theft'   },
    robbery_fleeca      = { label = 'Bank robbery'      },
    robbery_supermarket = { label = 'Store robbery'    },
    robbery_bobcat      = { label = 'Warehouse robbery'     },
    robbery_jewelry     = { label = 'Jewelry store robbery' },
    robbery_humanelabs  = { label = 'Humane Labs break-in' },
    robbery_truck       = { label = 'Gruppe 6 heist' },
    burglary            = { label = 'House burglary'  },
    atm                 = { label = 'ATM attack' },
}

local function getMeta(contractKey)
    return contractMeta[contractKey] or { label = 'Suspicious activity' }
end

local function getLocation(coords)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash) or 'Unknown street'
    local zone   = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    return (zone ~= '' and zone ~= 'NULL') and (street .. ', ' .. zone) or street
end

local function getPostal(coords)
    if GetResourceState('nearest-postal') == 'started' then
        return exports['nearest-postal']:getPostal(coords) or ''
    end
    return ''
end

local function buildMessage(contractKey, coords, extraData)
    local loc  = getLocation(coords)
    local male = IsPedMale(PlayerPedId())
    if contractKey == 'car_theft' and extraData then
        local verb = male and 'stole' or 'stole'
        return (male and 'A man' or 'A woman') .. ' ' .. verb .. ' a vehicle: ' ..
               (extraData.model or 'unknown') .. ', Color: ' .. (extraData.color or 'unknown') ..
               ', at ' .. loc
    elseif contractKey == 'burglary' then
        return 'An alarm was triggered at a property at ' .. loc
    elseif contractKey == 'robbery_fleeca' then
        return 'A Fleeca bank robbery is in progress at ' .. loc
    elseif contractKey == 'robbery_humanelabs' then
        return 'A security breach at Humane Labs at ' .. loc
    elseif contractKey == 'robbery_jewelry' then
        return 'A jewelry store robbery is in progress at ' .. loc
    elseif contractKey == 'robbery_bobcat' then
        return 'A Bobcat Security warehouse robbery is in progress at ' .. loc
    elseif contractKey == 'robbery_truck' then
        return 'A Gruppe 6 armored truck heist at ' .. loc
    elseif contractKey == 'robbery_supermarket' then
        return 'A store robbery at ' .. loc
    elseif contractKey == 'atm' then
        return 'An ATM attack at ' .. loc
    end
    return 'Suspicious activity at ' .. loc
end

function Dispatch.policeAlert(coords, radius, duration, contractKey)
    local meta = getMeta(contractKey)
    TriggerEvent('SonoranScripts::Call911', {
        location = getLocation(coords),
        postal   = getPostal(coords),
        message  = 'Suspicious activity - ' .. meta.label,
    })
end

function Dispatch.robbery(contractKey, coords, extraData)
    TriggerEvent('SonoranScripts::Call911', {
        location = getLocation(coords),
        postal   = getPostal(coords),
        message  = buildMessage(contractKey, coords, extraData),
    })
end
