
if Config.PoliceJob ~= 'qb-core' and Config.PoliceJob ~= 'auto' then return end
if Config.PoliceJob == 'auto' and GetResourceState('qb-core') ~= 'started' then return end
if IsPolice then return end

local QBCore = exports['qb-core']:GetCoreObject()

function IsPolice(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return false end
    local job = player.PlayerData.job.name
    for _, pg in ipairs(Config.PoliceGroups) do
        if job == pg then return true end
    end
    return false
end
