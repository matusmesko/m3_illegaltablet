
if Config.Notify ~= 'esx_notify' and Config.Notify ~= 'auto' then return end
if Config.Notify == 'auto' and GetResourceState('esx_notify') ~= 'started' then return end
if Notify then return end

local typeMap = {
    inform  = 'info',
    success = 'success',
    error   = 'error',
    warning = 'warning',
}

function Notify(msg, ntype)
    exports['esx_notify']:Custom({
        text    = msg,
        type    = typeMap[ntype] or 'info',
        length  = 5000,
    })
end

RegisterNetEvent('m3_illegaltablet:cl:notify', function(msg, ntype)
    Notify(msg, ntype)
end)
