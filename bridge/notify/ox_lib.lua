
if Config.Notify ~= 'ox_lib' and Config.Notify ~= 'auto' then return end
if Config.Notify == 'auto' and GetResourceState('ox_lib') ~= 'started' then return end
if Notify then return end

function Notify(msg, ntype)
    lib.notify({
        title       = 'Tablet',
        description = msg,
        type        = ntype or 'inform',
    })
end

RegisterNetEvent('m3_illegaltablet:cl:notify', function(msg, ntype)
    Notify(msg, ntype)
end)
