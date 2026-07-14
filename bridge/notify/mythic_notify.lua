
if Config.Notify ~= 'mythic_notify' and Config.Notify ~= 'auto' then return end
if Config.Notify == 'auto' and GetResourceState('mythic_notify') ~= 'started' then return end
if Notify then return end

local typeMap = {
    inform  = 'info',
    success = 'success',
    error   = 'error',
    warning = 'warning',
}

function Notify(msg, ntype)
    exports['mythic_notify']:DoHudText(typeMap[ntype] or 'info', msg)
end

RegisterNetEvent('m3_illegaltablet:cl:notify', function(msg, ntype)
    Notify(msg, ntype)
end)
