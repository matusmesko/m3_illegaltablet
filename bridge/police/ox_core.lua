
if Config.PoliceJob ~= 'ox_core' and Config.PoliceJob ~= 'auto' then return end
if Config.PoliceJob == 'auto' and GetResourceState('ox_core') ~= 'started' then return end
if IsPolice then return end

local Ox = exports.ox_core

local function GetCharId(src)
    local ok, player = pcall(function() return Ox:GetPlayer(src) end)
    if ok and player and player.charId then return player.charId end
    return nil
end

local activeCache = {}
local TTL = 5000

local function invalidate(src) activeCache[src] = nil end

AddEventHandler('playerDropped', function() invalidate(source) end)
AddEventHandler('ox:setActiveGroup', function(source) invalidate(source) end)
AddEventHandler('ox:setGroup',       function(source) invalidate(source) end)

function IsPolice(src)
    local now = GetGameTimer()
    local hit = activeCache[src]
    if hit and hit.expires > now then return hit.value end

    local value  = false
    local charId = GetCharId(src)
    if charId then
        local row = MySQL.single.await(
            'SELECT `name` FROM `character_groups` WHERE `charId` = ? AND `isActive` = 1 LIMIT 1',
            { charId })
        local active = row and row.name
        if active then
            for _, g in ipairs(Config.PoliceGroups) do
                if g == active then value = true; break end
            end
        end
        if Config.ContractDistribution and Config.ContractDistribution.debugLog then
            print(('[m3_illegaltablet] IsPolice player %d: active group=%s -> police=%s')
                :format(src, tostring(active), tostring(value)))
        end
    end

    activeCache[src] = { value = value, expires = now + TTL }
    return value
end
