
if Config.Notify ~= 'okokNotify' and Config.Notify ~= 'auto' then return end
if Config.Notify == 'auto' and GetResourceState('okokNotify') ~= 'started' then return end
if Notify then return end

local typeMap = {
    inform  = 'info',
    success = 'success',
    error   = 'error',
    warning = 'warning',
}

function Notify(msg, ntype)
    exports['okokNotify']:Alert('Tablet', msg, 5000, typeMap[ntype] or 'info')
end

RegisterNetEvent('m3_illegaltablet:cl:notify', function(msg, ntype)
    Notify(msg, ntype)
end)
