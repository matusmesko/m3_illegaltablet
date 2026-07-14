
if Config.Dispatch ~= 'rcore_dispatch' and Config.Dispatch ~= 'auto' then return end
if Config.Dispatch == 'auto' and GetResourceState('rcore_dispatch') ~= 'started' then return end

Dispatch = Dispatch or {}

local contractMeta = {
    car_theft           = { label = 'Car Theft',   code = '10-16', type = 'car_theft',    priority = 'medium' },
    robbery_fleeca      = { label = 'Bank robbery',      code = '10-30', type = 'bank_robbery', priority = 'high'   },
    robbery_supermarket = { label = 'Store robbery',    code = '10-30', type = 'robbery',      priority = 'high'   },
    robbery_bobcat      = { label = 'Warehouse robbery',     code = '10-30', type = 'robbery',      priority = 'high'   },
    robbery_jewelry     = { label = 'Jewelry store robbery', code = '10-30', type = 'robbery',    priority = 'high'   },
    robbery_humanelabs  = { label = 'Humane Labs break-in', code = '10-30', type = 'robbery', priority = 'high'   },
    robbery_truck       = { label = 'Gruppe 6 heist', code = '10-30', type = 'robbery',  priority = 'high'   },
    burglary            = { label = 'House burglary',  code = '10-68', type = 'burglary',     priority = 'medium' },
    atm                 = { label = 'ATM attack', code = '10-30', type = 'atm_robbery',  priority = 'high'   },
}

local function getMeta(contractKey)
    return contractMeta[contractKey] or { label = 'Suspicious activity', code = '10-90', type = 'suspicious', priority = 'low' }
end

local function getLocation(coords)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash) or 'Unknown street'
    local zone   = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    return (zone ~= '' and zone ~= 'NULL') and (street .. ', ' .. zone) or street
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
    TriggerServerEvent('rcore_dispatch:server:sendAlert', {
        coords   = coords,
        job      = Config.PoliceGroups,
        code     = meta.code,
        priority = meta.priority,
        message  = 'Suspicious activity - ' .. meta.label,
        type     = meta.type,
    })
end

function Dispatch.robbery(contractKey, coords, extraData)
    local meta = getMeta(contractKey)
    TriggerServerEvent('rcore_dispatch:server:sendAlert', {
        coords   = coords,
        job      = Config.PoliceGroups,
        code     = meta.code,
        priority = 'high',
        message  = buildMessage(contractKey, coords, extraData),
        type     = meta.type,
    })
end
