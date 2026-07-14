
if Config.Dispatch ~= 'cd_dispatch' and Config.Dispatch ~= 'auto' then return end
if Config.Dispatch == 'auto' and GetResourceState('cd_dispatch') ~= 'started' then return end

Dispatch = Dispatch or {}

local contractMeta = {
    car_theft           = { label = 'Car Theft',   code = '10-16', sprite = 56,  colour = 2 },
    robbery_fleeca      = { label = 'Bank robbery',      code = '10-30', sprite = 500, colour = 1 },
    robbery_supermarket = { label = 'Store robbery',    code = '10-30', sprite = 52,  colour = 1 },
    robbery_bobcat      = { label = 'Warehouse robbery',     code = '10-30', sprite = 110, colour = 1 },
    robbery_jewelry     = { label = 'Jewelry store robbery', code = '10-30', sprite = 617, colour = 5 },
    robbery_humanelabs  = { label = 'Humane Labs break-in', code = '10-30', sprite = 499, colour = 2 },
    robbery_truck       = { label = 'Gruppe 6 heist', code = '10-30', sprite = 477, colour = 1 },
    burglary            = { label = 'House burglary',  code = '10-68', sprite = 40,  colour = 3 },
    atm                 = { label = 'ATM attack', code = '10-30', sprite = 431, colour = 1 },
}

local function getMeta(contractKey)
    return contractMeta[contractKey] or { label = 'Suspicious activity', code = '10-90', sprite = 161, colour = 2 }
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

local function sendAlert(meta, coords, message, blipTime)
    local info = exports['cd_dispatch']:GetPlayerInfo()
    TriggerServerEvent('cd_dispatch:AddNotification', {
        job_table  = Config.PoliceGroups,
        coords     = coords,
        title      = meta.code .. ' | ' .. meta.label,
        message    = message,
        flash      = 0,
        unique_id  = info and info.unique_id or tostring(math.random(0, 9999999)),
        sound      = 1,
        blip = {
            sprite  = meta.sprite,
            scale   = 1.5,
            colour  = meta.colour,
            flashes = false,
            text    = meta.label,
            time    = blipTime or 10,
            radius  = 0,
        },
    })
end

function Dispatch.policeAlert(coords, radius, duration, contractKey)
    local meta = getMeta(contractKey)
    sendAlert(meta, coords, 'Suspicious activity nearby.', duration or 8)
end

function Dispatch.robbery(contractKey, coords, extraData)
    local meta = getMeta(contractKey)
    sendAlert(meta, coords, buildMessage(contractKey, coords, extraData), 15)
end
