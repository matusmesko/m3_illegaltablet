
if Config.PoliceJob ~= 'esx' and Config.PoliceJob ~= 'auto' then return end
if Config.PoliceJob == 'auto' and GetResourceState('es_extended') ~= 'started' then return end
if IsPolice then return end

local ESX = exports['es_extended']:getSharedObject()

function IsPolice(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local job = xPlayer:getJob().name
    for _, pg in ipairs(Config.PoliceGroups) do
        if job == pg then return true end
    end
    return false
end
