
if Config.Notify ~= 'qb-core' and Config.Notify ~= 'auto' then return end
if Config.Notify == 'auto' and GetResourceState('qb-core') ~= 'started' then return end
if Notify then return end

local typeMap = {
    inform  = 'primary',
    success = 'success',
    error   = 'error',
    warning = 'warning',
}

function Notify(msg, ntype)
    exports['qb-core']:Notify(msg, typeMap[ntype] or 'primary', 5000)
end

RegisterNetEvent('m3_illegaltablet:cl:notify', function(msg, ntype)
    Notify(msg, ntype)
end)
