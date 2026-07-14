
if Config.PoliceJob ~= 'qbx-core' and Config.PoliceJob ~= 'auto' then return end
if Config.PoliceJob == 'auto' and GetResourceState('qbx_core') ~= 'started' then return end
if IsPolice then return end

function IsPolice(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    local job = player.PlayerData.job.name
    for _, pg in ipairs(Config.PoliceGroups) do
        if job == pg then return true end
    end
    return false
end
