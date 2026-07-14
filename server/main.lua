
local Ox    = exports.ox_core
local OxInv = exports.ox_inventory

local function GetIdentifier(src)
    local player = Ox:GetPlayer(src)
    return player and tostring(player.charId) or nil
end

local function GetOxPlayer(src)
    return Ox:GetPlayer(src)
end

function GetPlayerFullName(src)
    local player = Ox:GetPlayer(src)
    if not player then return GetPlayerName(src) end

    local first = player.firstName or player.first_name or ''
    local last  = player.lastName  or player.last_name  or ''
    local full  = (first .. ' ' .. last):match('^%s*(.-)%s*$')
    return full ~= '' and full or GetPlayerName(src)
end

local function GiveMoney(src, amount)
    OxInv:AddItem(src, 'money', amount)
end

local function RemoveMoney(src, amount)
    local count = OxInv:GetItemCount(src, 'money') or 0
    if count < amount then return false end
    OxInv:RemoveItem(src, 'money', amount)
    return true
end

local function GiveItem(src, item, count)
    OxInv:AddItem(src, item, count)
end

if Config.UseItem then

    exports('useTablet', function(event, item, inventory, slot, data)
        if event ~= 'usingItem' then return false end
        local src = inventory.id
        TriggerClientEvent('m3_illegaltablet:cl:useTabletItem', src)
        return false
    end)
end

local function RemoveItem(src, item, count)
    OxInv:RemoveItem(src, item, count)
end

local function GetItemCount(src, item)
    return OxInv:GetItemCount(src, item) or 0
end

function Notify(src, msg, ntype)
    TriggerClientEvent('m3_illegaltablet:cl:notify', src, msg, ntype or 'inform')
end

playerData    = {}
playerIdToSrc = {}

local function DefaultPD()
    return {
        redXP           = 0,
        greenXP         = 0,
        contractFilter  = nil,
        offers          = {},
        nextRotation    = 0,
        playerId        = 0,
    }
end

local function GenerateUniquePlayerId(cb)
    local function tryId()
        local pid = math.random(1000, 9999)
        MySQL.single('SELECT identifier FROM m3_tablet WHERE player_id = ?', { pid }, function(row)
            if row then tryId()
            else        cb(pid)
            end
        end)
    end
    tryId()
end

function GetSrcByPlayerId(pid)
    pid = tonumber(pid)
    if not pid then return nil end

    local cached = playerIdToSrc[pid]
    if cached and GetPlayerName(cached) ~= nil then
        return cached
    end

    for _, src in ipairs(GetPlayers()) do
        local s = tonumber(src)
        local oxPlayer = Ox:GetPlayer(s)
        if oxPlayer then
            local id = tostring(oxPlayer.charId)
            local pd = playerData[id]
            if pd and pd.playerId == pid then
                playerIdToSrc[pid] = s
                return s
            end
        end
    end

    local row = MySQL.single.await(
        'SELECT identifier FROM m3_tablet WHERE player_id = ?', { pid })
    if not row then return nil end

    local dbIdentifier = tostring(row.identifier)
    for _, src in ipairs(GetPlayers()) do
        local s = tonumber(src)
        local oxPlayer = Ox:GetPlayer(s)
        if oxPlayer then
            local charId = tostring(oxPlayer.charId)

            if charId == dbIdentifier then
                playerIdToSrc[pid] = s
                return s
            end

            local identifiers = GetPlayerIdentifiers(s)
            for _, ident in ipairs(identifiers) do
                if ident == dbIdentifier then
                    playerIdToSrc[pid] = s
                    return s
                end
            end
        end
    end
    return nil
end

local function LoadPlayerData(identifier, cb)
    MySQL.single('SELECT * FROM m3_tablet WHERE identifier = ?', { identifier },
        function(row)
            if row then

                local rawFilter = row.contract_filter
                local decodedFilter
                if rawFilter and rawFilter ~= '' and rawFilter ~= 'null' then
                    local parsed = json.decode(rawFilter)
                    decodedFilter = (type(parsed) == 'table') and parsed or nil
                else
                    decodedFilter = nil
                end

                local pd = {
                    name           = row.name            or '',
                    redXP          = row.boosting_xp     or 0,
                    greenXP        = row.burglary_xp     or 0,
                    contractFilter = decodedFilter,
                    offers         = json.decode(row.offers          or '[]'),
                    nextRotation   = row.next_rotation   or 0,
                    playerId       = row.player_id       or 0,
                }

                if pd.playerId == 0 then
                    GenerateUniquePlayerId(function(newId)
                        pd.playerId = newId
                        if pd.name == '' then
                            pd.name = 'user_' .. string.format('%04d', newId)
                        end
                        MySQL.execute('UPDATE m3_tablet SET player_id=?, name=? WHERE identifier=?',
                            { newId, pd.name, identifier })
                        cb(pd)
                    end)
                else

                    if pd.name == '' then
                        pd.name = 'user_' .. string.format('%04d', pd.playerId)
                        MySQL.execute('UPDATE m3_tablet SET name=? WHERE identifier=?',
                            { pd.name, identifier })
                    end
                    cb(pd)
                end
            else

                GenerateUniquePlayerId(function(newId)
                    local defaultName = 'user_' .. string.format('%04d', newId)
                    MySQL.execute(
                        'INSERT INTO m3_tablet (identifier, name, boosting_xp, burglary_xp, contract_filter, offers, next_rotation, player_id) VALUES (?,?,0,0,?,?,0,?)',
                        { identifier, defaultName, '[]', '[]', newId })
                    local pd = DefaultPD()
                    pd.playerId = newId
                    pd.name     = defaultName
                    cb(pd)
                end)
            end
        end)
end

local function SavePlayerData(identifier, pd)
    MySQL.execute(
        [[UPDATE m3_tablet SET
            name=?, boosting_xp=?, burglary_xp=?,
            contract_filter=?, offers=?, next_rotation=?,
            player_id=?
          WHERE identifier=?]],
        {
            pd.name or '',
            pd.redXP,
            pd.greenXP,
            pd.contractFilter ~= nil and json.encode(pd.contractFilter) or '[]',
            json.encode(pd.offers),
            pd.nextRotation,
            pd.playerId or 0,
            identifier,
        })
end

function GetPD(src)
    local id = GetIdentifier(src)
    return id and playerData[id], id
end

AddEventHandler('ox:playerLoaded', function(source, charId, isNew)
    local id = tostring(charId)
    if playerData[id] then
        if playerData[id].playerId and playerData[id].playerId > 0 then
            playerIdToSrc[playerData[id].playerId] = source
        end
        return
    end
    LoadPlayerData(id, function(data)
        playerData[id] = data
        if data.playerId and data.playerId > 0 then
            playerIdToSrc[data.playerId] = source
        end
    end)
end)

AddEventHandler('ox:playerLogout', function(source, charId)
    local id = tostring(charId)
    if playerData[id] then
        if playerData[id].playerId then
            playerIdToSrc[playerData[id].playerId] = nil
        end
        SavePlayerData(id, playerData[id])
        playerData[id] = nil
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    FreeBurglaryLoc(src)
    CleanupTruckHeist(src, true)
    CleanupJewelryHeist(src, true)
    CleanupLabsHeist(src, true)
    local id = GetIdentifier(src)
    if id and playerData[id] then
        if playerData[id].playerId then
            playerIdToSrc[playerData[id].playerId] = nil
        end
        SavePlayerData(id, playerData[id])
        playerData[id] = nil
    end
end)

CreateThread(function()
    Wait(500)
    if not Config.CarHackItem then return end

    exports.ox_inventory:registerHook('usingItem', function(payload)
        TriggerClientEvent('m3_illegaltablet:cl:carHackItemUsed', payload.source)
        return false
    end, {
        itemFilter = { [Config.CarHackItem] = true }
    })
end)

local crewVehicleBlipCache = {}

RegisterNetEvent('m3_illegaltablet:sv:crewVehicleBlip', function(bx, by)
    local src = source
    crewVehicleBlipCache[src] = { bx = bx, by = by }
    if not activeCrew[src] then return end
    for _, msrc in ipairs(activeCrew[src].members) do
        TriggerClientEvent('m3_illegaltablet:cl:crewVehicleBlip', msrc, bx, by)
    end
end)

local crewVehicleCache = {}

RegisterNetEvent('m3_illegaltablet:sv:crewVehicleReady', function(netId)
    local src = source
    crewVehicleCache[src] = netId
    if not activeCrew[src] then return end
    for _, msrc in ipairs(activeCrew[src].members) do
        TriggerClientEvent('m3_illegaltablet:cl:crewVehicleReady', msrc, netId)
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:requestCrewVehicle', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local netId     = crewVehicleCache[leaderSrc]
    if netId then
        TriggerClientEvent('m3_illegaltablet:cl:crewVehicleReady', src, netId)
    end
    local blip = crewVehicleBlipCache[leaderSrc]
    if blip then
        TriggerClientEvent('m3_illegaltablet:cl:crewVehicleBlip', src, blip.bx, blip.by)
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:crewVehicleLockpicked', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local function relay(t)
        if t ~= src then
            TriggerClientEvent('m3_illegaltablet:cl:crewVehicleLockpicked', t)
        end
    end
    relay(leaderSrc)
    if activeCrew[leaderSrc] then
        for _, msrc in ipairs(activeCrew[leaderSrc].members) do relay(msrc) end
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:crewCarHackSync', function(hacksLeft, done)
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local function relay(t)
        TriggerClientEvent('m3_illegaltablet:cl:crewCarHackSync', t, hacksLeft, done)
    end
    if leaderSrc ~= src then relay(leaderSrc) end
    if activeCrew[leaderSrc] then
        for _, msrc in ipairs(activeCrew[leaderSrc].members) do
            if msrc ~= src then relay(msrc) end
        end
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:crewBurglaryLockpicked', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local function relay(t)
        if t ~= src then
            TriggerClientEvent('m3_illegaltablet:cl:crewBurglaryLockpicked', t)
        end
    end
    relay(leaderSrc)
    if activeCrew[leaderSrc] then
        for _, msrc in ipairs(activeCrew[leaderSrc].members) do relay(msrc) end
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:crewBoxSearched', function(contractId, boxIndex)
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local function relay(t)
        if t ~= src then
            TriggerClientEvent('m3_illegaltablet:cl:crewBoxSearched', t, boxIndex)
        end
    end
    relay(leaderSrc)
    if activeCrew[leaderSrc] then
        for _, msrc in ipairs(activeCrew[leaderSrc].members) do relay(msrc) end
    end
end)

local burglaryBoxCache = {}

RegisterNetEvent('m3_illegaltablet:sv:crewBurglaryBoxSync', function(contractId, positions)
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    burglaryBoxCache[leaderSrc] = positions
    if activeCrew[leaderSrc] then
        for _, msrc in ipairs(activeCrew[leaderSrc].members) do
            TriggerClientEvent('m3_illegaltablet:cl:burglaryBoxSync', msrc, positions)
        end
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:requestBurglaryBoxSync', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local cache     = burglaryBoxCache[leaderSrc]
    if cache then
        TriggerClientEvent('m3_illegaltablet:cl:burglaryBoxSync', src, cache)
    end
end)

local burglaryNpcCache = {}

RegisterNetEvent('m3_illegaltablet:sv:crewBurglaryNpcReady', function(x, y, z, w, model)
    local src = source
    burglaryNpcCache[src] = { x = x, y = y, z = z, w = w, model = model }
    if not activeCrew[src] then return end
    for _, msrc in ipairs(activeCrew[src].members) do
        TriggerClientEvent('m3_illegaltablet:cl:burglaryNpcReady', msrc, x, y, z, w, model)
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:requestBurglaryNpc', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local c         = burglaryNpcCache[leaderSrc]
    if c then
        TriggerClientEvent('m3_illegaltablet:cl:burglaryNpcReady', src, c.x, c.y, c.z, c.w, c.model)
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:crewBurglaryDelivered', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local function relay(t)
        if t ~= src then
            TriggerClientEvent('m3_illegaltablet:cl:burglaryDelivered', t)
        end
    end
    relay(leaderSrc)
    if activeCrew[leaderSrc] then
        for _, msrc in ipairs(activeCrew[leaderSrc].members) do relay(msrc) end
    end
end)

local shopNpcCache = {}

RegisterNetEvent('m3_illegaltablet:sv:shopNpcReady', function(netId)
    local src = source
    shopNpcCache[src] = netId
    if not activeCrew[src] then return end
    for _, msrc in ipairs(activeCrew[src].members) do
        TriggerClientEvent('m3_illegaltablet:cl:shopNpcReady', msrc, netId)
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:requestShopNpc', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local netId     = shopNpcCache[leaderSrc]
    if netId then
        TriggerClientEvent('m3_illegaltablet:cl:shopNpcReady', src, netId)
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:shopFearSync', function(pct)
    local src = source
    if not activeCrew[src] then return end
    for _, msrc in ipairs(activeCrew[src].members) do
        TriggerClientEvent('m3_illegaltablet:cl:shopFearSync', msrc, pct)
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:shopCrewAiming', function()
    local src       = source
    local leaderSrc = playerCrewMap[src]
    if leaderSrc then
        TriggerClientEvent('m3_illegaltablet:cl:shopCrewAiming', leaderSrc)
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:shopBagReady', function(x, y, z)
    local src = source
    if not activeCrew[src] then return end
    for _, msrc in ipairs(activeCrew[src].members) do
        TriggerClientEvent('m3_illegaltablet:cl:shopBagReady', msrc, x, y, z)
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:shopBagCollected', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local function relay(t)
        if t ~= src then TriggerClientEvent('m3_illegaltablet:cl:shopContractDone', t) end
    end
    relay(leaderSrc)
    if activeCrew[leaderSrc] then
        for _, msrc in ipairs(activeCrew[leaderSrc].members) do relay(msrc) end
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:crewFleecaVaultHacked', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local function relay(t)
        if t ~= src then TriggerClientEvent('m3_illegaltablet:cl:fleecaVaultHacked', t) end
    end
    relay(leaderSrc)
    if activeCrew[leaderSrc] then
        for _, msrc in ipairs(activeCrew[leaderSrc].members) do relay(msrc) end
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:crewFleecaBarsHacked', function()

    do
        local ls = playerCrewMap[source] or source
        if fleecaHeists[ls] then fleecaHeists[ls].barsOpen = true end
    end
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local function relay(t)
        if t ~= src then TriggerClientEvent('m3_illegaltablet:cl:fleecaBarsHacked', t) end
    end
    relay(leaderSrc)
    if activeCrew[leaderSrc] then
        for _, msrc in ipairs(activeCrew[leaderSrc].members) do relay(msrc) end
    end
end)

local TROLLEY_FULL  = joaat('hei_prop_hei_cash_trolly_01')
local TROLLEY_EMPTY = joaat('hei_prop_hei_cash_trolly_03')

fleecaHeists = {}

local function FleecaHeistCrew(leaderSrc)
    local out = { leaderSrc }
    if activeCrew[leaderSrc] then
        for _, msrc in ipairs(activeCrew[leaderSrc].members) do out[#out + 1] = msrc end
    end
    return out
end

local function FleecaSendTrolleys(h, target)
    local data = {}
    for i, t in ipairs(h.trolleys) do
        data[i] = { netId = t.netId, barsSide = t.barsSide, empty = t.remaining <= 0 }
    end
    TriggerClientEvent('m3_illegaltablet:cl:fleecaTrolleys', target, data, h.barsOpen == true)
end

local function FleecaCleanupHeist(leaderSrc)
    local h = fleecaHeists[leaderSrc]
    if not h then return end
    for _, t in ipairs(h.trolleys) do
        if t.ent and DoesEntityExist(t.ent) then DeleteEntity(t.ent) end
    end
    fleecaHeists[leaderSrc] = nil
end

RegisterNetEvent('m3_illegaltablet:sv:fleecaVaultOpened', function(defs)
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local ac        = activeContracts[src]
    if not ac or ac.contractKey ~= 'robbery_fleeca' then return end

    local h = fleecaHeists[leaderSrc]
    if h then
        FleecaSendTrolleys(h, src)
        return
    end
    if type(defs) ~= 'table' or #defs == 0 then return end

    fleecaHeists[leaderSrc] = { trolleys = {}, barsOpen = false }
    h = fleecaHeists[leaderSrc]

    local freezeIds = {}
    for _, d in ipairs(defs) do
        local obj = CreateObject(TROLLEY_FULL, d.x + 0.0, d.y + 0.0, d.z + 0.0, true, true, false)
        local t = 0
        while not DoesEntityExist(obj) and t < 2000 do Wait(50); t = t + 50 end
        if DoesEntityExist(obj) then
            SetEntityHeading(obj, d.heading or 0.0)
            local remaining = math.random(math.floor(d.min or 3000), math.floor(d.max or 7000))

            h.trolleys[#h.trolleys + 1] = {
                ent       = obj,
                netId     = NetworkGetNetworkIdFromEntity(obj),
                remaining = remaining,
                tick      = math.ceil(remaining / 8),
                barsSide  = d.barsSide == true,
            }
            freezeIds[#freezeIds + 1] = h.trolleys[#h.trolleys].netId
        end
    end

    TriggerClientEvent('m3_illegaltablet:cl:fleecaTrolleyFreeze', -1, freezeIds)

    for _, s in ipairs(FleecaHeistCrew(leaderSrc)) do
        FleecaSendTrolleys(h, s)
    end
    if Config.ContractDistribution and Config.ContractDistribution.debugLog then
        print(('[m3_illegaltablet] Fleeca: spawnnutych %d vozikov (lider %d)'):format(#h.trolleys, leaderSrc))
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:fleecaGrabTick', function(idx)
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local ac        = activeContracts[src]
    if not ac or ac.contractKey ~= 'robbery_fleeca' then return end

    local h = fleecaHeists[leaderSrc]
    if not h then return end
    local t = h.trolleys[tonumber(idx) or 0]
    if not t or t.remaining <= 0 then return end
    if t.barsSide and not h.barsOpen then return end

    local pay = math.min(t.tick, t.remaining)
    t.remaining = t.remaining - pay
    GiveMoney(src, pay)

    if t.remaining <= 0 then

        local pos  = GetEntityCoords(t.ent)
        local head = GetEntityHeading(t.ent)
        if DoesEntityExist(t.ent) then DeleteEntity(t.ent) end
        local e2 = CreateObject(TROLLEY_EMPTY, pos.x, pos.y, pos.z - 0.985, true, true, false)
        local wt = 0
        while not DoesEntityExist(e2) and wt < 2000 do Wait(50); wt = wt + 50 end
        local newNetId = 0
        if DoesEntityExist(e2) then
            SetEntityHeading(e2, head)
            t.ent    = e2
            newNetId = NetworkGetNetworkIdFromEntity(e2)
            TriggerClientEvent('m3_illegaltablet:cl:fleecaTrolleyFreeze', -1, { newNetId })
        end

        local crew = FleecaHeistCrew(leaderSrc)
        for _, s in ipairs(crew) do
            TriggerClientEvent('m3_illegaltablet:cl:fleecaTrolleyEmpty', s, tonumber(idx), newNetId)
        end

        local allEmpty = true
        for _, tt in ipairs(h.trolleys) do
            if tt.remaining > 0 then allEmpty = false; break end
        end
        if allEmpty then
            for _, s in ipairs(crew) do
                TriggerClientEvent('m3_illegaltablet:cl:fleecaAllEmpty', s)
            end
        end
    end
end)

bobcatDoorState = {}

RegisterNetEvent('m3_illegaltablet:sv:requestBobcatState', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    if bobcatDoorState[leaderSrc] then
        TriggerClientEvent('m3_illegaltablet:cl:bobcatDoorHacked', src)
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:crewBobcatDoorHacked', function()
    do
        local ls = playerCrewMap[source] or source
        bobcatDoorState[ls] = true
    end
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local function relay(t)
        if t ~= src then TriggerClientEvent('m3_illegaltablet:cl:bobcatDoorHacked', t) end
    end
    relay(leaderSrc)
    if activeCrew[leaderSrc] then
        for _, msrc in ipairs(activeCrew[leaderSrc].members) do relay(msrc) end
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:crewBobcatVaultBlown', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local function relay(t)
        if t ~= src then TriggerClientEvent('m3_illegaltablet:cl:bobcatVaultBlown', t) end
    end
    relay(leaderSrc)
    if activeCrew[leaderSrc] then
        for _, msrc in ipairs(activeCrew[leaderSrc].members) do relay(msrc) end
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:crewBobcatCrateLooted', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local function relay(t)
        if t ~= src then TriggerClientEvent('m3_illegaltablet:cl:bobcatCrateLooted', t) end
    end
    relay(leaderSrc)
    if activeCrew[leaderSrc] then
        for _, msrc in ipairs(activeCrew[leaderSrc].members) do relay(msrc) end
    end
end)

local truckHeists = {}

local function TruckCrew(leaderSrc)
    local out = { leaderSrc }
    if activeCrew[leaderSrc] then
        for _, m in ipairs(activeCrew[leaderSrc].members) do out[#out + 1] = m end
    end
    return out
end

local function TruckSendData(h, target)
    TriggerClientEvent('m3_illegaltablet:cl:truckData', target, {
        vehNet    = h.vehNet,
        driverNet = h.driverNet,
        guardNet  = h.guardNet,
        phase     = h.phase,
        bags      = h.bags,
        engaged   = h.engaged,
    })
end

local function DeleteTruckEntities(h)
    for _, nid in ipairs({ h.driverNet, h.guardNet, h.vehNet }) do
        if nid and nid ~= 0 then
            local ent = NetworkGetEntityFromNetworkId(nid)
            if ent and ent ~= 0 and DoesEntityExist(ent) then
                DeleteEntity(ent)
            end
        end
    end
end

function CleanupTruckHeist(src, onlyIfLeader)

    local leaderSrc = onlyIfLeader and src or (playerCrewMap[src] or src)
    local h = truckHeists[leaderSrc]
    if not h then return end
    truckHeists[leaderSrc] = nil

    if h.completed then
        local conf  = (Config.Robberies and Config.Robberies.truck) or {}
        local delay = conf.wreckCleanupDelay or 600
        if delay > 0 then
            SetTimeout(delay * 1000, function() DeleteTruckEntities(h) end)
        end
        return
    end

    DeleteTruckEntities(h)
end

RegisterNetEvent('m3_illegaltablet:sv:truckSpawned', function(vehNet, driverNet, guardNet)
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local ac        = activeContracts[src]
    if not ac or ac.contractKey ~= 'robbery_truck' then return end

    if truckHeists[leaderSrc] then
        CleanupTruckHeist(leaderSrc, true)
    end

    local conf  = (Config.Robberies and Config.Robberies.truck) or {}
    local bagsC = conf.bagCount or { min = 3, max = 5 }
    truckHeists[leaderSrc] = {
        vehNet    = vehNet,
        driverNet = driverNet,
        guardNet  = guardNet,
        phase     = 'drive',
        bags      = math.random(bagsC.min, bagsC.max),
    }
    local h = truckHeists[leaderSrc]
    for _, s in ipairs(TruckCrew(leaderSrc)) do TruckSendData(h, s) end

    local veh0 = NetworkGetEntityFromNetworkId(vehNet)
    if veh0 and veh0 ~= 0 and DoesEntityExist(veh0) then
        local c0 = GetEntityCoords(veh0)
        for _, s in ipairs(TruckCrew(leaderSrc)) do
            TriggerClientEvent('m3_illegaltablet:cl:truckPos', s, c0.x, c0.y, c0.z)
        end
    end

    if Config.ContractDistribution and Config.ContractDistribution.debugLog then
        print(('[m3_illegaltablet] Truck heist: spawn (leader %d, bags %d)')
            :format(leaderSrc, h.bags))
    end

    CreateThread(function()
        local posTicks = math.max(1, math.floor((conf.posUpdateInterval or 10) / 2))
        local tick = 0
        while truckHeists[leaderSrc] == h do
            Wait(2000)
            if truckHeists[leaderSrc] ~= h then break end

            if h.phase == 'drive' then
                local function isDead(nid)
                    if not nid or nid == 0 then return true end
                    local e = NetworkGetEntityFromNetworkId(nid)
                    if not e or e == 0 or not DoesEntityExist(e) then return true end
                    return GetEntityHealth(e) <= 0
                end
                if isDead(h.driverNet) and isDead(h.guardNet) then
                    h.phase = 'stopped'
                    for _, s in ipairs(TruckCrew(leaderSrc)) do
                        TriggerClientEvent('m3_illegaltablet:cl:truckGuardsDead', s)
                    end
                end
            end

            tick = tick + 1
            if tick >= posTicks then
                tick = 0
                local veh = NetworkGetEntityFromNetworkId(h.vehNet)
                if veh and veh ~= 0 and DoesEntityExist(veh) then
                    local c = GetEntityCoords(veh)
                    for _, s in ipairs(TruckCrew(leaderSrc)) do
                        TriggerClientEvent('m3_illegaltablet:cl:truckPos', s, c.x, c.y, c.z)
                    end
                end
            end
        end
    end)
end)

RegisterNetEvent('m3_illegaltablet:sv:truckNeed', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local h = truckHeists[leaderSrc]
    if h then TruckSendData(h, src) end
end)

RegisterNetEvent('m3_illegaltablet:sv:truckEngage', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local h = truckHeists[leaderSrc]
    if not h or h.engaged then return end
    h.engaged = true
    for _, s in ipairs(TruckCrew(leaderSrc)) do
        TriggerClientEvent('m3_illegaltablet:cl:truckEngage', s)
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:truckUseC4', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local h = truckHeists[leaderSrc]
    if not h or h.phase ~= 'stopped' then return end

    local conf = (Config.Robberies and Config.Robberies.truck) or {}
    local c4   = conf.c4Item or 'c4'
    if (exports.ox_inventory:GetItemCount(src, c4) or 0) < 1 then
        Notify(src, ('You need %s!'):format(c4), 'error')
        return
    end
    exports.ox_inventory:RemoveItem(src, c4, 1)

    h.phase = 'fused'
    local fuse = conf.c4FuseTime or 5000
    for _, s in ipairs(TruckCrew(leaderSrc)) do
        TriggerClientEvent('m3_illegaltablet:cl:truckC4Planted', s, fuse)
    end

    SetTimeout(fuse, function()

        if truckHeists[leaderSrc] ~= h or h.phase ~= 'fused' then return end
        h.phase = 'blown'
        for _, s in ipairs(TruckCrew(leaderSrc)) do
            TriggerClientEvent('m3_illegaltablet:cl:truckBlown', s, src)
        end
    end)
end)

function ConsumeDrillDurability(src, item, per)
    local slots = exports.ox_inventory:Search(src, 'slots', item)
    local slot  = slots and slots[1]
    if not slot then
        Notify(src, ('You need %s!'):format(item), 'error')
        return false
    end

    local meta = slot.metadata or {}
    local dur  = (tonumber(meta.durability) or 100) - per
    if dur <= 0 then
        exports.ox_inventory:RemoveItem(src, item, 1, nil, slot.slot)
        Notify(src, 'The drill broke!', 'error')
    else
        meta.durability = dur
        exports.ox_inventory:SetMetadata(src, slot.slot, meta)
    end
    return true
end

lib.callback.register('m3_illegaltablet:sv:truckDrillAttempt', function(src)
    local leaderSrc = playerCrewMap[src] or src
    local h = truckHeists[leaderSrc]
    if not h or h.phase ~= 'stopped' then return false end

    local conf = (Config.Robberies and Config.Robberies.truck) or {}
    return ConsumeDrillDurability(src, conf.drillItem or 'drill', conf.drillDurability or 20)
end)

lib.callback.register('m3_illegaltablet:sv:atmDrillAttempt', function(src)
    local ac = activeContracts[src]
    if not ac or ac.contractKey ~= 'robbery_atm' then return false end

    local conf = (Config.Robberies and Config.Robberies.atm) or {}
    return ConsumeDrillDurability(src, conf.drillItem or 'drill', conf.drillDurability or 20)
end)

RegisterNetEvent('m3_illegaltablet:sv:truckDrilled', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local h = truckHeists[leaderSrc]
    if not h or h.phase ~= 'stopped' then return end
    h.phase = 'blown'
    for _, s in ipairs(TruckCrew(leaderSrc)) do
        TriggerClientEvent('m3_illegaltablet:cl:truckBlown', s, src, 'drill')
    end
end)

local jewelryHeists = {}

function CleanupJewelryHeist(src, onlyIfLeader)
    local leaderSrc = onlyIfLeader and src or (playerCrewMap[src] or src)
    jewelryHeists[leaderSrc] = nil
end

local function JewelrySendData(h, target)
    TriggerClientEvent('m3_illegaltablet:cl:jewelryData', target, {
        cases       = h.cases,
        smashed     = h.smashed,
        required    = h.required,
        doorDrilled = h.doorDrilled,
    })
end

RegisterNetEvent('m3_illegaltablet:sv:jewelryStart', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local ac        = activeContracts[src]
    if not ac or ac.contractKey ~= 'robbery_jewelry' then return end

    if jewelryHeists[leaderSrc] then CleanupJewelryHeist(leaderSrc, true) end

    local conf  = (Config.Robberies and Config.Robberies.jewelry) or {}
    local total = #(conf.cases or {})
    if total == 0 then return end

    local n = math.min(conf.casesPerContract or 12, total)
    local pool = {}
    for i = 1, total do pool[i] = i end
    for i = total, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local cases = {}
    for i = 1, n do cases[i] = pool[i] end

    jewelryHeists[leaderSrc] = {
        cases    = cases,
        smashed  = {},
        count    = 0,
        required = math.min(conf.requiredCases or n, n),
    }
    local h = jewelryHeists[leaderSrc]
    for _, s in ipairs(TruckCrew(leaderSrc)) do JewelrySendData(h, s) end
end)

RegisterNetEvent('m3_illegaltablet:sv:jewelryNeed', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local h = jewelryHeists[leaderSrc]
    if h then JewelrySendData(h, src) end
end)

lib.callback.register('m3_illegaltablet:sv:jewelryDrillAttempt', function(src)
    local leaderSrc = playerCrewMap[src] or src
    local h = jewelryHeists[leaderSrc]
    if not h or h.doorDrilled then return false end

    local conf = (Config.Robberies and Config.Robberies.jewelry) or {}
    return ConsumeDrillDurability(src, conf.drillItem or 'drill', conf.drillDurability or 20)
end)

RegisterNetEvent('m3_illegaltablet:sv:jewelryDoorDrilled', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local h = jewelryHeists[leaderSrc]
    if not h or h.doorDrilled then return end
    h.doorDrilled = true
    for _, s in ipairs(TruckCrew(leaderSrc)) do
        TriggerClientEvent('m3_illegaltablet:cl:jewelryDoorDrilled', s)
        TriggerClientEvent('m3_illegaltablet:cl:jewelryAlarm', s, s == src)
    end
end)

local function JewelryPickLoot(lootTable)
    local total = 0
    for _, v in ipairs(lootTable) do total = total + v.weight end
    if total <= 0 then return nil end
    local roll, cum = math.random(total), 0
    for _, v in ipairs(lootTable) do
        cum = cum + v.weight
        if roll <= cum then return v.item end
    end
end

RegisterNetEvent('m3_illegaltablet:sv:jewelrySmash', function(idx)
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local h = jewelryHeists[leaderSrc]
    idx = tonumber(idx)
    if not h or not idx then return end
    if not h.doorDrilled then return end

    local active = false
    for _, c in ipairs(h.cases) do
        if c == idx then active = true break end
    end
    if not active or h.smashed[idx] then return end
    h.smashed[idx] = true
    h.count = h.count + 1

    local conf = (Config.Robberies and Config.Robberies.jewelry) or {}

    local ic = conf.itemsPerCase or { min = 1, max = 2 }
    for _ = 1, math.random(ic.min, ic.max) do
        local item = JewelryPickLoot(conf.lootTable or {})
        if item then GiveItem(src, item, 1) end
    end

    for _, s in ipairs(TruckCrew(leaderSrc)) do
        TriggerClientEvent('m3_illegaltablet:cl:jewelryCaseSmashed', s, idx, h.required - h.count)
    end

    if h.count >= h.required then
        for _, s in ipairs(TruckCrew(leaderSrc)) do
            TriggerClientEvent('m3_illegaltablet:cl:jewelryDone', s, s == src)
        end
    end
end)

local labsHeists = {}
local labsGuards = {}

local function CleanupLabsGuards(leaderSrc)
    if not labsGuards[leaderSrc] then return end
    labsGuards[leaderSrc] = nil
    TriggerClientEvent('m3_illegaltablet:cl:labsGuardsRemove', -1, leaderSrc)
end

function CleanupLabsHeist(src, onlyIfLeader)
    local leaderSrc = onlyIfLeader and src or (playerCrewMap[src] or src)
    if not labsHeists[leaderSrc] then return end
    labsHeists[leaderSrc] = nil
    CleanupLabsGuards(leaderSrc)
end

local function LabsSendData(h, target)
    TriggerClientEvent('m3_illegaltablet:cl:labsData', target, {
        crates      = h.crates,
        searched    = h.searched,
        doorHacked  = h.doorHacked,
        sampleTaken = h.sampleTaken,
        delivered   = h.delivered,
        deliveryIdx = h.deliveryIdx,
    })
end

local function LabsCheckDone(leaderSrc, h, finisherSrc)
    if h.delivered then
        for _, s in ipairs(TruckCrew(leaderSrc)) do
            TriggerClientEvent('m3_illegaltablet:cl:labsDone', s, s == finisherSrc)
        end
    end
end

RegisterNetEvent('m3_illegaltablet:sv:labsStart', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local ac        = activeContracts[src]
    if not ac or ac.contractKey ~= 'robbery_humanelabs' then return end
    if labsHeists[leaderSrc] then CleanupLabsHeist(leaderSrc, true) end

    local conf  = (Config.Robberies and Config.Robberies.humanelabs) or {}
    local total = #(conf.cratePositions or {})
    if total == 0 then return end

    local n = math.min(conf.cratesPerContract or 8, total)
    local pool = {}
    for i = 1, total do pool[i] = i end
    for i = total, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local crates = {}
    for i = 1, n do crates[i] = pool[i] end

    labsHeists[leaderSrc] = {
        crates      = crates,
        searched    = {},
        count       = 0,
        deliveryIdx = (#(conf.deliveryNpcs or {}) > 0)
            and math.random(#conf.deliveryNpcs) or nil,
    }
    local h = labsHeists[leaderSrc]
    for _, s in ipairs(TruckCrew(leaderSrc)) do LabsSendData(h, s) end
end)

RegisterNetEvent('m3_illegaltablet:sv:labsNeed', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local h = labsHeists[leaderSrc]
    if h then LabsSendData(h, src) end
end)

RegisterNetEvent('m3_illegaltablet:sv:labsDoorHacked', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local h = labsHeists[leaderSrc]
    if not h or h.doorHacked then return end
    h.doorHacked = true
    for _, s in ipairs(TruckCrew(leaderSrc)) do
        TriggerClientEvent('m3_illegaltablet:cl:labsDoorHacked', s, s == leaderSrc, s == src)
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:labsNeedGuards', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    if not labsHeists[leaderSrc] or not labsHeists[leaderSrc].doorHacked then return end
    if not labsGuards[leaderSrc] then
        labsGuards[leaderSrc] = { dead = {} }
    end
    TriggerClientEvent('m3_illegaltablet:cl:labsGuardsSpawn', -1,
        leaderSrc, labsGuards[leaderSrc].dead)
end)

AddEventHandler('ox:playerLoaded', function(source)
    for leaderSrc, g in pairs(labsGuards) do
        TriggerClientEvent('m3_illegaltablet:cl:labsGuardsSpawn', source, leaderSrc, g.dead)
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:labsGuardDied', function(heistId, idx)
    local g = labsGuards[tonumber(heistId) or 0]
    idx = tonumber(idx)
    if not g or not idx or g.dead[idx] then return end
    g.dead[idx] = true
    TriggerClientEvent('m3_illegaltablet:cl:labsGuardDie', -1, tonumber(heistId), idx)
end)

RegisterNetEvent('m3_illegaltablet:sv:labsSearch', function(idx)
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local h = labsHeists[leaderSrc]
    idx = tonumber(idx)
    if not h or not idx or not h.doorHacked then return end

    local active = false
    for _, c in ipairs(h.crates) do
        if c == idx then active = true break end
    end
    if not active or h.searched[idx] then return end
    h.searched[idx] = true
    h.count = h.count + 1

    local conf = (Config.Robberies and Config.Robberies.humanelabs) or {}
    local ic   = conf.itemsPerCrate or { min = 1, max = 2 }
    for _ = 1, math.random(ic.min, ic.max) do
        local item = JewelryPickLoot(conf.lootTable or {})
        if item then GiveItem(src, item, 1) end
    end

    for _, s in ipairs(TruckCrew(leaderSrc)) do
        TriggerClientEvent('m3_illegaltablet:cl:labsCrateSearched', s, idx)
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:labsSample', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local h = labsHeists[leaderSrc]
    if not h or not h.doorHacked or h.sampleTaken then return end
    h.sampleTaken = true

    local conf = (Config.Robberies and Config.Robberies.humanelabs) or {}
    GiveItem(src, conf.sampleItem or 'chem_vzorka', 1)
    Notify(src, 'You obtained the research sample! Take it to the buyer.', 'success')

    for _, s in ipairs(TruckCrew(leaderSrc)) do
        TriggerClientEvent('m3_illegaltablet:cl:labsSampleTaken', s)
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:labsDeliver', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local h = labsHeists[leaderSrc]
    if not h or not h.sampleTaken or h.delivered then return end

    local conf = (Config.Robberies and Config.Robberies.humanelabs) or {}
    local item = conf.sampleItem or 'chem_vzorka'
    if GetItemCount(src, item) < 1 then
        Notify(src, ('You are not carrying %s!'):format(item), 'error')
        return
    end
    RemoveItem(src, item, 1)
    h.delivered = true

    local rr = conf.sampleReward
    if rr then
        local reward = math.random(rr.min, rr.max)
        GiveMoney(src, reward)
        Notify(src, ('Sample delivered: +$%d'):format(reward), 'success')
    end

    for _, s in ipairs(TruckCrew(leaderSrc)) do
        TriggerClientEvent('m3_illegaltablet:cl:labsDelivered', s)
    end
    LabsCheckDone(leaderSrc, h, src)
end)

RegisterNetEvent('m3_illegaltablet:sv:truckTakeBag', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local h = truckHeists[leaderSrc]
    if not h or h.phase ~= 'blown' or h.bags <= 0 then return end

    h.bags = h.bags - 1
    local conf   = (Config.Robberies and Config.Robberies.truck) or {}
    local rr     = conf.rewardPerBag or { min = 4000, max = 9000 }
    local reward = math.random(rr.min, rr.max)
    GiveMoney(src, reward)

    for _, s in ipairs(TruckCrew(leaderSrc)) do
        TriggerClientEvent('m3_illegaltablet:cl:truckBagTaken', s, h.bags)
    end

    if h.bags <= 0 then
        h.completed = true
        for _, s in ipairs(TruckCrew(leaderSrc)) do

            TriggerClientEvent('m3_illegaltablet:cl:truckEmpty', s, s == src)
        end
    end
end)

local bobcatGuards = {}

function CleanupBobcatGuards(src)
    local leaderSrc = playerCrewMap[src] or src
    if not bobcatGuards[leaderSrc] then return end
    bobcatGuards[leaderSrc] = nil
    TriggerClientEvent('m3_illegaltablet:cl:bobcatGuardsRemove', -1, leaderSrc)
end

RegisterNetEvent('m3_illegaltablet:sv:bobcatNeedGuards', function()
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    if not bobcatGuards[leaderSrc] then
        bobcatGuards[leaderSrc] = { dead = {} }
        if Config.ContractDistribution and Config.ContractDistribution.debugLog then
            print(("[m3_illegaltablet] Bobcat: guards active (leader's heist %d)"):format(leaderSrc))
        end
    end

    TriggerClientEvent('m3_illegaltablet:cl:bobcatGuardsSpawn', -1,
        leaderSrc, bobcatGuards[leaderSrc].dead)
end)

AddEventHandler('ox:playerLoaded', function(source)
    for leaderSrc, g in pairs(bobcatGuards) do
        TriggerClientEvent('m3_illegaltablet:cl:bobcatGuardsSpawn', source, leaderSrc, g.dead)
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:bobcatGuardDied', function(heistId, idx)
    local g = bobcatGuards[tonumber(heistId) or 0]
    idx = tonumber(idx)
    if not g or not idx or g.dead[idx] then return end
    g.dead[idx] = true
    TriggerClientEvent('m3_illegaltablet:cl:bobcatGuardDie', -1, tonumber(heistId), idx)
end)

RegisterNetEvent('m3_illegaltablet:sv:bobcatCleanupGuards', function()
    CleanupBobcatGuards(source)
end)

RegisterCommand('m3buckets', function(src)
    if src ~= 0 then return end
    for _, ps in ipairs(GetPlayers()) do
        local pid = tonumber(ps)
        print(('[m3_illegaltablet] player %d (%s): bucket=%d')
            :format(pid, GetPlayerName(pid) or '?', GetPlayerRoutingBucket(ps) or -1))
    end

    for leaderSrc, g in pairs(bobcatGuards) do
        local deadCount = 0
        for _ in pairs(g.dead) do deadCount = deadCount + 1 end
        print(("[m3_illegaltablet] bobcat leader's heist %d: dead posts %d")
            :format(leaderSrc, deadCount))
    end
end, true)

RegisterNetEvent('m3_illegaltablet:sv:globalAlert', function(cx, cy, cz, radius)
    for _, ps in ipairs(GetPlayers()) do
        local pid = tonumber(ps)
        if IsPolice(pid) then
            TriggerClientEvent('m3_illegaltablet:cl:globalAlert', pid, cx, cy, cz, radius)
        end
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:globalAlertClear', function()
    for _, ps in ipairs(GetPlayers()) do
        local pid = tonumber(ps)
        if IsPolice(pid) then
            TriggerClientEvent('m3_illegaltablet:cl:globalAlertClear', pid)
        end
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:policeAlert', function(x, y, z, radius, duration)
    local players = GetPlayers()
    for _, ps in ipairs(players) do
        local pid = tonumber(ps)
        if IsPolice(pid) then
            TriggerClientEvent('m3_illegaltablet:cl:policeAlert', pid, x, y, z, radius, duration)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(300000)
        for id, pd in pairs(playerData) do
            SavePlayerData(id, pd)
        end
    end
end)

local function GetRedXPTier(redXP)
    local current, next = Config.RedXPTiers[1], nil
    for i, tier in ipairs(Config.RedXPTiers) do
        if redXP >= tier.minXP then
            current = tier
            next    = Config.RedXPTiers[i + 1]
        end
    end
    return current, next
end

local function GetGreenAccessible(greenXP)
    local ids = {}
    for _, unlock in ipairs(Config.GreenXPUnlocks) do
        if greenXP >= unlock.minXP then
            for _, id in ipairs(unlock.contracts) do
                ids[#ids + 1] = id
            end
        end
    end
    return ids
end

RegisterNetEvent('m3_illegaltablet:sv:requestTabletData', function()
    local src = source
    local id  = GetIdentifier(src)
    if not id then return end

    local function Send(pd)
        CheckRotation(src, pd)

        local redTier, redNext = GetRedXPTier(pd.redXP)
        local greenAccessible  = GetGreenAccessible(pd.greenXP)

        local tabletData = {
            playerName      = pd.name,
            redXP           = pd.redXP,
            greenXP         = pd.greenXP,
            redTier         = { id = redTier.id, label = redTier.label, minXP = redTier.minXP, nextMinXP = redNext and redNext.minXP },
            greenAccessible = greenAccessible,
            contracts       = pd.offers,
            contractFilter  = pd.contractFilter,
            allContractTypes = BuildAllContractTypes(pd),
            leaderboard     = GetLeaderboard(),
            playerId             = pd.playerId or 0,
            activeContract       = activeContracts[src] or false,
            isCrewLeader         = activeCrew[src] ~= nil,
            receivingEnabled     = ContractsReceivingEnabled(src),
        }

        if GetCrewDataForSrc then
            local crewData = GetCrewDataForSrc(src)
            if crewData then
                for k, v in pairs(crewData) do
                    tabletData[k] = v
                end
            end
        end

        TriggerClientEvent('m3_illegaltablet:cl:openTablet', src, tabletData)
    end

    if playerData[id] then
        Send(playerData[id])
    else
        LoadPlayerData(id, function(data)
            playerData[id] = data
            Send(data)
        end)
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:setPlayerName', function(newName)
    local src = source
    local pd, id = GetPD(src)
    if not pd or not id then return end

    newName = tostring(newName or ''):match('^%s*(.-)%s*$')
    if #newName < 2 or #newName > 30 then return end
    if newName:match('[^%w%s%._%-]') then return end

    pd.name = newName
    MySQL.execute('UPDATE m3_tablet SET name=? WHERE identifier=?', { newName, id })

    TriggerClientEvent('m3_illegaltablet:cl:updateData', src, { playerName = newName })
end)

RegisterNetEvent('m3_illegaltablet:sv:updateFilter', function(filter)
    local src = source
    local pd, id = GetPD(src)
    if not pd then return end
    pd.contractFilter = filter

    if Config.DebugContracts then

        RegenerateOffers(src, pd)
    else

        if filter ~= nil then
            local allowed = {}
            for _, f in ipairs(filter) do allowed[f] = true end
            local kept = {}
            for _, o in ipairs(pd.offers or {}) do
                if allowed[o.contractKey] then kept[#kept + 1] = o end
            end
            pd.offers = kept
        end
    end

    TriggerClientEvent('m3_illegaltablet:cl:updateData', src, {
        contracts      = pd.offers,
        contractFilter = filter,
    })
end)

RegisterNetEvent('m3_illegaltablet:sv:acceptContract', function(contractId)
    local src = source
    if activeContracts[src] then
        Notify(src, T('already_active'), 'error')
        return
    end
    local pd, id = GetPD(src)
    if not pd then return end

    local found
    for _, c in ipairs(pd.offers) do
        if c.id == contractId then found = c; break end
    end
    if not found then
        Notify(src, 'Contract not found.', 'error')
        return
    end

    if found.type == 'burglary' then
        local bKey  = found.burglaryKey
        local bConf = Config.Burglaries[bKey]
        if bConf and bConf.locations then
            local freeIdx = FindFreeLocIdx(bKey, #bConf.locations)
            local ext     = bConf.locations[freeIdx].exterior
            found.locationIndex = freeIdx
            found.location = { x = ext.x, y = ext.y, z = ext.z, w = ext.w }
            LockBurglaryLoc(bKey, freeIdx, src)
        end
    end

    activeContracts[src] = found

    for i, c in ipairs(pd.offers) do
        if c.id == contractId then table.remove(pd.offers, i); break end
    end
    SetContractTypeCooldown(found.contractKey)
    TriggerClientEvent('m3_illegaltablet:cl:updateData', src, { contracts = pd.offers })

    TriggerClientEvent('m3_illegaltablet:cl:startContract', src, found)
end)

local function ScheduleFleecaReset()
    local conf    = Config.Robberies and Config.Robberies.fleeca
    local delayMs = ((conf and conf.interiorResetDelay) or 10) * 60 * 1000
    SetTimeout(delayMs, function()
        TriggerClientEvent('m3_illegaltablet:cl:resetFleecaInterior', -1)
    end)
end

RegisterNetEvent('m3_illegaltablet:sv:setContractLocation', function(locIdx)
    local src = source
    local ac  = activeContracts[src]
    if not ac then return end
    ac.locationIndex = locIdx

    if activeCrew[src] then
        for _, msrc in ipairs(activeCrew[src].members) do
            if activeContracts[msrc] then
                activeContracts[msrc].locationIndex = locIdx
            end
        end
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:cancelContract', function()
    local src = source
    local ac  = activeContracts[src]
    if ac then
        if ac.contractKey == 'robbery_fleeca' then ScheduleFleecaReset() end
    end
    FinishContract(src)
end)

RegisterNetEvent('m3_illegaltablet:sv:contractExpired', function()
    local src = source
    local ac  = activeContracts[src]
    if ac then
        if ac.contractKey == 'robbery_fleeca' then ScheduleFleecaReset() end
    end
    Notify(src, T('contract_expired'), 'error')
    FinishContract(src)
end)

local interiorBuckets = {}
local _nextBucket     = 1

local burglarySites = {}

local function BroadcastToPolice(event, ...)
    local sent, total = 0, 0
    for _, ps in ipairs(GetPlayers()) do
        total = total + 1
        local pid = tonumber(ps)
        if IsPolice(pid) then
            sent = sent + 1
            TriggerClientEvent(event, pid, ...)
        end
    end
    if Config.ContractDistribution and Config.ContractDistribution.debugLog then
        print(('[m3_illegaltablet] %s -> %d/%d players are police (IsPolice)')
            :format(event, sent, total))
    end
    return sent
end

function FinishContract(src)
    SetPlayerRoutingBucket(src, 0)
    FreeBurglaryLoc(src)
    crewVehicleCache[src]     = nil
    crewVehicleBlipCache[src] = nil
    burglaryBoxCache[src]     = nil
    burglaryNpcCache[src]     = nil
    shopNpcCache[src]         = nil
    CleanupBobcatGuards(src)
    CleanupTruckHeist(src)
    CleanupJewelryHeist(src)
    CleanupLabsHeist(src)
    FleecaCleanupHeist(src)
    bobcatDoorState[src]      = nil
    if CleanupCrewFor then CleanupCrewFor(src) end
    local ac = activeContracts[src]
    activeContracts[src] = nil

    if ac and ac.id then
        local stillInUse = false
        for _, otherAc in pairs(activeContracts) do
            if otherAc.id == ac.id then stillInUse = true; break end
        end
        if not stillInUse then
            interiorBuckets[ac.id] = nil

            if burglarySites[ac.id] then
                burglarySites[ac.id] = nil
                BroadcastToPolice('m3_illegaltablet:cl:burglaryPoliceSiteRemove', ac.id)
            end
        end
    end
    TriggerClientEvent('m3_illegaltablet:cl:contractDone', src, 0)
end

local function AllocBucket()
    local b = _nextBucket
    _nextBucket = (_nextBucket % 999) + 1
    return b
end

RegisterNetEvent('m3_illegaltablet:sv:enterInterior', function(contractId)
    local src = source
    if not interiorBuckets[contractId] then
        interiorBuckets[contractId] = AllocBucket()
    end
    SetPlayerRoutingBucket(src, interiorBuckets[contractId])
end)

RegisterNetEvent('m3_illegaltablet:sv:exitInterior', function(contractId)
    local src = source
    SetPlayerRoutingBucket(src, 0)

end)

RegisterNetEvent('m3_illegaltablet:sv:burglarySiteOpen', function(site)
    local src = source
    local ac  = activeContracts[src]
    if not ac or ac.type ~= 'burglary' then return end
    if burglarySites[ac.id] then return end
    if type(site) ~= 'table' or not site.pos or not site.entry or not site.exit then return end

    burglarySites[ac.id] = {
        contractId = ac.id,
        pos    = site.pos,
        entry  = site.entry,
        exit   = site.exit,
        ipl    = site.ipl,
        sealed = false,
    }
    if Config.ContractDistribution and Config.ContractDistribution.debugLog then
        print(('[m3_illegaltablet] Crime scene OPEN (contract %s) - alerting police')
            :format(tostring(ac.id)))
    end
    BroadcastToPolice('m3_illegaltablet:cl:burglaryPoliceSite', burglarySites[ac.id])
end)

RegisterNetEvent('m3_illegaltablet:sv:sealBurglarySite', function(contractId)
    local src = source
    if not IsPolice(src) then return end
    local site = burglarySites[contractId]
    if not site or site.sealed then return end
    site.sealed = true

    BroadcastToPolice('m3_illegaltablet:cl:burglaryPoliceSiteRemove', contractId)

    TriggerClientEvent('m3_illegaltablet:cl:burglarySealed', -1, contractId)
    Notify(src, 'Crime scene sealed.', 'success')
end)

RegisterNetEvent('m3_illegaltablet:sv:vehicleDelivered', function()
    local src      = source
    local contract = activeContracts[src]
    if not contract or contract.type ~= 'vehicle_theft' then return end

    local pd, id = GetPD(src)
    if not pd then return end

    local leaderSrc = playerCrewMap[src] or src

    local allSrcs = { leaderSrc }
    if activeCrew[leaderSrc] then
        for _, msrc in ipairs(activeCrew[leaderSrc].members) do
            allSrcs[#allSrcs + 1] = msrc
        end
    end

    for _, s in ipairs(allSrcs) do
        if s ~= src then
            TriggerClientEvent('m3_illegaltablet:cl:crewVehicleDelivered', s)
        end
    end

    local cat = Config.VehicleCategories[contract.category]

    GiveMoney(src, contract.reward)

    local xpR = math.random(cat.redXPReward.min, cat.redXPReward.max)
    local crewSize = #allSrcs
    for _, s in ipairs(allSrcs) do
        local pd2, id2 = GetPD(s)
        if pd2 then
            local share = math.max(1, math.floor(xpR / crewSize))
            pd2.redXP = pd2.redXP + share
            local redTier2, redNext2 = GetRedXPTier(pd2.redXP)
            if s == src then
                Notify(s, string.format('$%s | +%s Boosting XP', contract.reward, share), 'success')
            else
                Notify(s, string.format('Vehicle delivered! +%s Boosting XP', share), 'success')
            end
            TriggerClientEvent('m3_illegaltablet:cl:updateData', s, {
                redXP   = pd2.redXP,
                redTier = { id = redTier2.id, label = redTier2.label, minXP = redTier2.minXP, nextMinXP = redNext2 and redNext2.minXP },
            })
            SavePlayerData(id2, pd2)
        end
    end

    FinishContract(leaderSrc)
end)

RegisterNetEvent('m3_illegaltablet:sv:collectRobberyItem', function(item, amt, rewardRange)
    local src = source
    if item == 'moneybag' or item == 'money' or item == 'cash' then
        if rewardRange then
            local rAmt = math.random(rewardRange.min, rewardRange.max)
            GiveMoney(src, amt * rAmt)
            return
        end
    end
    GiveItem(src, item, amt)
end)

RegisterNetEvent('m3_illegaltablet:sv:foundBurglaryItem', function(item, amt, rewardRange)
    GiveItem(source, item, amt)
end)

RegisterNetEvent('m3_illegaltablet:sv:burglary:giveContract', function()
    local src          = source
    local contractItem = Config.BurglaryContractItem or 'contract'
    GiveItem(src, contractItem, 1)
end)

RegisterNetEvent('m3_illegaltablet:sv:usedLockpick', function()
    if Config.LockpickItem then
        RemoveItem(source, Config.LockpickItem, 1)
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:useHackingDevice', function()
    local item = Config.HackingDeviceItem or 'hacking_device'
    RemoveItem(source, item, 1)
end)

RegisterNetEvent('m3_illegaltablet:sv:spawnDoorBlocker', function(model, x, y, z, heading)
    local src  = source
    local hash = GetHashKey(model)
    local obj  = CreateObject(hash, x, y, z, true, true, true)
    local t    = 0
    while not DoesEntityExist(obj) and t < 3000 do
        Wait(1); t = t + 1
    end
    if not DoesEntityExist(obj) then
        print('[m3] spawnDoorBlocker: CreateObject failed server-side for ' .. model)
        return
    end

    SetEntityAsMissionEntity(obj, true, true)
    SetEntityDynamic(obj, false)
    FreezeEntityPosition(obj, true)
    Wait(500)
    TriggerClientEvent('m3_illegaltablet:cl:doorBlockerSpawned', src,
        NetworkGetNetworkIdFromEntity(obj))
end)

RegisterNetEvent('m3_illegaltablet:sv:deleteDoorBlocker', function(netId)
    local obj = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(obj) then
        DeleteEntity(obj)
    end
end)

RegisterNetEvent('m3_illegaltablet:sv:bobcat:usedC4', function()
    local src  = source
    local item = Config.Robberies.bobcat and Config.Robberies.bobcat.vaultC4Item or 'c4'
    RemoveItem(src, item, 1)
end)

RegisterNetEvent('m3_illegaltablet:sv:bobcat:lootWeapons', function()
    local src      = source
    local contract = activeContracts[src]
    if not contract or contract.type ~= 'robbery' then return end

    local conf    = Config.Robberies.bobcat
    if not conf   then return end

    local weapons = conf.crateWeapons or {}
    if #weapons == 0 then return end

    local count = math.random(
        conf.crateCount and conf.crateCount.min or 1,
        conf.crateCount and conf.crateCount.max or 2)

    local pool = {}
    for i = 1, #weapons do pool[i] = i end
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    local given = {}
    for i = 1, math.min(count, #weapons) do
        local w = weapons[pool[i]]
        GiveItem(src, w, 1)
        given[#given + 1] = w
    end

    Notify(src, string.format('You took %d %s from the warehouse!',
        #given, #given == 1 and 'weapon' or 'weapons'), 'success')
end)

local function DistributeXpReward(leaderSrc, baseXp)
    local allSrcs = { leaderSrc }
    if activeCrew and activeCrew[leaderSrc] then
        for _, msrc in ipairs(activeCrew[leaderSrc].members) do
            allSrcs[#allSrcs + 1] = msrc
        end
    end

    for _, s in ipairs(allSrcs) do
        local sharePct = (GetXpShare and GetXpShare(leaderSrc, s)) or math.floor(100 / #allSrcs)
        if sharePct > 0 then
            local pd2, id2 = GetPD(s)
            if pd2 then
                local xp = math.max(1, math.floor(baseXp * sharePct / 100))
                pd2.greenXP = pd2.greenXP + xp
                local label = sharePct < 100
                    and string.format('+%s Burglary XP  (%s%%)', xp, sharePct)
                    or  string.format('+%s Burglary XP', xp)
                Notify(s, label, 'success')
                TriggerClientEvent('m3_illegaltablet:cl:updateData', s, {
                    greenXP         = pd2.greenXP,
                    greenAccessible = GetGreenAccessible(pd2.greenXP),
                })
                SavePlayerData(id2, pd2)
            end
        end
    end
end

RegisterNetEvent('m3_illegaltablet:sv:burglary:deliverContract', function()
    local src = source

    pcall(RemoveItem, src, Config.BurglaryContractItem or 'contract', 1)

    local leaderSrc = playerCrewMap[src] or src

    local allSrcs = { leaderSrc }
    if activeCrew[leaderSrc] then
        for _, msrc in ipairs(activeCrew[leaderSrc].members) do
            allSrcs[#allSrcs + 1] = msrc
        end
    end

    local ac   = activeContracts[leaderSrc] or activeContracts[src]
    local conf = ac and ac.type == 'burglary' and ac.burglaryKey and Config.Burglaries[ac.burglaryKey]
    if conf then
        local xpR = math.random(conf.greenXPReward.min, conf.greenXPReward.max)
        DistributeXpReward(leaderSrc, xpR)
    end

    for _, s in ipairs(allSrcs) do
        if s == src then
            Notify(s, 'Contract handed over successfully!', 'success')
        else
            Notify(s, 'Your team handed over the contract successfully!', 'success')
        end
    end

    FinishContract(leaderSrc)
end)

local _robberyXpDone = {}

RegisterNetEvent('m3_illegaltablet:sv:robberyCompleted', function(key)
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local contract  = activeContracts[src]
    local pd, id    = GetPD(src)
    if not pd then return end
    local conf = Config.Robberies[key]
    if not conf then return end

    local allSrcs = { leaderSrc }
    if activeCrew[leaderSrc] then
        for _, msrc in ipairs(activeCrew[leaderSrc].members) do
            allSrcs[#allSrcs + 1] = msrc
        end
    end

    local contractId = contract and contract.id
    if not contractId or not _robberyXpDone[contractId] then

        if contractId then _robberyXpDone[contractId] = true end
        local xpR = math.random(conf.greenXPReward.min, conf.greenXPReward.max)
        DistributeXpReward(leaderSrc, xpR)

        if key == 'fleeca' then ScheduleFleecaReset() end
    end

    for i = #allSrcs, 1, -1 do
        FinishContract(allSrcs[i])
    end

    if contractId then _robberyXpDone[contractId] = nil end
end)

RegisterNetEvent('m3_illegaltablet:sv:crewRobberyCompleted', function(key)
end)

local _burglaryXpDone = {}

RegisterNetEvent('m3_illegaltablet:sv:burglaryCompleted', function(key)
    local src       = source
    local leaderSrc = playerCrewMap[src] or src
    local contract  = activeContracts[src]
    local pd, id    = GetPD(src)
    if not pd then return end
    local conf = Config.Burglaries[key]
    if not conf then return end

    local allSrcs = { leaderSrc }
    if activeCrew[leaderSrc] then
        for _, msrc in ipairs(activeCrew[leaderSrc].members) do
            allSrcs[#allSrcs + 1] = msrc
        end
    end

    local contractId = contract and contract.id
    if not contractId or not _burglaryXpDone[contractId] then
        if contractId then _burglaryXpDone[contractId] = true end
        local xpR = math.random(conf.greenXPReward.min, conf.greenXPReward.max)
        DistributeXpReward(leaderSrc, xpR)
    end

    for i = #allSrcs, 1, -1 do
        FinishContract(allSrcs[i])
    end
    if contractId then _burglaryXpDone[contractId] = nil end
end)

function GetLeaderboard()
    local rows = MySQL.query.await(
        'SELECT identifier, name, boosting_xp, burglary_xp FROM m3_tablet ORDER BY (boosting_xp + burglary_xp) DESC LIMIT 10',
        {})
    local out = {}
    for i, r in ipairs(rows or {}) do
        out[i] = {
            rank       = i,
            identifier = r.identifier,
            redXP      = r.boosting_xp,
            greenXP    = r.burglary_xp,
            playerName = r.name ~= '' and r.name or ('user_' .. string.format('%04d', r.identifier or 0)),
        }
    end
    return out
end

RegisterNetEvent('m3_illegaltablet:sv:fetchLeaderboard', function()
    local src  = source
    local data = GetLeaderboard()
    TriggerClientEvent('m3_illegaltablet:cl:leaderboardData', src, data)
end)

function BuildAllContractTypes(pd)
    local greenAcc = GetGreenAccessible(pd.greenXP)
    local greenSet = {}
    for _, cid in ipairs(greenAcc) do greenSet[cid] = true end

    local greenMinXP = {}
    for _, unlock in ipairs(Config.GreenXPUnlocks) do
        for _, cid in ipairs(unlock.contracts) do
            greenMinXP[cid] = unlock.minXP
        end
    end

    local list = {}

    for _, cat in pairs(Config.VehicleCategories) do
        local accessible = pd.redXP >= cat.minRedXP
        list[#list + 1] = {
            id      = cat.id,
            label   = cat.label,
            blocked = not accessible,
            minXP   = cat.minRedXP,
            xpType  = 'red',
        }
    end

    for key, conf in pairs(Config.Robberies) do
        local accessible = greenSet[conf.id]
        list[#list + 1] = {
            id      = conf.id,
            label   = conf.label,
            blocked = not accessible,
            minXP   = greenMinXP[conf.id] or 0,
            xpType  = 'green',
        }
    end

    for key, conf in pairs(Config.Burglaries) do
        local accessible = greenSet[conf.id]
        list[#list + 1] = {
            id      = conf.id,
            label   = conf.label,
            blocked = not accessible,
            minXP   = greenMinXP[conf.id] or 0,
            xpType  = 'green',
        }
    end

    return list
end

local LOCATIONS_FILE = 'burglary_locations.json'

local function LoadSavedLocations()
    local raw = LoadResourceFile(GetCurrentResourceName(), LOCATIONS_FILE)
    if not raw or raw == '' then return end

    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then
        print('^3[m3_illegaltablet] burglary_locations.json parse error - skipping^7')
        return
    end

    local count = 0
    for burglaryKey, locs in pairs(data) do
        local conf = Config.Burglaries[burglaryKey]
        if conf and type(locs) == 'table' then
            for _, loc in ipairs(locs) do
                table.insert(conf.locations, {
                    exterior = vector4(loc.x, loc.y, loc.z, loc.w)
                })
                count = count + 1
            end
        end
    end
    if count > 0 then
        print(string.format('^2[m3_illegaltablet] Loaded %d custom burglary locations^7', count))
    end
end

LoadSavedLocations()

local function ReadLocationsFile()
    local raw = LoadResourceFile(GetCurrentResourceName(), LOCATIONS_FILE)
    if not raw or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    return (ok and type(data) == 'table') and data or {}
end

RegisterNetEvent('m3_illegaltablet:sv:admin:addLocation', function(burglaryKey, x, y, z, w)
    local src = source

    local isAdmin = IsPlayerAceAllowed(src, 'command.houserobbery')
    if not isAdmin then
        local player = Ox:GetPlayer(src)
        if player then
            local grp = player.group
            if not grp and player.groups then
                for g, _ in pairs(player.groups) do grp = g; break end
            end
            isAdmin = (grp == 'admin' or grp == 'superadmin')
        end
    end

    if not isAdmin then
        TriggerClientEvent('m3_illegaltablet:cl:admin:error', src,
            'You do not have permission for this command.')
        return
    end

    if not Config.Burglaries[burglaryKey] then
        TriggerClientEvent('m3_illegaltablet:cl:admin:error', src,
            string.format('Unknown burglary type: %s', burglaryKey))
        return
    end

    x = math.floor(x * 1000 + 0.5) / 1000
    y = math.floor(y * 1000 + 0.5) / 1000
    z = math.floor(z * 1000 + 0.5) / 1000
    w = math.floor(w * 100  + 0.5) / 100

    table.insert(Config.Burglaries[burglaryKey].locations, {
        exterior = vector4(x, y, z, w)
    })
    local total = #Config.Burglaries[burglaryKey].locations

    local fileData = ReadLocationsFile()
    if not fileData[burglaryKey] then fileData[burglaryKey] = {} end
    table.insert(fileData[burglaryKey], { x = x, y = y, z = z, w = w })

    local encoded = json.encode(fileData, { indent = true })
    local saved   = SaveResourceFile(GetCurrentResourceName(), LOCATIONS_FILE, encoded, -1)

    if not saved then
        TriggerClientEvent('m3_illegaltablet:cl:admin:error', src,
            'Error saving the file. Check the folder permissions.')
        return
    end

    TriggerClientEvent('m3_illegaltablet:cl:admin:locationSaved', src,
        burglaryKey, x, y, z, w, total)

    print(string.format(
        '^2[m3_illegaltablet] Admin %s added a location for [%s]: %.3f, %.3f, %.3f (%.2f deg) | Total: %d^7',
        GetPlayerName(src), burglaryKey, x, y, z, w, total))
end)
