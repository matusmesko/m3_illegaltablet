
activeContracts = {}

local activeBurglaryLocs = {}

function FindFreeLocIdx(burglaryKey, numLocs)
    local used = activeBurglaryLocs[burglaryKey] or {}
    local indices = {}
    for i = 1, numLocs do indices[i] = i end

    for i = numLocs, 2, -1 do
        local j = math.random(i)
        indices[i], indices[j] = indices[j], indices[i]
    end
    for _, idx in ipairs(indices) do
        if not used[idx] then return idx end
    end
    return math.random(numLocs)
end

function LockBurglaryLoc(burglaryKey, locIdx, src)
    if not activeBurglaryLocs[burglaryKey] then
        activeBurglaryLocs[burglaryKey] = {}
    end
    activeBurglaryLocs[burglaryKey][locIdx] = src
end

function FreeBurglaryLoc(src)
    for key, idxMap in pairs(activeBurglaryLocs) do
        for idx, s in pairs(idxMap) do
            if s == src then
                activeBurglaryLocs[key][idx] = nil
                return
            end
        end
    end
end

local function CanAccessVehicle(pd, cat)
    return pd.redXP >= (cat.minRedXP or 0)
end

local function GreenAccessSet(pd)
    local set = {}
    for _, unlock in ipairs(Config.GreenXPUnlocks) do
        if pd.greenXP >= unlock.minXP then
            for _, cid in ipairs(unlock.contracts) do
                set[cid] = true
            end
        end
    end
    return set
end

local function InFilter(pd, contractId)
    if pd.contractFilter == nil then return true end
    if #pd.contractFilter   == 0 then return false end
    for _, f in ipairs(pd.contractFilter) do
        if f == contractId then return true end
    end
    return false
end

local function MakeVehicleOffer(cat, conf)
    local zone   = conf.spawnZones[math.random(#conf.spawnZones)]
    local model  = conf.vehicles[math.random(#conf.vehicles)]
    local del    = conf.deliveryPoints[math.random(#conf.deliveryPoints)]
    local reward = math.random(conf.reward.min, conf.reward.max)

    return {
        id           = conf.id .. '_' .. math.random(100000, 999999),
        contractKey  = conf.id,
        type         = 'vehicle_theft',
        category     = cat,
        label        = conf.label,
        reward       = reward,
        vehicleModel = model,
        spawnZone    = { x = zone.coords.x, y = zone.coords.y,
                         z = zone.coords.z, radius = zone.radius },
        deliveryPoint = {
            coords   = { x = del.coords.x, y = del.coords.y,
                         z = del.coords.z, w = del.coords.w },
            npcModel = del.npcModel,
            label    = del.label,
        },
        timeLimit     = conf.timeLimit,
        needsLocator  = conf.needsLocator,
        lockpickDiff  = conf.lockpickDiff,
        hackDiff      = conf.hackDiff,
        needsHack     = conf.carHack ~= nil,
        hackCount     = conf.carHack and conf.carHack.count or nil,
        requiredItems = Config.RequiredItems[conf.id] or {},
        isSpecial     = (conf.tuning or 0) > 0 and math.random(100) <= (conf.tuning or 0),
    }
end

local function MakeRobberyOffer(key, conf)
    return {
        id            = conf.id .. '_' .. math.random(100000, 999999),
        contractKey   = conf.id,
        type          = 'robbery',
        robberyKey    = key,
        label         = conf.label,
        timeLimit     = conf.timeLimit,
        requiredItems = Config.RequiredItems[conf.id] or {},
    }
end

local function MakeBurglaryOffer(key, conf)
    return {
        id            = conf.id .. '_' .. math.random(100000, 999999),
        contractKey   = conf.id,
        type          = 'burglary',
        burglaryKey   = key,
        label         = conf.label,
        timeLimit     = conf.timeLimit,
        locationIndex = math.random(#conf.locations),
        requiredItems = Config.RequiredItems[conf.id] or {},
    }
end

local function BuildPool(pd)
    local pool     = {}
    local greenSet = GreenAccessSet(pd)

    for cat, conf in pairs(Config.VehicleCategories) do
        if CanAccessVehicle(pd, conf) and InFilter(pd, conf.id) then
            pool[#pool + 1] = MakeVehicleOffer(cat, conf)
        end
    end
    for key, conf in pairs(Config.Robberies) do
        if greenSet[conf.id] and InFilter(pd, conf.id) then
            pool[#pool + 1] = MakeRobberyOffer(key, conf)
        end
    end
    for key, conf in pairs(Config.Burglaries) do
        if greenSet[conf.id] and InFilter(pd, conf.id) then
            pool[#pool + 1] = MakeBurglaryOffer(key, conf)
        end
    end

    return pool
end

local function PickRandom(tbl, n)
    local copy = {}
    for _, v in ipairs(tbl) do copy[#copy + 1] = v end

    for i = #copy, 2, -1 do
        local j = math.random(i)
        copy[i], copy[j] = copy[j], copy[i]
    end

    local out = {}
    for i = 1, math.min(n, #copy) do
        out[i] = copy[i]
    end
    return out
end

function RegenerateOffers(src, pd)
    local pool = BuildPool(pd)
    pd.offers        = PickRandom(pool, Config.ContractOffersCount)
    pd.nextRotation  = os.time() + Config.ContractRotationInterval
end

function PruneOffers(pd)
    local now  = os.time()
    local kept = {}
    for _, o in ipairs(pd.offers or {}) do
        if o.expiresAt and o.expiresAt > now then
            kept[#kept + 1] = o
        end
    end
    pd.offers = kept
end

function CheckRotation(src, pd)
    if Config.DebugContracts then
        if os.time() >= pd.nextRotation then
            RegenerateOffers(src, pd)
        end
    else
        PruneOffers(pd)
    end
end

local contractsEnabled = {}
local typeCooldownUntil = {}
local lastDropAt        = {}

function ContractsReceivingEnabled(src)
    if Config.DebugContracts then return true end
    return contractsEnabled[src] == true
end

function SetContractTypeCooldown(contractKey)
    if Config.DebugContracts or not contractKey or contractKey == '' then return end
    local dist = Config.ContractDistribution
    local cd   = (dist.cooldowns and dist.cooldowns[contractKey]) or dist.acceptCooldown or 1800
    typeCooldownUntil[contractKey] = os.time() + cd
end

RegisterNetEvent('m3_illegaltablet:sv:setReceiving', function(enabled)
    local src = source
    contractsEnabled[src] = enabled == true
    if Config.ContractDistribution.debugLog then
        print(('[m3_illegaltablet] setReceiving: player %d -> %s')
            :format(src, tostring(contractsEnabled[src])))
    end
    if not Config.DebugContracts then
        Notify(src, contractsEnabled[src]
            and 'Contract intake ENABLED.'
            or  'Contract intake DISABLED.', 'inform')
    end
end)

AddEventHandler('playerDropped', function()
    contractsEnabled[source] = nil
end)

local function BuildTypeRegistry()
    local reg = {}
    for cat, conf in pairs(Config.VehicleCategories) do
        reg[conf.id] = { kind = 'vehicle', cat = cat, conf = conf }
    end
    for key, conf in pairs(Config.Robberies) do
        reg[conf.id] = { kind = 'robbery', key = key, conf = conf }
    end
    for key, conf in pairs(Config.Burglaries) do
        reg[conf.id] = { kind = 'burglary', key = key, conf = conf }
    end
    return reg
end

local function BuildOfferOfType(entry)
    if entry.kind == 'vehicle'  then return MakeVehicleOffer(entry.cat, entry.conf) end
    if entry.kind == 'robbery'  then return MakeRobberyOffer(entry.key, entry.conf) end
    if entry.kind == 'burglary' then return MakeBurglaryOffer(entry.key, entry.conf) end
    return nil
end

local function EligibleForType(pd, greenSet, entry)
    local id = entry.conf.id
    if not InFilter(pd, id) then return false end
    if entry.kind == 'vehicle' then
        return CanAccessVehicle(pd, entry.conf)
    end
    return greenSet[id] == true
end

local function HasOfferOfType(pd, contractKey)
    for _, o in ipairs(pd.offers or {}) do
        if o.contractKey == contractKey then return true end
    end
    return false
end

local function WeightedPick(cands, n)
    local pool = {}
    for i, c in ipairs(cands) do pool[i] = c end
    local out = {}
    while #out < n and #pool > 0 do
        local total = 0
        for _, c in ipairs(pool) do total = total + c.w end
        local r, acc  = math.random() * total, 0
        local pickIdx = #pool
        for i, c in ipairs(pool) do
            acc = acc + c.w
            if r <= acc then pickIdx = i; break end
        end
        out[#out + 1] = pool[pickIdx].p
        table.remove(pool, pickIdx)
    end
    return out
end

local function RunContractWave()
    local now  = os.time()
    local dist = Config.ContractDistribution
    local dbg  = dist.debugLog

    local allPlayers  = GetPlayers()
    local policeCount = 0
    if (dist.minPolice or 0) > 0 then
        for _, ps in ipairs(allPlayers) do
            if IsPolice(tonumber(ps)) then policeCount = policeCount + 1 end
        end
        if policeCount < dist.minPolice then
            if dbg then
                print(('[m3_illegaltablet] Wave skipped: police %d/%d on duty')
                    :format(policeCount, dist.minPolice))
            end
            return
        end
    end

    local players = {}
    local nEnabled, nBusy, nNoData = 0, 0, 0
    for _, ps in ipairs(allPlayers) do
        local src = tonumber(ps)
        if contractsEnabled[src] then
            nEnabled = nEnabled + 1
            if activeContracts[src] then
                nBusy = nBusy + 1
            else
                local pd, id = GetPD(src)
                if pd then
                    PruneOffers(pd)
                    players[#players + 1] = { src = src, id = id, pd = pd,
                                              green = GreenAccessSet(pd) }
                else
                    nNoData = nNoData + 1
                end
            end
        end
    end
    if dbg then
        print(('[m3_illegaltablet] Wave: online=%d, accepting=%d, busy=%d, noData=%d, candidates=%d')
            :format(#allPlayers, nEnabled, nBusy, nNoData, #players))
    end
    if #players == 0 then return end

    local registry = BuildTypeRegistry()
    local typeIds  = {}
    for tid in pairs(registry) do typeIds[#typeIds + 1] = tid end
    for i = #typeIds, 2, -1 do
        local j = math.random(i)
        typeIds[i], typeIds[j] = typeIds[j], typeIds[i]
    end

    local touched  = {}
    local lifetime = dist.offerLifetime or (dist.interval * 2)

    for _, typeId in ipairs(typeIds) do
        if (typeCooldownUntil[typeId] or 0) <= now then
            local entry = registry[typeId]
            local maxN  = (dist.maxPerInterval and dist.maxPerInterval[typeId])
                or dist.defaultMaxPerInterval or 3

            local cands = {}
            for _, p in ipairs(players) do
                if #p.pd.offers < Config.ContractOffersCount
                and not HasOfferOfType(p.pd, typeId)
                and EligibleForType(p.pd, p.green, entry) then

                    local w  = 1.0
                    local ld = lastDropAt[p.id]
                    if ld and (now - ld) < (dist.recentWindow or 1800) then
                        w = dist.recentWeight or 0.3
                    end
                    cands[#cands + 1] = { p = p, w = w }
                end
            end

            local picked = WeightedPick(cands, maxN)
            if dbg and #cands > 0 then
                print(('[m3_illegaltablet]   type %s: candidates=%d, drops=%d')
                    :format(typeId, #cands, #picked))
            end
            for _, p in ipairs(picked) do
                local offer = BuildOfferOfType(entry)
                if offer then
                    offer.expiresAt = now + lifetime
                    table.insert(p.pd.offers, offer)
                    lastDropAt[p.id] = now
                    touched[p.src]   = p
                end
            end
        elseif dbg then
            print(('[m3_illegaltablet]   type %s: on cooldown for %ds more')
                :format(typeId, (typeCooldownUntil[typeId] or 0) - now))
        end
    end

    local dropped = 0
    for src, p in pairs(touched) do
        dropped = dropped + 1
        TriggerClientEvent('m3_illegaltablet:cl:updateData', src, { contracts = p.pd.offers })
        Notify(src, 'A new contract landed in your tablet!', 'inform')
    end
    if dbg then
        print(('[m3_illegaltablet] Wave done: offers dropped to %d players'):format(dropped))
    end
end

CreateThread(function()
    local dist = Config.ContractDistribution or {}
    if not Config.DebugContracts then
        print(('[m3_illegaltablet] Contract distribution ACTIVE: wave every %ds, minPolice=%d')
            :format(dist.interval or 600, dist.minPolice or 0))
    end
    while true do
        Wait(((Config.ContractDistribution and Config.ContractDistribution.interval) or 600) * 1000)
        if not Config.DebugContracts then
            local ok, err = pcall(RunContractWave)
            if not ok then
                print('[m3_illegaltablet] RunContractWave ERROR: ' .. tostring(err))
            end
        end
    end
end)

RegisterCommand('m3wave', function(src)
    if src ~= 0 and not IsPlayerAceAllowed(tostring(src), 'group.admin') then return end
    if Config.DebugContracts then
        print('[m3_illegaltablet] m3wave: Config.DebugContracts = true -> waves are disabled')
        return
    end
    print('[m3_illegaltablet] m3wave: running a wave manually...')
    local ok, err = pcall(RunContractWave)
    if not ok then
        print('[m3_illegaltablet] RunContractWave ERROR: ' .. tostring(err))
    end
end, true)
