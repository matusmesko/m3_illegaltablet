
if Config.Dispatch ~= 'default' and Config.Dispatch ~= 'auto' then return end

Dispatch = Dispatch or {}

local contractMeta = {
    car_theft           = { label = 'Car Theft',     code = '10-16' },
    robbery_fleeca      = { label = 'Bank robbery',        code = '10-30' },
    robbery_supermarket = { label = 'Store robbery',      code = '10-30' },
    robbery_bobcat      = { label = 'Warehouse robbery',       code = '10-30' },
    robbery_jewelry     = { label = 'Jewelry store robbery', code = '10-30' },
    robbery_humanelabs  = { label = 'Humane Labs break-in', code = '10-30' },
    robbery_truck       = { label = 'Gruppe 6 heist', code = '10-30' },
    burglary            = { label = 'House burglary',    code = '10-68' },
    atm                 = { label = 'ATM attack',   code = '10-30' },
}

local function getLocation(coords)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash) or 'Unknown street'
    local zone   = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    return (zone ~= '' and zone ~= 'NULL') and (street .. ', ' .. zone) or street
end

local function buildMessage(contractKey, coords, extraData)
    local loc = getLocation(coords)
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
    elseif contractKey == 'robbery_supermarket' then
        return 'A store robbery at ' .. loc
    elseif contractKey == 'atm' then
        return 'An ATM attack at ' .. loc
    end
    return 'Suspicious activity at ' .. loc
end

function Dispatch.policeAlert(coords, radius, duration, contractKey)
    TriggerServerEvent('m3_illegaltablet:sv:policeAlert',
        coords.x, coords.y, coords.z, radius, duration or 8)
end

function Dispatch.robbery(contractKey, coords, extraData)
    TriggerServerEvent('m3_illegaltablet:sv:policeAlert',
        coords.x, coords.y, coords.z, 80.0, 10)
end
