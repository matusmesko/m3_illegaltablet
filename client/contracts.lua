
local activeBlip        = nil
local activeRadiusBlip  = nil
contractRunning         = false
local spawnedVehicle    = nil
local spawnedGuards     = {}

local _carHackCallback   = nil

local _carHackInProgress = false

local _crewVehicleNetId  = nil
local _crewVehicleBlipPos = nil

local _sharedHacksLeft      = nil
local _sharedHackDone       = false

local _crewVehicleLockpicked = false

local _crewVehicleDelivered  = false

local _burglaryBoxCallbacks   = {}
local _crewBurglaryLockpicked = false
local _burglaryNpcPos         = nil
local _burglaryNpcModel       = nil
local _burglaryDelivered      = false
local _burglaryContractFound  = false
local _burglaryBoxSync        = nil
local _burglarySealedId       = nil

local _shopSharedFear   = 0.0
local _shopNpcNetId     = nil
local _shopBagPosition  = nil
local _shopContractDone = false
local _shopCrewAimUntil = 0

local _fleecaVaultHacked  = false
local _fleecaBarsHacked   = false
local _fleecaAllGrabbed   = false
local _fleecaTrolleyData  = nil
local _fleecaGrabbing     = false

local function StartTrolleyFreezer(netId)
    if not netId or netId == 0 then return end
    CreateThread(function()
        local deadline = GetGameTimer() + 30 * 60 * 1000
        local seen     = false
        while GetGameTimer() < deadline do
            if NetworkDoesNetworkIdExist(netId) then
                local ent = NetworkGetEntityFromNetworkId(netId)
                if ent ~= 0 and DoesEntityExist(ent) then
                    seen = true
                    SetEntityDynamic(ent, false)
                    FreezeEntityPosition(ent, true)

                    if GetInteriorFromEntity(ent) == 0 then
                        local myInt = GetInteriorFromEntity(PlayerPedId())
                        if myInt ~= 0 then
                            ForceRoomForEntity(ent, myInt, GetRoomKeyFromEntity(PlayerPedId()))
                        end
                    end
                end
            elseif seen then
                return
            end
            Wait(2000)
        end
    end)
end

local _bobcatDoorHacked  = false
local _bobcatVaultBlown  = false
local _bobcatCrateLooted = false

CreateThread(function()
    local bconf = Config.Robberies and Config.Robberies.bobcat
    if not bconf or not bconf.ipl then return end
    RequestIpl(bconf.ipl)
    local t = 0
    while not IsIplActive(bconf.ipl) and t < 15000 do Wait(200); t = t + 200 end
    if bconf.interiorCoords then
        local intId = GetInteriorAtCoords(bconf.interiorCoords.x,
            bconf.interiorCoords.y, bconf.interiorCoords.z)
        if intId ~= 0 then
            ActivateInteriorEntitySet(intId, 'np_prolog_clean')
            RefreshInterior(intId)
        end
    end
end)

local function SendDispatchOnce(sent, contractKey, coords, extraData)
    if sent then return true end
    if Dispatch and Dispatch.robbery then
        Dispatch.robbery(contractKey, coords, extraData)
    end
    return true
end

local _gta_colors = {
    [0]='Black',[1]='Black',[2]='Graphite',[3]='Matte black',[4]='Matte black',
    [5]='Yellow',[6]='Gold',[7]='Orange',[8]='Orange',[9]='Matte orange',
    [10]='Green',[11]='Green',[12]='Dark green',[13]='Matte green',[14]='Turquoise',
    [15]='Light blue',[16]='Blue',[17]='Blue',[18]='Dark blue',[19]='Matte blue',
    [20]='Purple',[21]='Pink',[22]='Pink',[23]='Red',[24]='Red',
    [25]='Dark red',[26]='Matte red',[27]='Red',[28]='Red',[29]='Red',
    [30]='Beige',[31]='Brown',[32]='Brown',[33]='Matte brown',[34]='Brown',
    [35]='Cream',[36]='White',[37]='White',[38]='White',[39]='Matte white',
    [40]='Silver',[41]='Gray',[42]='Gray',[43]='Matte gray',[44]='Gray',
    [45]='Dark silver',[46]='Silver',[47]='Matte silver',[48]='Silver',
    [49]='Gold',[50]='Matte gold',[51]='Gold',[52]='Bronze',[53]='Yellow',
    [111]='White',[112]='White',
}
local function GetVehicleColorName(veh)
    local primary, _ = GetVehicleColours(veh)
    return _gta_colors[primary] or 'Unknown'
end

local _vehicleLockpicked = false

local function AssertVehicleUnlocked(veh)
    CreateThread(function()
        local deadline = GetGameTimer() + 30000
        while GetGameTimer() < deadline and DoesEntityExist(veh) do
            if NetworkHasControlOfEntity(veh) then
                if GetVehicleDoorLockStatus(veh) ~= 1 then
                    SetVehicleDoorsLocked(veh, 1)
                end
                SetVehicleNeedsToBeHotwired(veh, false)
            end
            Wait(500)
        end
    end)
end

RegisterNetEvent('m3_illegaltablet:cl:carHackItemUsed', function()
    if _carHackCallback and not _carHackInProgress then
        _carHackCallback()
    end
end)

RegisterNetEvent('m3_illegaltablet:cl:crewVehicleBlip', function(bx, by)
    _crewVehicleBlipPos = { x = bx, y = by }
end)

RegisterNetEvent('m3_illegaltablet:cl:crewVehicleReady', function(netId)
    _crewVehicleNetId = netId
end)

RegisterNetEvent('m3_illegaltablet:cl:crewCarHackSync', function(hacksLeft, done)
    _sharedHacksLeft = hacksLeft
    if done then _sharedHackDone = true end
end)

RegisterNetEvent('m3_illegaltablet:cl:crewVehicleLockpicked', function()
    _crewVehicleLockpicked = true
end)

RegisterNetEvent('m3_illegaltablet:cl:crewVehicleDelivered', function()
    _crewVehicleDelivered = true
end)

RegisterNetEvent('m3_illegaltablet:cl:shopCrewAiming', function()
    _shopCrewAimUntil = GetGameTimer() + 800
end)

RegisterNetEvent('m3_illegaltablet:cl:crewBurglaryLockpicked', function()
    _crewBurglaryLockpicked = true
end)

RegisterNetEvent('m3_illegaltablet:cl:burglarySealed', function(contractId)
    _burglarySealedId = contractId
end)
RegisterNetEvent('m3_illegaltablet:cl:crewBoxSearched', function(boxIndex)
    local cb = _burglaryBoxCallbacks[boxIndex]
    if cb then
        _burglaryBoxCallbacks[boxIndex] = nil
        cb()
    end
end)
RegisterNetEvent('m3_illegaltablet:cl:burglaryNpcReady', function(x, y, z, w, model)
    _burglaryNpcPos   = vector4(x, y, z, w)
    _burglaryNpcModel = model
end)
RegisterNetEvent('m3_illegaltablet:cl:burglaryContractFound', function()
    _burglaryContractFound = true
end)
RegisterNetEvent('m3_illegaltablet:cl:burglaryDelivered', function()
    _burglaryDelivered = true
end)

RegisterNetEvent('m3_illegaltablet:cl:burglaryBoxSync', function(positions)
    _burglaryBoxSync = positions
end)

RegisterNetEvent('m3_illegaltablet:cl:shopNpcReady', function(netId)
    _shopNpcNetId = netId
end)
RegisterNetEvent('m3_illegaltablet:cl:shopFearSync', function(pct)
    _shopSharedFear = pct
end)
RegisterNetEvent('m3_illegaltablet:cl:shopBagReady', function(x, y, z)
    _shopBagPosition = vector3(x, y, z)
end)
RegisterNetEvent('m3_illegaltablet:cl:shopContractDone', function()
    _shopContractDone = true
end)

RegisterNetEvent('m3_illegaltablet:cl:fleecaVaultHacked', function()
    _fleecaVaultHacked = true
end)
RegisterNetEvent('m3_illegaltablet:cl:fleecaBarsHacked', function()
    _fleecaBarsHacked = true
end)

RegisterNetEvent('m3_illegaltablet:cl:fleecaTrolleys', function(data, barsOpen)
    _fleecaTrolleyData = data
    _fleecaVaultHacked = true
    if barsOpen then _fleecaBarsHacked = true end
end)

RegisterNetEvent('m3_illegaltablet:cl:fleecaTrolleyFreeze', function(netIds)
    for _, nid in ipairs(netIds or {}) do StartTrolleyFreezer(nid) end
end)

RegisterNetEvent('m3_illegaltablet:cl:fleecaTrolleyEmpty', function(idx, newNetId)
    if _fleecaTrolleyData and _fleecaTrolleyData[idx] then
        _fleecaTrolleyData[idx].empty = true
    end
end)

RegisterNetEvent('m3_illegaltablet:cl:fleecaAllEmpty', function()
    _fleecaAllGrabbed = true
    Notify('All the money is out! Flee the scene.', 'success')
end)

RegisterNetEvent('m3_illegaltablet:cl:bobcatDoorHacked', function()
    _bobcatDoorHacked = true
end)
RegisterNetEvent('m3_illegaltablet:cl:bobcatVaultBlown', function()

    _bobcatVaultBlown = true
end)
RegisterNetEvent('m3_illegaltablet:cl:bobcatCrateLooted', function()
    _bobcatCrateLooted = true
end)

local _truck = nil
local _truckBagProps = {}

local function ClearTruckBagProps()
    for _, p in ipairs(_truckBagProps) do
        if DoesEntityExist(p) then DeleteObject(p) end
    end
    _truckBagProps = {}
end

local function SpawnTruckBagProps(veh)
    local conf = (Config.Robberies and Config.Robberies.truck) or {}
    local offsets = conf.bagOffsets or {}
    local count = math.min((_truck and _truck.bags) or 0, #offsets)
    if count <= 0 then return end

    local model = joaat(conf.bagProp or 'prop_money_bag_01')
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 3000 do Wait(50); t = t + 50 end
    if not HasModelLoaded(model) then

        model = joaat('prop_money_bag_01')
        RequestModel(model)
        t = 0
        while not HasModelLoaded(model) and t < 3000 do Wait(50); t = t + 50 end
        if not HasModelLoaded(model) then return end
    end

    ClearTruckBagProps()
    for i = 1, count do
        local off = offsets[i]
        local pos = GetOffsetFromEntityInWorldCoords(veh, off.x, off.y, off.z)
        local obj = CreateObject(model, pos.x, pos.y, pos.z, false, false, false)
        AttachEntityToEntity(obj, veh, 0, off.x, off.y, off.z,
            0.0, 0.0, math.random(0, 359) + 0.0, false, false, false, false, 2, true)
        _truckBagProps[#_truckBagProps + 1] = obj
    end
    SetModelAsNoLongerNeeded(model)
end

local function BreakTruckRearDoors(veh, method)
    CreateThread(function()
        local t = 0
        NetworkRequestControlOfEntity(veh)
        while not NetworkHasControlOfEntity(veh) and t < 2000 do
            NetworkRequestControlOfEntity(veh); Wait(50); t = t + 50
        end
        if not DoesEntityExist(veh) then return end
        SetVehicleDoorsLocked(veh, 1)
        for _, d in ipairs({ 2, 3, 5 }) do
            if GetIsDoorValid(veh, d) then
                if method == 'drill' then
                    SetVehicleDoorOpen(veh, d, false, false)
                else
                    SetVehicleDoorBroken(veh, d, false)
                end
            end
        end
    end)
end

RegisterNetEvent('m3_illegaltablet:cl:truckData', function(d)
    _truck = _truck or {}
    _truck.vehNet    = d.vehNet
    _truck.driverNet = d.driverNet
    _truck.guardNet  = d.guardNet
    _truck.phase     = d.phase
    _truck.bags      = d.bags
    if d.engaged then
        _truck.engaged = true
        AddRelationshipGroup('M3_TRUCK_GUARD')
        SetRelationshipBetweenGroups(5, GetHashKey('M3_TRUCK_GUARD'), GetHashKey('PLAYER'))
        SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), GetHashKey('M3_TRUCK_GUARD'))
    end

    if d.phase == 'blown' and #_truckBagProps == 0 and (d.bags or 0) > 0 then
        CreateThread(function()
            local deadline = GetGameTimer() + 10000
            while GetGameTimer() < deadline do
                local veh = d.vehNet and NetworkGetEntityFromNetworkId(d.vehNet) or 0
                if veh and veh ~= 0 and DoesEntityExist(veh) then

                    BreakTruckRearDoors(veh, 'drill')
                    SpawnTruckBagProps(veh)
                    return
                end
                Wait(500)
            end
        end)
    end
end)

RegisterNetEvent('m3_illegaltablet:cl:truckPos', function(x, y, z)
    _truck = _truck or {}
    _truck.circle = { x = x, y = y, z = z }
end)

RegisterNetEvent('m3_illegaltablet:cl:truckGuardsDead', function()
    if _truck then _truck.phase = 'stopped' end
end)

RegisterNetEvent('m3_illegaltablet:cl:truckEngage', function()
    if _truck then _truck.engaged = true end
    AddRelationshipGroup('M3_TRUCK_GUARD')
    SetRelationshipBetweenGroups(5, GetHashKey('M3_TRUCK_GUARD'), GetHashKey('PLAYER'))
    SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), GetHashKey('M3_TRUCK_GUARD'))
end)

RegisterNetEvent('m3_illegaltablet:cl:truckC4Planted', function(fuseMs)
    if _truck then _truck.phase = 'fused' end
    Notify(('C4 set! Back away from the doors! (%ds)'):format(math.floor((fuseMs or 5000) / 1000)), 'error')
end)

RegisterNetEvent('m3_illegaltablet:cl:truckBlown', function(_planterSrc, method)
    if _truck then _truck.phase = 'blown' end
    local veh = _truck and _truck.vehNet and NetworkGetEntityFromNetworkId(_truck.vehNet) or 0
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        if method ~= 'drill' then
            local coords = GetEntityCoords(veh)
            local back   = coords - GetEntityForwardVector(veh) * 2.6
            AddExplosion(back.x, back.y, back.z, 2, 0.6, true, false, 0.6)
        end
        BreakTruckRearDoors(veh, method)
        SpawnTruckBagProps(veh)
    end
    Notify(method == 'drill'
        and 'Lock drilled! Grab the money bags.'
        or  'Rear doors blown! Grab the money bags.', 'success')
end)

RegisterNetEvent('m3_illegaltablet:cl:truckBagTaken', function(remaining)
    if _truck then _truck.bags = remaining end
    local prop = table.remove(_truckBagProps)
    if prop and DoesEntityExist(prop) then DeleteObject(prop) end
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local st = _truck
    if not st or st.engaged or st.phase ~= 'drive' or not contractRunning then return end

    local victim = args[1]
    if not victim or victim == 0 or not DoesEntityExist(victim) then return end
    if not NetworkGetEntityIsNetworked(victim) then return end

    local vNet = NetworkGetNetworkIdFromEntity(victim)
    if vNet ~= st.driverNet and vNet ~= st.guardNet and vNet ~= st.vehNet then return end

    local attacker = args[2]
    local isPlayerAttack = false
    if attacker and attacker ~= 0 and DoesEntityExist(attacker) then
        if IsEntityAPed(attacker) and IsPedAPlayer(attacker) then
            isPlayerAttack = true
        elseif IsEntityAVehicle(attacker) then
            local drv = GetPedInVehicleSeat(attacker, -1)
            isPlayerAttack = drv ~= 0 and IsPedAPlayer(drv)
        end
    end
    if not isPlayerAttack then return end

    st.engaged = true
    TriggerServerEvent('m3_illegaltablet:sv:truckEngage')
end)

local _jewelry        = nil
local _jewelryZones   = {}
local _jewelryAlarmOn = false

local function JewelryCleanupZones()
    for idx, zid in pairs(_jewelryZones) do
        exports.ox_target:removeZone(zid)
        _jewelryZones[idx] = nil
    end
end

local function JewelryStopAlarm()
    if _jewelryAlarmOn then
        StopAlarm('JEWEL_STORE_HEIST_ALARMS', true)
        _jewelryAlarmOn = false
    end
end

RegisterNetEvent('m3_illegaltablet:cl:jewelryData', function(d)
    _jewelry = _jewelry or {}
    _jewelry.cases       = d.cases
    _jewelry.smashed     = d.smashed or {}
    _jewelry.required    = d.required
    _jewelry.doorDrilled = d.doorDrilled
end)

RegisterNetEvent('m3_illegaltablet:cl:jewelryDoorDrilled', function()
    if _jewelry then _jewelry.doorDrilled = true end
end)

RegisterNetEvent('m3_illegaltablet:cl:jewelryAlarm', function(isReporter)
    local conf = (Config.Robberies and Config.Robberies.jewelry) or {}
    if conf.alarmSound and not _jewelryAlarmOn then
        _jewelryAlarmOn = true
        CreateThread(function()
            PrepareAlarm('JEWEL_STORE_HEIST_ALARMS')
            Wait(300)
            StartAlarm('JEWEL_STORE_HEIST_ALARMS', false)
        end)
    end
    if isReporter and Dispatch and Dispatch.robbery then
        Dispatch.robbery('robbery_jewelry', conf.location or GetEntityCoords(PlayerPedId()))
    end
end)

RegisterNetEvent('m3_illegaltablet:cl:jewelryCaseSmashed', function(idx, remaining)
    if _jewelry then _jewelry.smashed[idx] = true end
    local zid = _jewelryZones[idx]
    if zid then
        exports.ox_target:removeZone(zid)
        _jewelryZones[idx] = nil
    end
end)

RegisterNetEvent('m3_illegaltablet:cl:jewelryDone', function(isFinisher)
    JewelryCleanupZones()
    JewelryStopAlarm()
    if contractRunning then
        contractRunning = false
        if isFinisher then
            TriggerServerEvent('m3_illegaltablet:sv:robberyCompleted', 'jewelry')
        else
            TriggerServerEvent('m3_illegaltablet:sv:crewRobberyCompleted', 'jewelry')
        end
    end
end)

local _labs      = nil
local _labsZones = {}
local _labsProps = {}

local function LabsCleanup()
    for idx, zid in pairs(_labsZones) do
        exports.ox_target:removeZone(zid)
        _labsZones[idx] = nil
    end
    for idx, obj in pairs(_labsProps) do
        if DoesEntityExist(obj) then DeleteObject(obj) end
        _labsProps[idx] = nil
    end
end

local _labsLocalGuards = nil

local function RemoveLocalLabsGuards()
    if not _labsLocalGuards then return end
    for _, ped in pairs(_labsLocalGuards.peds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    _labsLocalGuards = nil
end

RegisterNetEvent('m3_illegaltablet:cl:labsGuardsSpawn', function(heistId, deadMap)
    local lconf = Config.Robberies and Config.Robberies.humanelabs
    if not lconf or not lconf.guards then return end
    if _labsLocalGuards then
        if _labsLocalGuards.heistId == heistId then return end
        RemoveLocalLabsGuards()
    end
    _labsLocalGuards = { heistId = heistId, peds = {} }
    local my = _labsLocalGuards

    CreateThread(function()

        local a = lconf.guards[1].coords
        while _labsLocalGuards == my do
            if #(GetEntityCoords(PlayerPedId()) - vector3(a.x, a.y, a.z)) < 150.0 then break end
            Wait(1000)
        end
        if _labsLocalGuards ~= my then return end

        local model = joaat(lconf.guardModel or 's_m_m_chemsec_01')
        RequestModel(model)
        local mt = 0
        while not HasModelLoaded(model) and mt < 5000 do Wait(50); mt = mt + 50 end
        if not HasModelLoaded(model) then return end

        AddRelationshipGroup('M3_LABS_GUARD')
        local grp = GetHashKey('M3_LABS_GUARD')
        SetRelationshipBetweenGroups(5, grp, GetHashKey('PLAYER'))
        SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), grp)

        for i, gd in ipairs(lconf.guards) do
            if not (deadMap and (deadMap[i] or deadMap[tostring(i)])) and _labsLocalGuards == my then
                RequestCollisionAtCoord(gd.coords.x, gd.coords.y, gd.coords.z)
                local ped = CreatePed(4, model,
                    gd.coords.x, gd.coords.y, gd.coords.z - 1.0, gd.coords.w or 0.0,
                    false, false)
                if DoesEntityExist(ped) then
                    SetEntityAsMissionEntity(ped, true, true)
                    local hp = lconf.guardHealth or 400
                    SetPedMaxHealth(ped, hp)
                    SetEntityHealth(ped, hp)
                    SetPedSuffersCriticalHits(ped, false)
                    SetPedCanRagdoll(ped, false)
                    SetRagdollBlockingFlags(ped, 1 | 32 | 128)
                    SetPedConfigFlag(ped, 281, true)
                    SetPedArmour(ped, gd.armor or 100)
                    GiveWeaponToPed(ped, GetHashKey(gd.weapon or 'WEAPON_PISTOL'), 9999, false, true)
                    SetPedInfiniteAmmo(ped, true, GetHashKey(gd.weapon or 'WEAPON_PISTOL'))
                    SetPedDropsWeaponsWhenDead(ped, false)
                    SetPedRelationshipGroupHash(ped, grp)
                    SetBlockingOfNonTemporaryEvents(ped, true)
                    SetPedFleeAttributes(ped, 0, false)
                    SetPedCombatAttributes(ped, 46, true)
                    SetPedCombatMovement(ped, 0)
                    SetPedAccuracy(ped, gd.accuracy or 55)
                    SetPedKeepTask(ped, true)
                    SetPedSeeingRange(ped, 80.0)
                    SetPedHearingRange(ped, 80.0)
                    TaskCombatPed(ped, PlayerPedId(), 0, 16)
                    my.peds[i] = ped

                    local _i, _ped = i, ped
                    CreateThread(function()
                        while DoesEntityExist(_ped) and not IsPedDeadOrDying(_ped, true) do
                            Wait(300)
                        end
                        if _labsLocalGuards == my and DoesEntityExist(_ped) then
                            TriggerServerEvent('m3_illegaltablet:sv:labsGuardDied', my.heistId, _i)
                        end
                    end)
                    CreateThread(function()
                        while _labsLocalGuards == my and DoesEntityExist(_ped)
                        and not IsPedDeadOrDying(_ped, true) do
                            if not IsPedInCombat(_ped, PlayerPedId()) then
                                TaskCombatPed(_ped, PlayerPedId(), 0, 16)
                            end
                            Wait(3000)
                        end
                    end)
                end
            end
        end
        SetModelAsNoLongerNeeded(model)
    end)
end)

RegisterNetEvent('m3_illegaltablet:cl:labsGuardDie', function(heistId, idx)
    local g = _labsLocalGuards
    if not g or g.heistId ~= heistId then return end
    local ped = g.peds[idx] or g.peds[tostring(idx)]
    if ped and DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
        SetEntityHealth(ped, 0)
    end
end)

RegisterNetEvent('m3_illegaltablet:cl:labsGuardsRemove', function(heistId)
    if _labsLocalGuards and _labsLocalGuards.heistId == heistId then
        RemoveLocalLabsGuards()
    end
end)

RegisterNetEvent('m3_illegaltablet:cl:labsData', function(d)
    _labs = _labs or {}
    _labs.crates      = d.crates
    _labs.searched    = d.searched or {}
    _labs.doorHacked  = d.doorHacked
    _labs.sampleTaken = d.sampleTaken
    _labs.delivered   = d.delivered
    _labs.deliveryIdx = d.deliveryIdx
end)

RegisterNetEvent('m3_illegaltablet:cl:labsDoorHacked', function(isLeader, isReporter)
    if _labs then _labs.doorHacked = true end

    local conf = (Config.Robberies and Config.Robberies.humanelabs) or {}

    local myState = _labs
    CreateThread(function()
        local nextReq = 0
        while not _labsLocalGuards and contractRunning and _labs == myState do
            if GetGameTimer() >= nextReq then
                TriggerServerEvent('m3_illegaltablet:sv:labsNeedGuards')
                nextReq = GetGameTimer() + 3000
            end
            Wait(200)
        end
    end)

    if isReporter and Dispatch and Dispatch.robbery then
        local p = conf.hackPanel
        Dispatch.robbery('robbery_humanelabs',
            p and vector3(p.x, p.y, p.z) or GetEntityCoords(PlayerPedId()))
    end
end)

RegisterNetEvent('m3_illegaltablet:cl:labsCrateSearched', function(idx)
    if _labs then _labs.searched[idx] = true end
    local zid = _labsZones[idx]
    if zid then
        exports.ox_target:removeZone(zid)
        _labsZones[idx] = nil
    end
    local obj = _labsProps[idx]
    if obj and DoesEntityExist(obj) then
        DeleteObject(obj)
        _labsProps[idx] = nil
    end
end)

RegisterNetEvent('m3_illegaltablet:cl:labsSampleTaken', function()
    if _labs then _labs.sampleTaken = true end
end)

RegisterNetEvent('m3_illegaltablet:cl:labsDelivered', function()
    if _labs then _labs.delivered = true end
end)

RegisterNetEvent('m3_illegaltablet:cl:labsDone', function(isFinisher)
    LabsCleanup()
    if contractRunning then
        contractRunning = false
        if isFinisher then
            TriggerServerEvent('m3_illegaltablet:sv:robberyCompleted', 'humanelabs')
        else
            TriggerServerEvent('m3_illegaltablet:sv:crewRobberyCompleted', 'humanelabs')
        end
    end
end)

RegisterNetEvent('m3_illegaltablet:cl:truckEmpty', function(isFinisher)
    if _truck then _truck.phase = 'empty' end

    if contractRunning then
        contractRunning = false
        if isFinisher then
            TriggerServerEvent('m3_illegaltablet:sv:robberyCompleted', 'truck')
        else
            TriggerServerEvent('m3_illegaltablet:sv:crewRobberyCompleted', 'truck')
        end
    end
end)

local _bobcatLocalGuards = nil

local function RemoveLocalBobcatGuards()
    if not _bobcatLocalGuards then return end
    for _, ped in pairs(_bobcatLocalGuards.peds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    _bobcatLocalGuards = nil
end

RegisterNetEvent('m3_illegaltablet:cl:bobcatGuardsSpawn', function(heistId, deadMap)
    local bconf = Config.Robberies and Config.Robberies.bobcat
    if not bconf or not bconf.guards then return end
    if _bobcatLocalGuards then
        if _bobcatLocalGuards.heistId == heistId then return end
        RemoveLocalBobcatGuards()
    end
    _bobcatLocalGuards = { heistId = heistId, peds = {} }
    local my = _bobcatLocalGuards

    CreateThread(function()

        local a = bconf.guards[1].coords
        while _bobcatLocalGuards == my do
            if #(GetEntityCoords(PlayerPedId()) - vector3(a.x, a.y, a.z)) < 120.0 then break end
            Wait(1000)
        end
        if _bobcatLocalGuards ~= my then return end

        local model = joaat(bconf.guardModel or 's_m_m_security_01')
        RequestModel(model)
        local mt = 0
        while not HasModelLoaded(model) and mt < 5000 do Wait(50); mt = mt + 50 end
        if not HasModelLoaded(model) then return end

        AddRelationshipGroup('BOBCAT_GUARD')
        local grp = GetHashKey('BOBCAT_GUARD')
        SetRelationshipBetweenGroups(5, grp, GetHashKey('PLAYER'))
        SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), grp)

        for i, gd in ipairs(bconf.guards) do
            if not (deadMap and (deadMap[i] or deadMap[tostring(i)])) and _bobcatLocalGuards == my then
                RequestCollisionAtCoord(gd.coords.x, gd.coords.y, gd.coords.z)

                local ped = CreatePed(4, model,
                    gd.coords.x, gd.coords.y, gd.coords.z - 1.0, gd.coords.w or 0.0,
                    false, false)
                if DoesEntityExist(ped) then
                    SetEntityAsMissionEntity(ped, true, true)
                    local hp = bconf.guardHealth or 400
                    SetPedMaxHealth(ped, hp)
                    SetEntityHealth(ped, hp)
                    SetPedSuffersCriticalHits(ped, false)
                    SetPedCanRagdoll(ped, false)
                    SetRagdollBlockingFlags(ped, 1 | 32 | 128)
                    SetPedConfigFlag(ped, 281, true)
                    SetPedArmour(ped, gd.armor or 200)
                    GiveWeaponToPed(ped, GetHashKey(gd.weapon or 'WEAPON_PISTOL'), 9999, false, true)
                    SetPedInfiniteAmmo(ped, true, GetHashKey(gd.weapon or 'WEAPON_PISTOL'))
                    SetPedDropsWeaponsWhenDead(ped, false)
                    SetPedRelationshipGroupHash(ped, grp)
                    SetBlockingOfNonTemporaryEvents(ped, true)
                    SetPedFleeAttributes(ped, 0, false)
                    SetPedCombatAttributes(ped, 46, true)
                    SetPedCombatMovement(ped, 0)
                    SetPedAccuracy(ped, gd.accuracy or 60)
                    SetPedKeepTask(ped, true)
                    SetPedSeeingRange(ped, 80.0)
                    SetPedHearingRange(ped, 80.0)

                    TaskCombatPed(ped, PlayerPedId(), 0, 16)
                    my.peds[i] = ped

                    local _i, _ped = i, ped

                    CreateThread(function()
                        while DoesEntityExist(_ped) and not IsPedDeadOrDying(_ped, true) do
                            Wait(300)
                        end
                        if _bobcatLocalGuards == my and DoesEntityExist(_ped) then
                            TriggerServerEvent('m3_illegaltablet:sv:bobcatGuardDied', my.heistId, _i)
                        end
                    end)

                    CreateThread(function()
                        while _bobcatLocalGuards == my and DoesEntityExist(_ped)
                        and not IsPedDeadOrDying(_ped, true) do
                            if not IsPedInCombat(_ped, PlayerPedId()) then
                                TaskCombatPed(_ped, PlayerPedId(), 0, 16)
                            end
                            Wait(3000)
                        end
                    end)
                end
            end
        end
        SetModelAsNoLongerNeeded(model)
    end)
end)

RegisterNetEvent('m3_illegaltablet:cl:bobcatGuardDie', function(heistId, idx)
    local g = _bobcatLocalGuards
    if not g or g.heistId ~= heistId then return end
    local ped = g.peds[idx] or g.peds[tostring(idx)]
    if ped and DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
        SetEntityHealth(ped, 0)
    end
end)

RegisterNetEvent('m3_illegaltablet:cl:bobcatGuardsRemove', function(heistId)
    if _bobcatLocalGuards and _bobcatLocalGuards.heistId == heistId then
        RemoveLocalBobcatGuards()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then RemoveLocalBobcatGuards() end
end)

RegisterCommand('m3guards', function()
    local myPos = GetEntityCoords(PlayerPedId())
    print(('[m3guards] my position: %.1f,%.1f,%.1f | interior=%d')
        :format(myPos.x, myPos.y, myPos.z, GetInteriorFromEntity(PlayerPedId())))
    if not _bobcatLocalGuards then
        print('[m3guards] no local guards (heist not running / you are far)')
        return
    end
    for i, ped in pairs(_bobcatLocalGuards.peds) do
        if DoesEntityExist(ped) then
            local c = GetEntityCoords(ped)
            print(('[m3guards] post %s: pos=%.1f,%.1f,%.1f, dist=%.1f, hp=%d, interior=%d, dead=%s')
                :format(tostring(i), c.x, c.y, c.z, #(myPos - c),
                        GetEntityHealth(ped), GetInteriorFromEntity(ped),
                        tostring(IsPedDeadOrDying(ped, true))))
        else
            print(('[m3guards] post %s: entity does not exists'):format(tostring(i)))
        end
    end
end, false)

local SPECIAL_COLORS = {
    { idx = 27,  name = 'Orange' },
    { idx = 38,  name = 'Yellow' },
    { idx = 46,  name = 'Blue' },
    { idx = 49,  name = 'Dark green' },
    { idx = 64,  name = 'Matte black' },
    { idx = 111, name = 'Pearl white' },
    { idx = 6,   name = 'Graphite' },
    { idx = 141, name = 'Metallic blue' },
    { idx = 143, name = 'Metallic red' },
    { idx = 137, name = 'Champagne' },
}

local SPECIAL_VISUAL_ALWAYS = {
    0,
    1,
    2,
    3,
    4,
    7,
    10,
}

local SPECIAL_VISUAL_RANDOM = {
    5,
    6,
    8,
    9,
    14,
    25,
    27,
    28,
    30,
    33,
    34,
    35,
}

local function FullTuneVehicle(veh)
    SetVehicleModKit(veh, 0)

    local col  = SPECIAL_COLORS[math.random(#SPECIAL_COLORS)]
    local col2 = SPECIAL_COLORS[math.random(#SPECIAL_COLORS)]
    SetVehicleColours(veh, col.idx, col2.idx)
    SetVehicleExtraColours(veh, math.random(0, 160), math.random(0, 160))
    SetVehicleWindowTint(veh, math.random(0, 5))

    for _, m in ipairs({ 11, 12, 13, 15, 16 }) do
        local c = GetNumVehicleMods(veh, m)
        if c > 0 then SetVehicleMod(veh, m, c - 1, false) end
    end
    ToggleVehicleMod(veh, 18, true)

    for _, m in ipairs(SPECIAL_VISUAL_ALWAYS) do
        local c = GetNumVehicleMods(veh, m)
        if c > 0 then SetVehicleMod(veh, m, math.random(0, c - 1), false) end
    end

    for _, m in ipairs(SPECIAL_VISUAL_RANDOM) do
        local c = GetNumVehicleMods(veh, m)
        if c > 0 then SetVehicleMod(veh, m, math.random(-1, c - 1), false) end
    end

    SetVehicleWheelType(veh, math.random(0, 6))
    local wc = GetNumVehicleMods(veh, 23)
    if wc > 0 then SetVehicleMod(veh, 23, math.random(0, wc - 1), false) end

    local livOld = GetVehicleLiveryCount(veh)
    if livOld and livOld > 0 then
        SetVehicleLivery(veh, math.random(0, livOld - 1))
    end
    local livMod = GetNumVehicleMods(veh, 48)
    if livMod and livMod > 0 then
        SetVehicleMod(veh, 48, math.random(0, livMod - 1), false)
    end

    local roofLiv = GetVehicleRoofLiveryCount and GetVehicleRoofLiveryCount(veh) or 0
    if roofLiv and roofLiv > 0 then
        SetVehicleRoofLivery(veh, math.random(0, roofLiv - 1))
    end

    ToggleVehicleMod(veh, 22, true)
    SetVehicleXenonLightsColor(veh, math.random(0, 12))
    for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, true) end
    SetVehicleNeonLightsColour(veh, math.random(0, 255), math.random(0, 255), math.random(0, 255))

    ToggleVehicleMod(veh, 20, true)
    SetVehicleTyreSmokeColor(veh, math.random(0, 255), math.random(0, 255), math.random(0, 255))

    return col.name
end

local function GetColorName(idx)
    if     idx <=  0  then return 'Black'
    elseif idx <=  5  then return 'Black'
    elseif idx <=  9  then return 'Dark gray'
    elseif idx <= 12  then return 'Silver'
    elseif idx <= 22  then return 'Red'
    elseif idx <= 25  then return 'Pink'
    elseif idx <= 28  then return 'Orange'
    elseif idx <= 30  then return 'Gold'
    elseif idx <= 33  then return 'Yellow'
    elseif idx <= 40  then return 'Green'
    elseif idx <= 53  then return 'Blue'
    elseif idx <= 66  then return 'Brown'
    elseif idx <= 70  then return 'Purple'
    elseif idx <= 73  then return 'White'
    elseif idx == 74  then return 'Black'
    elseif idx == 75  then return 'White'
    elseif idx == 76  then return 'Silver'
    elseif idx == 77  then return 'Gold'
    elseif idx == 78  then return 'Blue'
    elseif idx == 79  then return 'Red'
    elseif idx == 80  then return 'Yellow'
    elseif idx == 81  then return 'Green'
    elseif idx == 82  then return 'Orange'
    elseif idx == 83  then return 'Pink'
    elseif idx == 84  then return 'Purple'
    elseif idx == 85  then return 'Brown'
    else                   return 'Special'
    end
end

local function AddBlip(coords, sprite, color, label, scale)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, sprite or 1)
    SetBlipColour(b, color or 0)
    SetBlipScale(b, scale or 0.8)
    SetBlipAsShortRange(b, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label or '')
    EndTextCommandSetBlipName(b)
    return b
end

function ClearBlips()
    if activeBlip and DoesBlipExist(activeBlip) then RemoveBlip(activeBlip) end
    if activeRadiusBlip and DoesBlipExist(activeRadiusBlip) then RemoveBlip(activeRadiusBlip) end
    activeBlip       = nil
    activeRadiusBlip = nil
end

local function WaitForModelLoad(model)
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) do
        Wait(10)
        t = t + 10
        if t > 5000 then return false end
    end
    return true
end

local function SpawnNPC(model, coords, scenario, localOnly)
    if not WaitForModelLoad(model) then return nil end
    local net = not localOnly
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w or 0.0, net, net)
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskSetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCanRagdoll(ped, false)
    SetPedSeeingRange(ped, 0)
    FreezeEntityPosition(ped, true)
    if scenario then
        TaskStartScenarioInPlace(ped, scenario, 0, true)
    end
    SetModelAsNoLongerNeeded(model)
    return ped
end

local function CleanGuards()
    for _, g in ipairs(spawnedGuards) do
        if DoesEntityExist(g) then DeletePed(g) end
    end
    spawnedGuards = {}
end

local function ShowHint(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local timerActive = false
local timerEnd    = 0

local function StartTimer(seconds)
    timerActive = true
    timerEnd    = GetGameTimer() + (seconds * 1000)
    CreateThread(function()
        while timerActive do
            local remaining = math.max(0, math.floor((timerEnd - GetGameTimer()) / 1000))
            if remaining <= 0 then
                timerActive = false
                if contractRunning then
                    contractRunning = false
                    TriggerServerEvent('m3_illegaltablet:sv:contractExpired')
                end
                return
            end
            Wait(500)
        end
    end)
end

function StopTimer()
    timerActive = false
end

function DrawText2D(x, y, text, scale)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextDropShadow()
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(x, y)
end

function StartContractExecution(contract)

    contractRunning = false
    Wait(300)
    contractRunning = true
    local ctype = contract.type

    if ctype == 'vehicle_theft' then
        StartVehicleTheft(contract)
    elseif ctype == 'robbery' then
        StartRobbery(contract)
    elseif ctype == 'burglary' then
        StartBurglary(contract)
    end
end

function StartVehicleTheft(contract)
    local catKey  = contract.category
    local cat     = Config.VehicleCategories[catKey]
    local zone    = contract.spawnZone
    local model   = contract.vehicleModel
    local delivery = contract.deliveryPoint

    if not contract.isCrewMember then

        _crewVehicleBlipPos = nil
        local blipAngle = math.random() * 2.0 * math.pi
        local blipDist  = math.random() * zone.radius
        local blipX = zone.x - blipDist * math.cos(blipAngle)
        local blipY = zone.y - blipDist * math.sin(blipAngle)

        activeRadiusBlip = AddBlipForRadius(blipX, blipY, zone.z, zone.radius)
        SetBlipColour(activeRadiusBlip, 38)
        SetBlipAlpha(activeRadiusBlip, 80)

        TriggerServerEvent('m3_illegaltablet:sv:crewVehicleBlip', blipX, blipY)
    else

        CreateThread(function()
            local deadline = GetGameTimer() + 30000
            while not _crewVehicleBlipPos and contractRunning and GetGameTimer() < deadline do
                Wait(100)
            end
            if not _crewVehicleBlipPos or not contractRunning then return end
            local bp = _crewVehicleBlipPos
            if activeRadiusBlip and DoesBlipExist(activeRadiusBlip) then RemoveBlip(activeRadiusBlip) end
            activeRadiusBlip = AddBlipForRadius(bp.x, bp.y, zone.z, zone.radius)
            SetBlipColour(activeRadiusBlip, 38)
            SetBlipAlpha(activeRadiusBlip, 80)
        end)
    end

    Notify('Find the vehicle in the marked zone.', 'inform')
    StartTimer(cat.timeLimit)

    _vehicleLockpicked     = false
    _crewVehicleLockpicked = false
    _crewVehicleDelivered  = false

    CreateThread(function()
        Wait(500)

        if not contractRunning then return end

        if contract.isCrewMember then

            Notify('Find the vehicle and lockpick it (or wait for another crew member to do it).', 'inform')
            local deadline = GetGameTimer() + 180000
            local nextReq  = 0
            while not _crewVehicleNetId and contractRunning and GetGameTimer() < deadline do
                if GetGameTimer() >= nextReq then
                    TriggerServerEvent('m3_illegaltablet:sv:requestCrewVehicle')
                    nextReq = GetGameTimer() + 3000
                end
                Wait(300)
            end
            if not contractRunning then return end
            if not _crewVehicleNetId then
                Notify('Vehicle not found - contract expired.', 'error')
                contractRunning = false
                return
            end

            local netId = _crewVehicleNetId
            _crewVehicleNetId = nil

            local veh = 0
            local t   = 0
            while contractRunning and t < 180000 do
                if NetworkDoesNetworkIdExist(netId) then
                    veh = NetToVeh(netId)
                    if veh ~= 0 and DoesEntityExist(veh) then break end
                end
                Wait(500)
                t = t + 500
            end
            if not contractRunning then return end
            if veh == 0 or not DoesEntityExist(veh) then
                Notify('Failed to load the vehicle - contract expired.', 'error')
                contractRunning = false
                return
            end
            spawnedVehicle = veh

            local picked          = false
            local _lpDispatchSent = false
            exports.ox_target:addLocalEntity(veh, {
                {
                    name = 'veh_lockpick',
                    icon = 'fas fa-unlock',
                    label = T('veh_lockpick_hint'),
                    distance = 2.5,
                    onSelect = function()
                        local modelKey  = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
                        local modelName = GetLabelText(modelKey)
                        _lpDispatchSent = SendDispatchOnce(_lpDispatchSent, 'car_theft', GetEntityCoords(veh), {
                            model = (modelName ~= 'NULL' and modelName) or modelKey,
                            color = GetVehicleColorName(veh),
                        })
                        local ok = DoLockpick(cat.lockpickDiff)
                        if ok then
                            picked = true

                            NetworkRequestControlOfEntity(veh)
                            local ct = 0
                            while not NetworkHasControlOfEntity(veh) and ct < 1500 do
                                NetworkRequestControlOfEntity(veh)
                                Wait(50); ct = ct + 50
                            end
                            SetVehicleDoorsLocked(veh, 1)
                            SetVehicleNeedsToBeHotwired(veh, false)
                            AssertVehicleUnlocked(veh)
                            exports.ox_target:removeLocalEntity(veh, 'veh_lockpick')
                            TriggerServerEvent('m3_illegaltablet:sv:crewVehicleLockpicked')
                        end
                    end
                }
            })
            while not picked and not _crewVehicleLockpicked and contractRunning do Wait(250) end
            exports.ox_target:removeLocalEntity(veh, 'veh_lockpick')
            if not contractRunning then return end

            _vehicleLockpicked = true
            SetVehicleDoorsLocked(veh, 1)
            SetVehicleNeedsToBeHotwired(veh, false)
            AssertVehicleUnlocked(veh)
            if not picked then

            end

            if cat.carHack then

                _sharedHacksLeft = nil
                _sharedHackDone  = false

                local w = 0
                while _sharedHacksLeft == nil and contractRunning and w < 30000 do
                    Wait(200); w = w + 200
                end

                if _sharedHacksLeft == nil then _sharedHacksLeft = cat.carHack.count end

                Notify(string.format(
                    'Get in the vehicle! Use %s to hack the tracker. Remaining: %d',
                    Config.CarHackItem, _sharedHacksLeft), 'success')

                if activeBlip and DoesBlipExist(activeBlip) then RemoveBlip(activeBlip) end
                activeBlip = AddBlip(
                    vector3(delivery.coords.x, delivery.coords.y, delivery.coords.z),
                    280, 5, delivery.label)
                if Config.ContractBlipRoute then SetBlipRoute(activeBlip, true) end

                local hc            = cat.carHack
                local cooldownUntil = 0

                _carHackCallback = function()
                    if _carHackInProgress then return end
                    if GetVehiclePedIsIn(PlayerPedId(), false) ~= veh then
                        Notify('You must be in the stolen vehicle!', 'error')
                        return
                    end
                    local now = GetGameTimer()
                    if now < cooldownUntil then
                        Notify(string.format('Wait %ds more!',
                            math.ceil((cooldownUntil - now) / 1000)), 'error')
                        return
                    end
                    _carHackInProgress = true
                    local ok
                    if GetResourceState('bl_ui') == 'started' then
                        ok = exports.bl_ui:DigitDazzle(1, { length = 4, duration = 50000 }) == true
                    else
                        ok = DoHack(hc.hackDiff or 'hard')
                    end
                    _carHackInProgress = false
                    if ok then
                        _sharedHacksLeft = math.max(0, _sharedHacksLeft - 1)
                        TriggerServerEvent('m3_illegaltablet:sv:crewCarHackSync',
                            _sharedHacksLeft, _sharedHacksLeft == 0)
                        if _sharedHacksLeft == 0 then
                            _sharedHackDone  = true
                            _carHackCallback = nil
                            Notify('Tracker disabled!', 'success')
                            return
                        end
                        Notify(string.format('Hack successful! Remaining: %d', _sharedHacksLeft), 'success')
                    else
                        _sharedHacksLeft = _sharedHacksLeft + 1
                        TriggerServerEvent('m3_illegaltablet:sv:crewCarHackSync', _sharedHacksLeft, false)
                        Notify(string.format('Hack failed! Remaining: %d', _sharedHacksLeft), 'error')
                    end
                    cooldownUntil = GetGameTimer() + (hc.cooldown * 1000)
                end

                CreateThread(function()
                    local slotKeys = { 157, 158, 160, 164, 165 }
                    local hackSlot = nil
                    local slots = exports.ox_inventory:Search('slots', Config.CarHackItem)
                    if slots then
                        for _, s in ipairs(slots) do
                            if s.slot and s.slot <= 5 then hackSlot = s.slot; break end
                        end
                    end
                    if not hackSlot then return end
                    local inputCode = slotKeys[hackSlot]
                    if not inputCode then return end
                    while not _sharedHackDone and contractRunning do
                        if GetVehiclePedIsIn(PlayerPedId(), false) == veh then
                            if IsDisabledControlJustPressed(0, inputCode)
                            and _carHackCallback and not _carHackInProgress then
                                _carHackCallback()
                            end
                            Wait(0)
                        else
                            Wait(250)
                        end
                    end
                end)

                while not _sharedHackDone and contractRunning do Wait(300) end
                _carHackCallback   = nil
                _carHackInProgress = false
            end

            ClearBlips()
            local plate = GetVehicleNumberPlateText(veh)
            activeBlip = AddBlip(
                vector3(delivery.coords.x, delivery.coords.y, delivery.coords.z),
                280, 5, delivery.label)
            if Config.ContractBlipRoute then SetBlipRoute(activeBlip, true) end
            Notify(T('veh_deliver_hint'), 'inform')

            local delNpc    = SpawnNPC(delivery.npcModel, delivery.coords, 'WORLD_HUMAN_STAND_IMPATIENT', true)
            local delivered = false
            exports.ox_target:addLocalEntity(delNpc, {
                {
                    name     = 'veh_deliver',
                    icon     = 'fas fa-car',
                    label    = T('veh_handover_hint'),
                    distance = 8.0,
                    onSelect = function()

                        if cat.carHack and not _sharedHackDone then
                            Notify(string.format('Finish hacking first! Remaining: %d %s.',
                                _sharedHacksLeft or 0,
                                (_sharedHacksLeft or 0) == 1 and 'hack' or 'hackov'), 'error')
                            return
                        end
                        local ped         = PlayerPedId()
                        local inVehHandle = GetVehiclePedIsIn(ped, false)
                        if inVehHandle ~= 0 then
                            local currentPlate = GetVehicleNumberPlateText(inVehHandle)
                            if currentPlate ~= plate then
                                Notify('This is not the target vehicle! (Plate: ' .. plate .. ')', 'error')
                                return
                            end
                        else
                            local dist = #(GetEntityCoords(ped) - GetEntityCoords(veh))
                            if dist > 15.0 then
                                Notify('You must bring the vehicle to the drop-off point!', 'error')
                                return
                            end
                        end
                        if GetEntityHealth(veh) < 250 then
                            Notify(T('veh_too_damaged'), 'error')
                            return
                        end
                        delivered = true
                        lib.requestAnimDict(Config.Anims.handover.dict)
                        TaskPlayAnim(PlayerPedId(),
                            Config.Anims.handover.dict, Config.Anims.handover.clip,
                            2.0, -1.0, 2000, 0, 0, false, false, false)
                        Wait(2000)
                        TriggerServerEvent('m3_illegaltablet:sv:vehicleDelivered')
                        exports.ox_target:removeLocalEntity(delNpc, 'veh_deliver')
                    end
                }
            })

            while not delivered and not _crewVehicleDelivered and contractRunning do Wait(250) end
            exports.ox_target:removeLocalEntity(delNpc, 'veh_deliver')
            if delNpc and DoesEntityExist(delNpc) then DeletePed(delNpc) end

            CleanupVehicleContract(veh, delivered or _crewVehicleDelivered)
            return
        end

        if not WaitForModelLoad(model) then
            Notify('Failed to load the vehicle model.', 'error')
            contractRunning = false
            return
        end

        local function FindClearSpawnPos(x, y, z)
            local function isClear(cx, cy, cz)
                local nearby = GetClosestVehicle(cx, cy, cz, 5.0, 0, 70)
                return not DoesEntityExist(nearby)
            end
            if isClear(x, y, z) then return x, y, z end
            local offsets = { {6,0},{-6,0},{0,6},{0,-6},{8,8},{-8,8},{8,-8},{-8,-8} }
            for _, off in ipairs(offsets) do
                local nx, ny = x + off[1], y + off[2]
                if isClear(nx, ny, z) then return nx, ny, z end
            end
            return x, y, z
        end

        local spawnX, spawnY, _ = FindClearSpawnPos(zone.x, zone.y, zone.z)
        local spawnZ = zone.z + 1.0

        local veh = CreateVehicle(model, spawnX, spawnY, spawnZ, math.random(0, 360), true, false)
        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleHasBeenOwnedByPlayer(veh, true)
        SetVehicleDoorsLocked(veh, 2)
        SetVehicleNeedsToBeHotwired(veh, true)
        spawnedVehicle = veh

        CreateThread(function()
            while DoesEntityExist(veh) do
                SetEntityAsMissionEntity(veh, true, true)
                Wait(5000)
            end
        end)

        local plate = GetVehicleNumberPlateText(veh)

        local colorName
        if contract.isSpecial then
            colorName = FullTuneVehicle(veh)
        else
            local primaryColor = GetVehicleColours(veh)
            colorName = GetColorName(primaryColor)
        end

        local mdlHash  = GetEntityModel(veh)
        local mdlLabel = GetLabelText(GetDisplayNameFromVehicleModel(mdlHash))
        if not mdlLabel or mdlLabel == 'NULL' or mdlLabel == '' then
            mdlLabel = model:sub(1,1):upper() .. model:sub(2)
        end

        SendNUIMessage({
            action = 'vehicleInfo',
            data   = {
                model     = mdlLabel,
                color     = colorName,
                plate     = plate:match('^%s*(.-)%s*$'),
                isSpecial = contract.isSpecial or false,
            }
        })

        SetModelAsNoLongerNeeded(model)

        TriggerServerEvent('m3_illegaltablet:sv:crewVehicleReady', NetworkGetNetworkIdFromEntity(veh))

        local picked          = false
        local _lpDispatchSent = false
        exports.ox_target:addLocalEntity(veh, {
            {
                name = 'veh_lockpick',
                icon = 'fas fa-unlock',
                label = T('veh_lockpick_hint'),
                distance = 2.5,
                onSelect = function()
                    local modelKey  = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
                    local modelName = GetLabelText(modelKey)
                    _lpDispatchSent = SendDispatchOnce(_lpDispatchSent, 'car_theft', GetEntityCoords(veh), {
                        model = (modelName ~= 'NULL' and modelName) or modelKey,
                        color = GetVehicleColorName(veh),
                    })
                    local ok = DoLockpick(cat.lockpickDiff)
                    if ok then
                        picked             = true
                        _vehicleLockpicked = true
                        SetVehicleDoorsLocked(veh, 1)
                        SetVehicleNeedsToBeHotwired(veh, false)
                        AssertVehicleUnlocked(veh)
                        exports.ox_target:removeLocalEntity(veh, 'veh_lockpick')
                        TriggerServerEvent('m3_illegaltablet:sv:crewVehicleLockpicked')
                    end
                end
            }
        })
        while not picked and not _crewVehicleLockpicked and contractRunning do Wait(250) end
        if _crewVehicleLockpicked and not picked then

            exports.ox_target:removeLocalEntity(veh, 'veh_lockpick')
            _vehicleLockpicked = true
            SetVehicleDoorsLocked(veh, 1)
            SetVehicleNeedsToBeHotwired(veh, false)
            AssertVehicleUnlocked(veh)
        end
        if not contractRunning then
            exports.ox_target:removeLocalEntity(veh, 'veh_lockpick')
            CleanupVehicleContract(veh, not _vehicleLockpicked)
            _vehicleLockpicked = false
            return
        end

        if cat.carHack then
            ClearBlips()
            local hc           = cat.carHack
            _sharedHacksLeft  = hc.count
            _sharedHackDone   = false
            local cooldownUntil = 0

            TriggerServerEvent('m3_illegaltablet:sv:crewCarHackSync', _sharedHacksLeft, false)

            activeBlip = AddBlip(
                vector3(delivery.coords.x, delivery.coords.y, delivery.coords.z),
                280, 5, delivery.label)
            if Config.ContractBlipRoute then SetBlipRoute(activeBlip, true) end

            local delNpc    = SpawnNPC(delivery.npcModel, delivery.coords, 'WORLD_HUMAN_STAND_IMPATIENT', true)
            local delivered = false
            exports.ox_target:addLocalEntity(delNpc, {
                {
                    name     = 'veh_deliver',
                    icon     = 'fas fa-car',
                    label    = T('veh_handover_hint'),
                    distance = 8.0,
                    onSelect = function()

                        if not _sharedHackDone then
                            Notify(string.format(
                                'Finish hacking first! Remaining: %d %s.',
                                _sharedHacksLeft, _sharedHacksLeft == 1 and 'hack' or 'hackov'), 'error')
                            return
                        end
                        local ped         = PlayerPedId()
                        local inVehHandle = GetVehiclePedIsIn(ped, false)
                        if inVehHandle ~= 0 then
                            local currentPlate = GetVehicleNumberPlateText(inVehHandle)
                            if currentPlate ~= plate then
                                Notify('This is not the target vehicle! (Plate: ' .. plate .. ')', 'error')
                                return
                            end
                        else
                            local dist = #(GetEntityCoords(ped) - GetEntityCoords(veh))
                            if dist > 15.0 then
                                Notify('You must bring the vehicle to the drop-off point!', 'error')
                                return
                            end
                        end
                        if GetEntityHealth(veh) < 250 then
                            Notify(T('veh_too_damaged'), 'error')
                            return
                        end
                        delivered = true
                        lib.requestAnimDict(Config.Anims.handover.dict)
                        TaskPlayAnim(PlayerPedId(),
                            Config.Anims.handover.dict, Config.Anims.handover.clip,
                            2.0, -1.0, 2000, 0, 0, false, false, false)
                        Wait(2000)
                        TriggerServerEvent('m3_illegaltablet:sv:vehicleDelivered')
                        exports.ox_target:removeLocalEntity(delNpc, 'veh_deliver')
                    end
                }
            })

            Notify(string.format(
                'Tracker active! Get in the vehicle and use %s to hack. Remaining: %d',
                Config.CarHackItem, _sharedHacksLeft), 'inform')

            if hc.globalAlertInterval then
                CreateThread(function()
                    local function sendAlert()
                        local vpos  = GetEntityCoords(veh)
                        local r     = hc.globalAlertRadius

                        local angle = math.random() * 2.0 * math.pi
                        local dist  = (r * 0.3) + math.random() * (r * 0.25)
                        local cx    = vpos.x + dist * math.cos(angle)
                        local cy    = vpos.y + dist * math.sin(angle)

                        TriggerServerEvent('m3_illegaltablet:sv:globalAlert', cx, cy, vpos.z, r)
                    end

                    sendAlert()
                    Wait(hc.globalAlertInterval * 1000)

                    while not _sharedHackDone and contractRunning do
                        sendAlert()
                        Wait(hc.globalAlertInterval * 1000)
                    end

                    TriggerServerEvent('m3_illegaltablet:sv:globalAlertClear')
                end)
            end

            CreateThread(function()

                local slotKeys = { 157, 158, 160, 164, 165 }

                local hackSlot = nil
                local slots = exports.ox_inventory:Search('slots', Config.CarHackItem)
                if slots then
                    for _, s in ipairs(slots) do
                        if s.slot and s.slot <= 5 then
                            hackSlot = s.slot
                            break
                        end
                    end
                end

                if not hackSlot then return end
                local inputCode = slotKeys[hackSlot]
                if not inputCode then return end

                while not _sharedHackDone and contractRunning do
                    if GetVehiclePedIsIn(PlayerPedId(), false) == veh then
                        if IsDisabledControlJustPressed(0, inputCode)
                        and _carHackCallback and not _carHackInProgress then
                            _carHackCallback()
                        end
                        Wait(0)
                    else
                        Wait(250)
                    end
                end
            end)

            _carHackCallback = function()
                if _carHackInProgress then return end
                if GetVehiclePedIsIn(PlayerPedId(), false) ~= veh then
                    Notify('You must be in the stolen vehicle!', 'error')
                    return
                end
                local now = GetGameTimer()
                if now < cooldownUntil then
                    Notify(string.format('Wait %ds more!',
                        math.ceil((cooldownUntil - now) / 1000)), 'error')
                    return
                end

                _carHackInProgress = true

                local ok
                if GetResourceState('bl_ui') == 'started' then
                    ok = exports.bl_ui:DigitDazzle(1, { length = 4, duration = 50000 }) == true
                else
                    ok = DoHack(hc.hackDiff or 'hard')
                end

                _carHackInProgress = false

                if ok then
                    _sharedHacksLeft = math.max(0, _sharedHacksLeft - 1)
                    TriggerServerEvent('m3_illegaltablet:sv:crewCarHackSync',
                        _sharedHacksLeft, _sharedHacksLeft == 0)
                    if _sharedHacksLeft == 0 then
                        _sharedHackDone  = true
                        _carHackCallback = nil
                        Notify('Tracker disabled! Drive the vehicle to the drop-off point.', 'success')
                        return
                    end
                    Notify(string.format('Hack successful! Remaining: %d', _sharedHacksLeft), 'success')
                else
                    _sharedHacksLeft = _sharedHacksLeft + 1
                    TriggerServerEvent('m3_illegaltablet:sv:crewCarHackSync', _sharedHacksLeft, false)
                    Notify(string.format('Hack failed! Remaining: %d', _sharedHacksLeft), 'error')
                end
                cooldownUntil = GetGameTimer() + (hc.cooldown * 1000)
            end

            while not _sharedHackDone and contractRunning do Wait(300) end
            _sharedHackDone = true
            _carHackCallback   = nil
            _carHackInProgress = false

            if not contractRunning then

                exports.ox_target:removeLocalEntity(delNpc, 'veh_deliver')
                if delNpc and DoesEntityExist(delNpc) then DeletePed(delNpc) end
                CleanupVehicleContract(veh, not _vehicleLockpicked)
                _vehicleLockpicked = false
                return
            end

            Notify(T('veh_deliver_hint'), 'inform')
            while not delivered and not _crewVehicleDelivered and contractRunning do Wait(250) end

            exports.ox_target:removeLocalEntity(delNpc, 'veh_deliver')
            CleanupVehicleContract(veh, delivered or _crewVehicleDelivered)
            if delNpc and DoesEntityExist(delNpc) then DeletePed(delNpc) end
            StopTimer()
            return
        end

        ClearBlips()
        activeBlip = AddBlip(
            vector3(delivery.coords.x, delivery.coords.y, delivery.coords.z),
            280, 5, delivery.label)
        if Config.ContractBlipRoute then SetBlipRoute(activeBlip, true) end
        Notify(T('veh_deliver_hint'), 'inform')

        local delNpc = SpawnNPC(delivery.npcModel, delivery.coords, 'WORLD_HUMAN_STAND_IMPATIENT', true)

        local delivered = false
        exports.ox_target:addLocalEntity(delNpc, {
            {
                name     = 'veh_deliver',
                icon     = 'fas fa-car',
                label    = T('veh_handover_hint'),
                distance = 8.0,
                onSelect = function()
                    local ped         = PlayerPedId()
                    local inVehHandle = GetVehiclePedIsIn(ped, false)

                    if inVehHandle ~= 0 then
                        local currentPlate = GetVehicleNumberPlateText(inVehHandle)
                        if currentPlate ~= plate then
                            Notify('This is not the target vehicle! (Plate: ' .. plate .. ')', 'error')
                            return
                        end
                    else
                        local dist = #(GetEntityCoords(ped) - GetEntityCoords(veh))
                        if dist > 15.0 then
                            Notify('You must bring the vehicle to the drop-off point!', 'error')
                            return
                        end
                    end

                    if GetEntityHealth(veh) < 250 then
                        Notify(T('veh_too_damaged'), 'error')
                        return
                    end

                    delivered = true
                    lib.requestAnimDict(Config.Anims.handover.dict)
                    TaskPlayAnim(PlayerPedId(),
                        Config.Anims.handover.dict, Config.Anims.handover.clip,
                        2.0, -1.0, 2000, 0, 0, false, false, false)
                    Wait(2000)
                    TriggerServerEvent('m3_illegaltablet:sv:vehicleDelivered')
                    exports.ox_target:removeLocalEntity(delNpc, 'veh_deliver')
                end
            }
        })
        while not delivered and not _crewVehicleDelivered and contractRunning do Wait(250) end

        CleanupVehicleContract(veh, delivered or _crewVehicleDelivered)
        if delNpc and DoesEntityExist(delNpc) then DeletePed(delNpc) end
        StopTimer()
    end)
end

local function ForceDeleteVehicle(veh)
    if not (veh and DoesEntityExist(veh)) then return end
    local ped = PlayerPedId()
    if GetVehiclePedIsIn(ped, false) == veh then
        local pos = GetEntityCoords(veh)
        SetEntityCoords(ped, pos.x + 3.0, pos.y, pos.z, false, false, false, false)
        local t = 0
        while GetVehiclePedIsIn(ped, false) == veh and t < 1000 do
            Wait(50); t = t + 50
        end
    end

    if NetworkGetEntityIsNetworked(veh) then
        local t = 0
        while not NetworkHasControlOfEntity(veh) and t < 1500 do
            NetworkRequestControlOfEntity(veh)
            Wait(50); t = t + 50
        end
    end
    SetEntityAsMissionEntity(veh, false, true)
    DeleteVehicle(veh)
end

function CleanupVehicleContract(veh, deleteVeh)
    contractRunning = false
    ClearBlips()
    StopTimer()
    if deleteVeh then
        ForceDeleteVehicle(veh)
    end
    spawnedVehicle = nil
end

function CleanupSpawnedVehicle()
    if spawnedVehicle and not _vehicleLockpicked then
        ForceDeleteVehicle(spawnedVehicle)
    end
    spawnedVehicle = nil

end

function StartRobbery(contract)
    local key  = contract.robberyKey
    local conf = Config.Robberies[key]
    if not conf then return end

    if key == 'truck' then
        CreateThread(function() StartTruckRobbery(conf, contract) end)
        return
    end

    if conf.locations and #conf.locations > 0 then
        local base = conf
        conf = {}
        for k, v in pairs(base) do conf[k] = v end

        local locIdx
        if contract.locationIndex then

            locIdx = contract.locationIndex
        else

            locIdx = math.random(#base.locations)
            TriggerServerEvent('m3_illegaltablet:sv:setContractLocation', locIdx)
        end

        local picked = base.locations[locIdx]
        if type(picked) == 'vector3' then

            conf.location = picked
        else

            local cp = picked.cashierPos
            conf.location = picked.coords
                or (cp and vector3(cp.x, cp.y, cp.z))
            for k, v in pairs(picked) do
                if k ~= 'coords' then conf[k] = v end
            end
        end
    end

    activeBlip = AddBlip(conf.location, conf.blipSprite, conf.blipColor, conf.label)
    if Config.ContractBlipRoute then SetBlipRoute(activeBlip, true) end
    StartTimer(conf.timeLimit)

    if key == 'jewelry' then
        CreateThread(function() StartJewelryRobbery(conf, contract) end)
        return
    end
    if key == 'humanelabs' then
        CreateThread(function() StartLabsRobbery(conf, contract) end)
        return
    end
    if key == 'supermarket' then
        CreateThread(function() StartStoreRobbery(conf, contract) end)
        return
    end
    if key == 'fleeca' then
        CreateThread(function() StartFleecaRobbery(conf, contract) end)
        return
    end
    if key == 'bobcat' then
        CreateThread(function() StartBobcatRobbery(conf, contract) end)
        return
    end

    CreateThread(function()

        local broken           = false
        local _atmDispatchSent = false
        local breakinZoneId
        breakinZoneId = exports.ox_target:addSphereZone({
            coords = conf.location,
            radius = 3.0,
            debug = false,
            options = {
                {
                    name = 'robbery_break_' .. key,
                    icon = 'fas fa-door-open',
                    label = T('rob_break_hint'),

                    items = key == 'atm' and (Config.HackingDeviceItem or 'hacking_device') or nil,
                    onSelect = function()
                        if key == 'fleeca' or key == 'bobcat' then

                            local ok = DoProgressBar(T('rob_drilling'), conf.drillTime,
                                Config.Anims.drill.dict, Config.Anims.drill.clip, 1)
                            if ok then
                                broken = true
                                if key == 'fleeca' then
                                    local hok = DoHack('medium')
                                    if not hok then
                                        Notify('Hack failed! Try again.', 'error')
                                        broken = false
                                    end
                                end
                            end

                        elseif key == 'atm' then

                            local breakOk = DoProgressBar(T('rob_breaking'), conf.breakInTime or 5000,
                                Config.Anims.drill.dict, Config.Anims.drill.clip, 1)
                            if breakOk then

                                local hackItem = Config.HackingDeviceItem or 'hacking_device'
                                if (exports.ox_inventory:GetItemCount(hackItem) or 0) < 1 then
                                    Notify('You need ' .. hackItem .. '!', 'error')
                                else
                                    TriggerServerEvent('m3_illegaltablet:sv:useHackingDevice')

                                    if not _atmDispatchSent then
                                        _atmDispatchSent = true
                                        if Dispatch and Dispatch.robbery then
                                            Dispatch.robbery('atm', GetEntityCoords(PlayerPedId()))
                                        end
                                    end

                                    local hackOk = DoAtmHack()
                                    if hackOk then

                                        local extractOk = DoProgressBar(
                                            'Withdrawing money...',
                                            conf.extractTime or 6000,
                                            Config.Anims.search.dict,
                                            Config.Anims.search.clip,
                                            49)
                                        if extractOk then
                                            local amt = math.random(conf.itemsCount.min, conf.itemsCount.max)
                                            TriggerServerEvent('m3_illegaltablet:sv:collectRobberyItem',
                                                conf.item, amt, conf.rewardPerItem)
                                            broken = true
                                        end
                                    else
                                        Notify('Hack failed! Try again.', 'error')
                                    end
                                end
                            end

                        else

                            local ok = DoProgressBar(T('rob_breaking'), conf.breakInTime or 5000,
                                Config.Anims.drill.dict, Config.Anims.drill.clip, 1)
                            broken = ok
                        end

                        if broken then
                            exports.ox_target:removeZone(breakinZoneId)

                            if key == 'bobcat' and conf.guards then
                                SpawnGuards(conf)
                            end
                        end
                    end
                },

                key == 'atm' and {
                    name  = 'robbery_drill_atm',
                    icon  = 'fas fa-screwdriver-wrench',
                    label = 'Drill the ATM',
                    items = conf.drillItem or 'drill',
                    onSelect = function()

                        local ok = lib.callback.await('m3_illegaltablet:sv:atmDrillAttempt', false)
                        if not ok then return end

                        if not _atmDispatchSent then
                            _atmDispatchSent = true
                            if Dispatch and Dispatch.robbery then
                                Dispatch.robbery('atm', GetEntityCoords(PlayerPedId()))
                            end
                        end

                        local success = DoDrillMinigame()
                        if not success then
                            Notify('Drilling failed!', 'error')
                            return
                        end

                        local extractOk = DoProgressBar(
                            'Withdrawing money...',
                            conf.extractTime or 6000,
                            Config.Anims.search.dict,
                            Config.Anims.search.clip,
                            49)
                        if extractOk then
                            local amt = math.random(conf.itemsCount.min, conf.itemsCount.max)
                            TriggerServerEvent('m3_illegaltablet:sv:collectRobberyItem',
                                conf.item, amt, conf.rewardPerItem)
                            broken = true
                            exports.ox_target:removeZone(breakinZoneId)
                        end
                    end,
                } or nil,
            }
        })

        while not broken and contractRunning do Wait(250) end
        if not contractRunning then
            exports.ox_target:removeZone(breakinZoneId)
            ClearBlips()
            StopTimer()
            return
        end

        ClearBlips()

        if conf.collectZones then
            local collected = {}
            for i, zc in ipairs(conf.collectZones) do
                collected[i] = false
                local collectZoneId
                collectZoneId = exports.ox_target:addSphereZone({
                    coords = zc,
                    radius = 1.2,
                    debug = false,
                    options = {
                        {
                            name = 'rob_collect_' .. key .. '_' .. i,
                            icon = 'fas fa-box',
                            label = T('rob_collect_hint'),
                            onSelect = function()
                                local ct = conf.collectTime or 4000
                                local ok = DoProgressBar(T('rob_collecting'), ct,
                                    Config.Anims.search.dict, Config.Anims.search.clip, 49)
                                if ok then
                                    collected[i] = true
                                    exports.ox_target:removeZone(collectZoneId)
                                    local amt = math.random(conf.itemsPerZone.min, conf.itemsPerZone.max)
                                    TriggerServerEvent('m3_illegaltablet:sv:collectRobberyItem',
                                        conf.item, amt, conf.rewardPerItem)
                                    Notify(string.format('You took %sx %s', amt, conf.item), 'success')
                                end
                            end
                        }
                    }
                })
            end

            local allDone = false
            while not allDone and contractRunning do
                allDone = true
                for i, zc in ipairs(conf.collectZones) do
                    if not collected[i] then
                        allDone = false
                        break
                    end
                end
                Wait(250)
            end
        end

        if not broken then exports.ox_target:removeZone(breakinZoneId) end

        StopTimer()
        CleanGuards()

        if contractRunning then
            contractRunning = false
            TriggerServerEvent('m3_illegaltablet:sv:robberyCompleted', key)
        end
    end)
end

function StartFleecaRobbery(conf, contract)

    _fleecaVaultHacked = false
    _fleecaBarsHacked  = false
    _fleecaAllGrabbed  = false
    _fleecaTrolleyData = nil
    _fleecaGrabbing    = false

    local isCrew = contract and contract.isCrewMember

    local function FleecaHack(iterations, difficulty, fallback)
        if GetResourceState('bl_ui') == 'started' then
            local ok = exports['bl_ui']:CircleProgress(iterations, difficulty)
            return ok == true
        else
            return DoHack(fallback or 'medium')
        end
    end

    local doorHash = conf.vaultDoorHash or GetHashKey('v_ilev_gb_vauldr')
    local dp       = conf.vaultDoorPos or conf.vaultZonePos
    if dp then
        SetStateOfClosestDoorOfType(doorHash, dp.x, dp.y, dp.z, 1, 0.0, false)
    end

    local function OpenVaultDoor()
        if not dp then return end
        SetStateOfClosestDoorOfType(doorHash, dp.x, dp.y, dp.z, 0, 0.0, false)
        local obj = GetClosestObjectOfType(dp.x, dp.y, dp.z, 6.0, doorHash, false, false, false)
        if DoesEntityExist(obj) then
            CreateThread(function()
                for _ = 1, 900 do
                    SetEntityHeading(obj, GetEntityHeading(obj) - 0.10)
                    Wait(10)
                end
            end)
        end
    end

    local barsLocked = true
    local barsOwned  = nil

    local function SpawnOwnBars()
        local bp = conf.barsObjPos
        if not bp then return end
        local hash = GetHashKey('v_ilev_gb_vaubar')
        RequestModel(hash)
        local deadline = GetGameTimer() + 4000
        while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(50) end
        if not HasModelLoaded(hash) then SetModelAsNoLongerNeeded(hash); return end
        local obj = CreateObject(hash, bp.x, bp.y, bp.z, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        if not DoesEntityExist(obj) then return end
        SetEntityHeading(obj, conf.barsLockedHeading or 0.0)
        SetEntityAsMissionEntity(obj, true, true)
        FreezeEntityPosition(obj, true)
        SetEntityCollision(obj, true, true)
        barsOwned = obj
    end

    SpawnOwnBars()

    CreateThread(function()
        local bp = conf.barsObjPos
        if not bp then return end
        local posV     = vector3(bp.x, bp.y, bp.z)
        local barsHash = GetHashKey('v_ilev_gb_vaubar')
        local frozen   = nil
        while barsLocked and contractRunning do
            if not (frozen and DoesEntityExist(frozen) and #(GetEntityCoords(frozen) - posV) < 5.0) then
                local bestDist = 5.0
                frozen = nil
                for _, obj in ipairs(GetGamePool('CObject')) do
                    if DoesEntityExist(obj) and GetEntityModel(obj) == barsHash then
                        local d = #(GetEntityCoords(obj) - posV)
                        if d < bestDist then frozen = obj; bestDist = d end
                    end
                end
            end
            if frozen then
                FreezeEntityPosition(frozen, true)
                if conf.barsLockedHeading then SetEntityHeading(frozen, conf.barsLockedHeading) end
            end
            if barsLocked and (not barsOwned or not DoesEntityExist(barsOwned)) then
                SpawnOwnBars()
            end
            Wait(100)
        end

        if barsOwned and DoesEntityExist(barsOwned) then
            DeleteObject(barsOwned); barsOwned = nil
        end
        for _, obj in ipairs(GetGamePool('CObject')) do
            if DoesEntityExist(obj) and GetEntityModel(obj) == barsHash
            and #(GetEntityCoords(obj) - posV) < 5.0 then
                FreezeEntityPosition(obj, false)
            end
        end
    end)

    local function BuildTrolleyDefs()
        local defs = {}
        local m1 = conf.moneyPerTrolley  or { min = 3000, max = 7000  }
        local m2 = conf.money2PerTrolley or { min = 5000, max = 12000 }
        for _, td in ipairs(conf.trolleys1 or {}) do
            defs[#defs + 1] = { x = td.pos.x, y = td.pos.y, z = td.pos.z,
                                heading = td.heading or 0.0, barsSide = false,
                                min = m1.min, max = m1.max }
        end
        for _, td in ipairs(conf.trolleys2 or {}) do
            defs[#defs + 1] = { x = td.pos.x, y = td.pos.y, z = td.pos.z,
                                heading = td.heading or 0.0, barsSide = true,
                                min = m2.min, max = m2.max }
        end
        return defs
    end

    local _vaultDispatchSent = false
    local vaultZoneId
    vaultZoneId = exports.ox_target:addSphereZone({
        coords  = conf.vaultZonePos,
        radius  = 2.0,
        debug   = false,
        options = {{
            name     = 'fleeca_vault',
            icon     = 'fas fa-shield-alt',
            label    = 'Hack the vault',
            canInteract = function() return not _fleecaVaultHacked end,
            onSelect = function()
                _vaultDispatchSent = SendDispatchOnce(_vaultDispatchSent, 'robbery_fleeca',
                    vector3(conf.vaultZonePos.x, conf.vaultZonePos.y, conf.vaultZonePos.z))
                local ok = FleecaHack(conf.vaultHackIterations or 3,
                                      conf.vaultHackDifficulty or 22, 'medium')
                if ok then
                    _fleecaVaultHacked = true
                    TriggerServerEvent('m3_illegaltablet:sv:crewFleecaVaultHacked')

                    TriggerServerEvent('m3_illegaltablet:sv:fleecaVaultOpened', BuildTrolleyDefs())
                else
                    Notify('Hack failed! Try again.', 'error')
                end
            end,
        }},
    })

    while not _fleecaVaultHacked and contractRunning do Wait(250) end
    exports.ox_target:removeZone(vaultZoneId)
    if not contractRunning then
        barsLocked = false
        ClearBlips(); StopTimer(); return
    end

    OpenVaultDoor()
    do
        local nextReq = 0
        while not _fleecaTrolleyData and contractRunning do
            if GetGameTimer() >= nextReq then

                TriggerServerEvent('m3_illegaltablet:sv:fleecaVaultOpened', nil)
                nextReq = GetGameTimer() + 3000
            end
            Wait(200)
        end
    end
    if not contractRunning then
        barsLocked = false
        ClearBlips(); StopTimer(); return
    end

    local grabDict = 'anim@heists@ornate_bank@grab_cash'
    local function GrabFromTrolley(idx)
        if _fleecaGrabbing then return end
        _fleecaGrabbing = true

        lib.requestAnimDict(grabDict)
        local ped = PlayerPedId()

        TaskPlayAnim(ped, grabDict, 'intro', 4.0, -1.0, 1600, 1, 0, false, false, false)
        Wait(1600)
        TaskPlayAnim(ped, grabDict, 'grab', 2.0, -1.0, -1, 1, 0, false, false, false)

        local grabbingDone = false
        CreateThread(function()
            for _ = 1, 8 do
                if grabbingDone or not contractRunning then return end
                local d = _fleecaTrolleyData and _fleecaTrolleyData[idx]
                if not d or d.empty then return end
                TriggerServerEvent('m3_illegaltablet:sv:fleecaGrabTick', idx)
                Wait(1000)
            end
        end)

        lib.progressBar({
            duration     = 8000,
            label        = 'Taking money from the trolley...',
            useWhileDead = false,
            canCancel    = false,
            disable      = { move = true, car = true, combat = true, sprint = true },
        })
        grabbingDone = true

        ClearPedTasks(ped)
        TaskPlayAnim(ped, grabDict, 'exit', 4.0, -1.0, 1800, 1, 0, false, false, false)
        Wait(1800)
        ClearPedTasks(ped)
        RemoveAnimDict(grabDict)
        _fleecaGrabbing = false
    end

    local trolleyTargets = {}
    for i, td in ipairs(_fleecaTrolleyData) do
        local _i, _nid = i, td.netId
        local _name = 'fleeca_trolley_' .. _i
        trolleyTargets[#trolleyTargets + 1] = { netId = _nid, name = _name }
        exports.ox_target:addEntity(_nid, {{
            name     = _name,
            icon     = 'fas fa-money-bill-wave',
            label    = 'Take money from the trolley',
            distance = 1.8,
            canInteract = function()
                local d = _fleecaTrolleyData and _fleecaTrolleyData[_i]
                if not d or d.empty then return false end
                if d.barsSide and not _fleecaBarsHacked then return false end
                return not _fleecaGrabbing
            end,
            onSelect = function() GrabFromTrolley(_i) end,
        }})
    end

    local barsZoneId
    barsZoneId = exports.ox_target:addSphereZone({
        coords  = conf.barsZonePos,
        radius  = 2.0,
        debug   = false,
        options = {{
            name     = 'fleeca_bars',
            icon     = 'fas fa-laptop-code',
            label    = 'Hack the bars',
            canInteract = function() return not _fleecaBarsHacked end,
            onSelect = function()
                local hackItem = Config.HackingDeviceItem or 'hacking_device'
                if (exports.ox_inventory:GetItemCount(hackItem) or 0) < 1 then
                    Notify('You need ' .. hackItem .. '!', 'error')
                    return
                end
                TriggerServerEvent('m3_illegaltablet:sv:useHackingDevice')
                local anim = Config.Anims.hack
                lib.requestAnimDict(anim.dict)
                TaskPlayAnim(PlayerPedId(), anim.dict, anim.clip,
                    3.0, -1.0, -1, 49, 0, false, false, false)
                local ok = FleecaHack(conf.barsHackIterations or 4,
                                      conf.barsHackDifficulty or 14, 'hard')
                ClearPedTasks(PlayerPedId())
                if ok then
                    _fleecaBarsHacked = true
                    TriggerServerEvent('m3_illegaltablet:sv:crewFleecaBarsHacked')
                else
                    Notify('Hack failed! Try again.', 'error')
                end
            end,
        }},
    })

    CreateThread(function()
        while not _fleecaBarsHacked and contractRunning do Wait(250) end
        barsLocked = false
        if barsZoneId then exports.ox_target:removeZone(barsZoneId); barsZoneId = nil end
    end)

    while not _fleecaAllGrabbed and contractRunning do Wait(250) end

    if contractRunning and _fleecaAllGrabbed and not isCrew then

        TriggerServerEvent('m3_illegaltablet:sv:robberyCompleted', 'fleeca')
    end

    barsLocked = false
    if barsZoneId then exports.ox_target:removeZone(barsZoneId) end
    for _, t in ipairs(trolleyTargets) do
        exports.ox_target:removeEntity(t.netId, t.name)
    end
    ClearBlips(); StopTimer()
end

local function DrawFearBar(pct)
    SendNUIMessage({ action = 'fearBar', data = { pct = pct } })
end

function StartStoreRobbery(conf, contract)

    _shopSharedFear   = 0.0
    _shopNpcNetId     = nil
    _shopBagPosition  = nil
    _shopContractDone = false
    _shopCrewAimUntil = 0

    local isCrewMember = contract and contract.isCrewMember

    if isCrewMember then
        local crewFinished = false

        CreateThread(function()
            local lastPct = -1
            while not crewFinished and contractRunning and not _shopContractDone do
                if math.abs(_shopSharedFear - lastPct) > 0.005 then
                    DrawFearBar(_shopSharedFear)
                    lastPct = _shopSharedFear
                end
                Wait(50)
            end
            DrawFearBar(0)
        end)

        CreateThread(function()
            local npc     = 0
            local nextReq = 0
            while not crewFinished and contractRunning and not _shopContractDone do
                if npc == 0 or not DoesEntityExist(npc) then
                    if _shopNpcNetId and NetworkDoesNetworkIdExist(_shopNpcNetId) then
                        npc = NetworkGetEntityFromNetworkId(_shopNpcNetId)
                    elseif not _shopNpcNetId and GetGameTimer() >= nextReq then
                        TriggerServerEvent('m3_illegaltablet:sv:requestShopNpc')
                        nextReq = GetGameTimer() + 3000
                    end
                end
                if npc ~= 0 and DoesEntityExist(npc) then
                    local ped   = PlayerPedId()
                    local armed = GetSelectedPedWeapon(ped) ~= GetHashKey('WEAPON_UNARMED')
                    if armed and #(GetEntityCoords(ped) - GetEntityCoords(npc)) < 8.0
                    and IsPlayerFreeAimingAtEntity(PlayerId(), npc) then
                        TriggerServerEvent('m3_illegaltablet:sv:shopCrewAiming')
                    end
                end
                Wait(300)
            end
        end)

        while not _shopBagPosition and contractRunning and not _shopContractDone do
            Wait(200)
        end
        crewFinished = true

        if not contractRunning or _shopContractDone then
            ClearBlips(); StopTimer(); return
        end

        lib.requestModel(`p_poly_bag_01_s`)
        local bagHash = GetHashKey('p_poly_bag_01_s')
        local bp      = _shopBagPosition
        local pickup  = CreatePickupRotate(
            GetHashKey('PICKUP_MONEY_MED_BAG'),
            bp.x, bp.y, bp.z, 0.0, 0.0, 0.0,
            8, 1, 24, true, bagHash)
        SetModelAsNoLongerNeeded(bagHash)


        local collected = false
        while DoesPickupExist(pickup) and contractRunning and not collected and not _shopContractDone do
            local dist = #(GetEntityCoords(PlayerPedId(), false) - GetPickupCoords(pickup))
            if dist < 1.5 and HasPickupBeenCollected(pickup) then
                collected = true
                local amt = math.random(conf.itemsCount.min, conf.itemsCount.max)
                TriggerServerEvent('m3_illegaltablet:sv:collectRobberyItem',
                    conf.item, amt, conf.rewardPerItem)
                TriggerServerEvent('m3_illegaltablet:sv:shopBagCollected')
            end
            Wait(dist < 5.0 and 5 or 200)
        end
        if DoesPickupExist(pickup) then RemovePickup(pickup) end

        ClearBlips(); StopTimer()
        if contractRunning then
            contractRunning = false
            TriggerServerEvent('m3_illegaltablet:sv:robberyCompleted', 'supermarket')
        end
        return
    end

    local npc = SpawnNPC(conf.cashierModel or 's_f_y_shop_mid', conf.cashierPos, nil)
    if not npc then
        Notify('Error: failed to spawn the NPC!', 'error')
        contractRunning = false
        TriggerServerEvent('m3_illegaltablet:sv:contractExpired')
        return
    end

    Wait(200)
    TriggerServerEvent('m3_illegaltablet:sv:shopNpcReady', NetworkGetNetworkIdFromEntity(npc))

    local fearMax    = 100.0
    local tickMs     = 50
    local fillPTick  = fearMax / (conf.fearFillTime  or 10.0) * (tickMs / 1000.0)
    local decayPTick = fearMax / (conf.fearDecayTime or 20.0) * (tickMs / 1000.0)

    local fear              = 0.0
    local bagSpawned        = false
    local finished          = false
    local _shopDispatchSent = false

    CreateThread(function()
        while not finished and contractRunning do
            TriggerServerEvent('m3_illegaltablet:sv:shopFearSync', fear / fearMax)
            Wait(500)
        end
    end)

    CreateThread(function()
        while not bagSpawned and contractRunning do
            Wait(tickMs)

            local ped    = PlayerPedId()
            local armed  = GetSelectedPedWeapon(ped) ~= GetHashKey('WEAPON_UNARMED')
            local dist   = #(GetEntityCoords(ped) - GetEntityCoords(npc))

            local aiming = (armed and dist < 8.0 and IsPlayerFreeAimingAtEntity(PlayerId(), npc))
                or (GetGameTimer() < _shopCrewAimUntil)

            if aiming and not _shopDispatchSent then
                _shopDispatchSent = true
                if Dispatch and Dispatch.robbery then
                    Dispatch.robbery('robbery_supermarket', GetEntityCoords(ped))
                end
            end

            if aiming then
                fear = math.min(fearMax, fear + fillPTick)
            else
                fear = math.max(0.0, fear - decayPTick)
            end

            if fear >= fearMax then
                bagSpawned = true
            end
        end
    end)

    CreateThread(function()
        local lastPct = -1
        while not finished and contractRunning do
            local pct = bagSpawned and 1.0 or (fear / fearMax)
            if math.abs(pct - lastPct) > 0.005 then
                DrawFearBar(pct)
                lastPct = pct
            end
            Wait(50)
        end
        DrawFearBar(0)
    end)

    while not bagSpawned and contractRunning do Wait(100) end

    if not contractRunning then
        finished = true
        if DoesEntityExist(npc) then DeletePed(npc) end
        return
    end

    fear = fearMax
    local npcPos = GetEntityCoords(npc)

    local tillObj = GetClosestObjectOfType(
        npcPos.x, npcPos.y, npcPos.z, 5.0,
        GetHashKey('prop_till_01'), false, false, false)

    local tillCoords, tillRotation
    if tillObj and DoesEntityExist(tillObj) then

        tillCoords   = GetOffsetFromEntityInWorldCoords(tillObj, 0.0, 0.0, -0.12)
        tillRotation = GetEntityRotation(tillObj, 2)
    else
        tillCoords   = npcPos
        tillRotation = vector3(0.0, 0.0, GetEntityHeading(npc))
    end

    lib.requestModel(`p_till_01_s`)
    lib.requestModel(`p_poly_bag_01_s`)
    local tillSceneHash = GetHashKey('p_till_01_s')
    local bagHash       = GetHashKey('p_poly_bag_01_s')

    if tillObj and DoesEntityExist(tillObj) then
        FreezeEntityPosition(npc, false)
        local moveTo = GetOffsetFromEntityInWorldCoords(tillObj, 0.0, -1.0, 0.0)
        TaskGoStraightToCoord(npc, moveTo.x, moveTo.y, moveTo.z,
            1.0, 3000, GetEntityHeading(tillObj), 0.0)
        while #(GetEntityCoords(npc, false) - moveTo) > 0.3 do
            Wait(100)
        end

    end

    if tillObj and DoesEntityExist(tillObj) then
        CreateModelSwap(tillCoords.x, tillCoords.y, tillCoords.z, 0.5,
            GetHashKey('prop_till_01'), GetHashKey('p_till_01_s'), true)
    end

    local sceneTill = CreateObject(tillSceneHash,
        tillCoords.x, tillCoords.y, tillCoords.z, true, false, false)
    local sceneBag  = CreateObject(bagHash,
        tillCoords.x, tillCoords.y, tillCoords.z, true, false, false)
    SetModelAsNoLongerNeeded(tillSceneHash)
    SetModelAsNoLongerNeeded(bagHash)

    local wt = 0
    while (not DoesEntityExist(sceneTill) or not DoesEntityExist(sceneBag)) and wt < 3000 do
        Wait(50); wt = wt + 50
    end

    local scene = NetworkCreateSynchronisedScene(
        tillCoords.x, tillCoords.y, tillCoords.z,
        tillRotation.x, tillRotation.y, tillRotation.z - 180.0,
        2, false, false, -1, 0, 1.0)

    NetworkAddPedToSynchronisedScene(
        npc, scene, 'mp_am_hold_up', 'holdup_victim_20s',
        1.5, -4.0, 1, 16, 1148846080, 0)

    NetworkAddEntityToSynchronisedScene(
        sceneTill, scene, 'mp_am_hold_up', 'holdup_victim_20s_till',
        1.0, 1.0, 1)

    NetworkAddEntityToSynchronisedScene(
        sceneBag, scene, 'mp_am_hold_up', 'holdup_victim_20s_bag',
        1.0, 1.0, 1)

    NetworkStartSynchronisedScene(scene)

    local pickedUp = false
    CreateThread(function()
        Wait(21500)
        if not contractRunning then return end

        local bagPos = DoesEntityExist(sceneBag) and GetEntityCoords(sceneBag, false) or tillCoords
        local bagRot = DoesEntityExist(sceneBag) and GetEntityRotation(sceneBag, 2) or vector3(0.0, 0.0, 0.0)

        TriggerServerEvent('m3_illegaltablet:sv:shopBagReady', bagPos.x, bagPos.y, bagPos.z)

        lib.requestModel(`p_poly_bag_01_s`)

        local pickup = CreatePickupRotate(
            GetHashKey('PICKUP_MONEY_MED_BAG'),
            bagPos.x, bagPos.y, bagPos.z,
            bagRot.x, bagRot.y, bagRot.z,
            8, 1, 24, true, bagHash)
        SetModelAsNoLongerNeeded(bagHash)

        while DoesPickupExist(pickup) and contractRunning and not pickedUp and not _shopContractDone do
            local dist = #(GetEntityCoords(PlayerPedId(), false) - GetPickupCoords(pickup))
            if dist < 1.5 and HasPickupBeenCollected(pickup) then
                pickedUp = true
                local amt = math.random(conf.itemsCount.min, conf.itemsCount.max)
                TriggerServerEvent('m3_illegaltablet:sv:collectRobberyItem',
                    conf.item, amt, conf.rewardPerItem)
                TriggerServerEvent('m3_illegaltablet:sv:shopBagCollected')
            end
            Wait(dist < 5.0 and 5 or 200)
        end
        if DoesPickupExist(pickup) then RemovePickup(pickup) end
    end)

    Wait(21566)

    NetworkStopSynchronisedScene(scene)
    ClearPedTasks(npc)
    FreezeEntityPosition(npc, true)
    if DoesEntityExist(sceneBag)  then DeleteEntity(sceneBag)  end
    if DoesEntityExist(sceneTill) then DeleteEntity(sceneTill) end

    Wait(1000)
    RemoveModelSwap(tillCoords.x, tillCoords.y, tillCoords.z, 0.5,
        GetHashKey('prop_till_01'), GetHashKey('p_till_01_s'), true)
    RemoveModelSwap(tillCoords.x, tillCoords.y, tillCoords.z, 0.5,
        GetHashKey('p_till_01_s'), GetHashKey('prop_till_01'), true)

    while not pickedUp and not _shopContractDone and contractRunning do Wait(100) end

    finished = true
    if DoesEntityExist(npc) then DeletePed(npc) end

    ClearBlips()
    StopTimer()
    if contractRunning and (pickedUp or _shopContractDone) then
        contractRunning = false
        TriggerServerEvent('m3_illegaltablet:sv:robberyCompleted', 'supermarket')
    end
end

function StartBobcatRobbery(conf, contract)

    _bobcatDoorHacked  = false
    _bobcatVaultBlown  = false
    _bobcatCrateLooted = false

    if not IsIplActive(conf.ipl) then
        RequestIpl(conf.ipl)
        local iplT = 0
        while not IsIplActive(conf.ipl) and iplT < 5000 do Wait(100); iplT = iplT + 100 end
    end
    local interiorId = GetInteriorAtCoords(conf.interiorCoords.x, conf.interiorCoords.y, conf.interiorCoords.z)
    if interiorId ~= 0 then

        ActivateInteriorEntitySet(interiorId, 'np_prolog_clean')
        DeactivateInteriorEntitySet(interiorId, 'np_prolog_broken')
        RefreshInterior(interiorId)
    end

    Wait(1000)

    ClearBlips()
    activeBlip = AddBlip(vector3(conf.doorHackPos.x, conf.doorHackPos.y, conf.doorHackPos.z),
        conf.blipSprite, conf.blipColor, conf.label)
    if Config.ContractBlipRoute then SetBlipRoute(activeBlip, true) end
    StartTimer(conf.timeLimit)

    local frozenDoor          = nil
    local doorHacked          = false
    local _bobcatDispatchSent = false

    local function UnfreezeBobcatDoor()
        if not conf.doorFreezePos then return end
        local fposV = vector3(conf.doorFreezePos.x, conf.doorFreezePos.y, conf.doorFreezePos.z)

        local candidates = {}
        if frozenDoor and DoesEntityExist(frozenDoor) then
            candidates[#candidates + 1] = frozenDoor
        end
        for _, obj in ipairs(GetGamePool('CObject')) do
            if DoesEntityExist(obj) and #(GetEntityCoords(obj) - fposV) < 3.0 then
                candidates[#candidates + 1] = obj
            end
        end

        for _, obj in ipairs(candidates) do
            NetworkRequestControlOfEntity(obj)
        end
        Wait(200)

        for _, obj in ipairs(candidates) do
            if DoesEntityExist(obj) then
                FreezeEntityPosition(obj, false)
            end
        end
        frozenDoor = nil

        if conf.doorHash then
            SetStateOfClosestDoorOfType(
                GetHashKey(conf.doorHash),
                fposV.x, fposV.y, fposV.z,
                0, 0.0, false)
        end
    end

    if conf.doorFreezePos then
        local fposV = vector3(conf.doorFreezePos.x, conf.doorFreezePos.y, conf.doorFreezePos.z)
        CreateThread(function()
            while not doorHacked do
                if not (frozenDoor and DoesEntityExist(frozenDoor)
                        and #(GetEntityCoords(frozenDoor) - fposV) < 3.0) then
                    local bestDist = 3.0
                    frozenDoor = nil
                    for _, obj in ipairs(GetGamePool('CObject')) do
                        if DoesEntityExist(obj) then
                            local d = #(GetEntityCoords(obj) - fposV)
                            if d < bestDist then
                                frozenDoor = obj
                                bestDist   = d
                            end
                        end
                    end
                    if frozenDoor then NetworkRequestControlOfEntity(frozenDoor) end
                end
                if frozenDoor then
                    FreezeEntityPosition(frozenDoor, true)
                end

                if conf.doorHash then
                    SetStateOfClosestDoorOfType(
                        GetHashKey(conf.doorHash),
                        fposV.x, fposV.y, fposV.z,
                        1, 0.0, false)
                end
                Wait(100)
            end
        end)
    end

    local guardPeds   = {}
    local crateProp   = nil
    local doorBlocker = nil

    local function CleanupBobcat()
        doorHacked = true
        Wait(150)
        UnfreezeBobcatDoor()

        if not (contract and contract.isCrewMember) then
            TriggerServerEvent('m3_illegaltablet:sv:bobcatCleanupGuards')
        end
        guardPeds = {}

        if crateProp and DoesEntityExist(crateProp) then
            DeleteObject(crateProp)
            crateProp = nil
        end

        if doorBlocker and DoesEntityExist(doorBlocker) then
            DeleteObject(doorBlocker)
            doorBlocker = nil
        end

        ClearBlips()
        StopTimer()
    end

    if conf.doorBlockerModel then
        local bHash = GetHashKey(conf.doorBlockerModel)
        if WaitForModelLoad(bHash) then
            doorBlocker = CreateObject(bHash,
                conf.doorBlockerPos.x, conf.doorBlockerPos.y, conf.doorBlockerPos.z,
                false, false, false)
            SetEntityHeading(doorBlocker, conf.doorBlockerPos.w or 0.0)
            FreezeEntityPosition(doorBlocker, true)
            SetModelAsNoLongerNeeded(bHash)
        end
    end

    local doorZoneId

    doorZoneId = exports.ox_target:addSphereZone({
        coords  = vector3(conf.doorHackPos.x, conf.doorHackPos.y, conf.doorHackPos.z),
        radius  = 2.0,
        debug   = false,
        options = {{
            name     = 'bobcat_door',
            icon     = 'fas fa-keyboard',
            label    = 'Hack the door panel',
            items    = Config.HackingDeviceItem or 'hacking_device',
            onSelect = function()

                local hackItem = Config.HackingDeviceItem or 'hacking_device'
                if (exports.ox_inventory:GetItemCount(hackItem) or 0) < 1 then
                    Notify('You need ' .. hackItem .. '!', 'error')
                    return
                end
                TriggerServerEvent('m3_illegaltablet:sv:useHackingDevice')

                if not _bobcatDispatchSent then
                    _bobcatDispatchSent = true
                    if Dispatch and Dispatch.robbery then
                        Dispatch.robbery('robbery_bobcat',
                            vector3(conf.doorHackPos.x, conf.doorHackPos.y, conf.doorHackPos.z))
                    end
                end

                local ok
                if GetResourceState('bl_ui') == 'started' then
                    ok = exports.bl_ui:DigitDazzle(conf.doorHackDiff or 1,
                        { length = 4, duration = 50000 }) == true
                else
                    ok = DoHack('hard')
                end
                if ok then
                    doorHacked        = true
                    _bobcatDoorHacked = true
                    TriggerServerEvent('m3_illegaltablet:sv:crewBobcatDoorHacked')
                    Wait(150)
                    UnfreezeBobcatDoor()
                    exports.ox_target:removeZone(doorZoneId)

                    if doorBlocker and DoesEntityExist(doorBlocker) then
                        DeleteObject(doorBlocker)
                        doorBlocker = nil
                    end
                else
                    Notify('Hack failed! Try again.', 'error')
                end
            end,
        }},
    })

    do

        local nextReq = 0
        while not doorHacked and not _bobcatDoorHacked and contractRunning do
            if contract and contract.isCrewMember and GetGameTimer() >= nextReq then
                TriggerServerEvent('m3_illegaltablet:sv:requestBobcatState')
                nextReq = GetGameTimer() + 3000
            end
            Wait(250)
        end
    end

    if _bobcatDoorHacked and not doorHacked then
        doorHacked = true
        Wait(150)
        UnfreezeBobcatDoor()
        exports.ox_target:removeZone(doorZoneId)
        if doorBlocker and DoesEntityExist(doorBlocker) then
            DeleteObject(doorBlocker); doorBlocker = nil
        end
    end
    if not contractRunning then
        exports.ox_target:removeZone(doorZoneId)
        CleanupBobcat(); return
    end

    CreateThread(function()
        local nextReq = 0
        while not _bobcatLocalGuards and contractRunning do
            if GetGameTimer() >= nextReq then
                TriggerServerEvent('m3_illegaltablet:sv:bobcatNeedGuards')
                nextReq = GetGameTimer() + 3000
            end
            Wait(200)
        end
    end)

    ClearBlips()
    activeBlip = AddBlip(vector3(conf.vaultPos.x, conf.vaultPos.y, conf.vaultPos.z),
        458, 38, 'Vault')
    if Config.ContractBlipRoute then SetBlipRoute(activeBlip, true) end

    local vaultBlown = false
    local vaultZoneId

    vaultZoneId = exports.ox_target:addSphereZone({
        coords  = vector3(conf.vaultPos.x, conf.vaultPos.y, conf.vaultPos.z),
        radius  = 1.5,
        debug   = false,
        options = {{
            name     = 'bobcat_vault',
            icon     = 'fas fa-bomb',
            label    = 'Place C4 on the vault',
            onSelect = function()

                local hasC4 = (exports.ox_inventory:GetItemCount(conf.vaultC4Item) or 0) > 0
                if not hasC4 then
                    Notify(string.format('You need %s!', conf.vaultC4Item), 'error')
                    return
                end

                local ok = DoProgressBar('Placing C4...', conf.vaultPlantTime or 6000,
                    Config.Anims.drill.dict, Config.Anims.drill.clip, 1)
                if not ok then return end

                TriggerServerEvent('m3_illegaltablet:sv:bobcat:usedC4')
                exports.ox_target:removeZone(vaultZoneId)

                Notify(string.format('C4 set! Take cover! (%ds)',
                    math.floor((conf.vaultFuseTime or 3000) / 1000)), 'inform')
                Wait(conf.vaultFuseTime or 3000)

                AddExplosion(conf.vaultPos.x, conf.vaultPos.y, conf.vaultPos.z,
                    32, 100.0, true, false, 2.0)

                if interiorId ~= 0 then
                    ActivateInteriorEntitySet(interiorId, 'np_prolog_broken')
                    DeactivateInteriorEntitySet(interiorId, 'np_prolog_clean')
                    RefreshInterior(interiorId)
                end

                vaultBlown        = true
                _bobcatVaultBlown = true

                TriggerServerEvent('m3_illegaltablet:sv:crewBobcatVaultBlown')
            end,
        }},
    })

    while not vaultBlown and not _bobcatVaultBlown and contractRunning do Wait(250) end

    if _bobcatVaultBlown and not vaultBlown then
        vaultBlown = true
        if interiorId ~= 0 then
            ActivateInteriorEntitySet(interiorId, 'np_prolog_broken')
            DeactivateInteriorEntitySet(interiorId, 'np_prolog_clean')
            RefreshInterior(interiorId)
        end
        exports.ox_target:removeZone(vaultZoneId)
    end
    if not contractRunning then
        exports.ox_target:removeZone(vaultZoneId)
        CleanupBobcat(); return
    end

    ClearBlips()
    activeBlip = AddBlip(vector3(conf.cratePos.x, conf.cratePos.y, conf.cratePos.z),
        110, 38, 'Weapons')
    if Config.ContractBlipRoute then SetBlipRoute(activeBlip, true) end

    if conf.crateModel then
        local crateHash = GetHashKey(conf.crateModel)
        RequestModel(crateHash)
        local mt = 0
        while not HasModelLoaded(crateHash) and mt < 3000 do Wait(100); mt = mt + 100 end
        if HasModelLoaded(crateHash) then
            crateProp = CreateObject(crateHash,
                conf.cratePos.x, conf.cratePos.y, conf.cratePos.z,
                false, false, false)
            FreezeEntityPosition(crateProp, true)
            PlaceObjectOnGroundProperly(crateProp)
            SetModelAsNoLongerNeeded(crateHash)
        end
    end

    local crateLooted = false
    local crateZoneId

    crateZoneId = exports.ox_target:addSphereZone({
        coords  = vector3(conf.cratePos.x, conf.cratePos.y, conf.cratePos.z),
        radius  = 2.0,
        debug   = false,
        options = {{
            name     = 'bobcat_crate',
            icon     = 'fas fa-box-open',
            label    = 'Take weapons from the crates',
            onSelect = function()
                local ok = DoProgressBar('Collecting weapons...', conf.crateTime or 8000,
                    Config.Anims.search.dict, Config.Anims.search.clip, 49)
                if not ok then return end
                exports.ox_target:removeZone(crateZoneId)

                TriggerServerEvent('m3_illegaltablet:sv:crewBobcatCrateLooted')
                TriggerServerEvent('m3_illegaltablet:sv:bobcat:lootWeapons')
                CleanupBobcat()
                if contractRunning then
                    contractRunning = false
                    TriggerServerEvent('m3_illegaltablet:sv:robberyCompleted', 'bobcat')
                end
            end,
        }},
    })

    while contractRunning and not _bobcatCrateLooted do Wait(250) end
    if _bobcatCrateLooted then

        exports.ox_target:removeZone(crateZoneId)
        if crateProp and DoesEntityExist(crateProp) then
            DeleteObject(crateProp); crateProp = nil
        end
        CleanupBobcat()
        if contractRunning then
            contractRunning = false

            TriggerServerEvent('m3_illegaltablet:sv:crewRobberyCompleted', 'bobcat')
        end
    end
end

local function SpawnTruckConvoy(conf)
    local sp = conf.spawnPoints[math.random(#conf.spawnPoints)]
    local vh = joaat(conf.truckModel or 'stockade')
    if not WaitForModelLoad(vh) then return end

    local veh = CreateVehicle(vh, sp.x, sp.y, sp.z, sp.w or 0.0, true, false)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleDoorsLocked(veh, 1)
    SetModelAsNoLongerNeeded(vh)

    local dh = joaat(conf.driverModel or 's_m_m_armoured_01')
    local gh = joaat(conf.guardModel or 's_m_m_armoured_02')
    WaitForModelLoad(dh)
    WaitForModelLoad(gh)

    local driver = CreatePedInsideVehicle(veh, 4, dh, -1, true, false)
    local guard  = CreatePedInsideVehicle(veh, 4, gh, 0, true, false)
    SetModelAsNoLongerNeeded(dh)
    SetModelAsNoLongerNeeded(gh)

    AddRelationshipGroup('M3_TRUCK_GUARD')
    for _, ped in ipairs({ driver, guard }) do
        SetEntityAsMissionEntity(ped, true, true)
        SetPedArmour(ped, conf.guardArmor or 100)
        SetPedDropsWeaponsWhenDead(ped, false)
        SetPedFleeAttributes(ped, 0, false)
        SetPedRelationshipGroupHash(ped, GetHashKey('M3_TRUCK_GUARD'))
        SetPedAccuracy(ped, conf.guardAccuracy or 60)
    end

    SetBlockingOfNonTemporaryEvents(driver, true)

    SetBlockingOfNonTemporaryEvents(guard, true)
    SetPedCombatAttributes(guard, 46, true)
    SetPedCombatAttributes(guard, 3, true)
    SetPedCombatAttributes(guard, 5, true)
    SetPedCombatAbility(guard, 100)
    SetPedCombatMovement(guard, 2)
    SetPedCombatRange(guard, 2)
    GiveWeaponToPed(guard, joaat(conf.guardWeapon or 'WEAPON_COMBATPISTOL'), 250, false, true)

    TaskVehicleDriveWander(driver, veh, 12.0, 447)

    TriggerServerEvent('m3_illegaltablet:sv:truckSpawned',
        NetworkGetNetworkIdFromEntity(veh),
        NetworkGetNetworkIdFromEntity(driver),
        NetworkGetNetworkIdFromEntity(guard))
end

local function AddTruckTarget(veh, conf)
    exports.ox_target:addLocalEntity(veh, {
        {
            name     = 'm3_truck_c4',
            icon     = 'fas fa-bomb',
            label    = 'Place C4 on the rear doors',
            distance = 3.5,
            items    = conf.c4Item or 'c4',
            canInteract = function()
                return _truck and _truck.phase == 'stopped'
            end,
            onSelect = function()
                local c4 = conf.c4Item or 'c4'
                if (exports.ox_inventory:GetItemCount(c4) or 0) < 1 then
                    Notify(string.format('You need %s!', c4), 'error')
                    return
                end
                local ok = DoProgressBar('Placing C4...', conf.c4PlantTime or 6000,
                    Config.Anims.drill.dict, Config.Anims.drill.clip, 1)
                if not ok then return end
                TriggerServerEvent('m3_illegaltablet:sv:truckUseC4')
            end,
        },
        {
            name     = 'm3_truck_drill',
            icon     = 'fas fa-screwdriver-wrench',
            label    = 'Drill the door lock',
            distance = 3.5,
            items    = conf.drillItem or 'drill',
            canInteract = function()
                return _truck and _truck.phase == 'stopped'
            end,
            onSelect = function()

                local ok = lib.callback.await('m3_illegaltablet:sv:truckDrillAttempt', false)
                if not ok then return end

                local success = DoDrillMinigame()

                if success then
                    TriggerServerEvent('m3_illegaltablet:sv:truckDrilled')
                else
                    Notify('Drilling failed!', 'error')
                end
            end,
        },
        {
            name     = 'm3_truck_bag',
            icon     = 'fas fa-sack-dollar',
            label    = 'Grab the money bag',
            distance = 3.5,
            canInteract = function()
                return _truck and _truck.phase == 'blown' and (_truck.bags or 0) > 0
            end,
            onSelect = function()
                local ok = DoProgressBar('Taking the bag...', conf.bagTakeTime or 4000,
                    Config.Anims.search.dict, Config.Anims.search.clip, 49)
                if not ok then return end
                TriggerServerEvent('m3_illegaltablet:sv:truckTakeBag')
            end,
        },
    })
end

function StartTruckRobbery(conf, contract)
    local isLeader = not (contract and contract.isCrewMember)
    _truck = { phase = 'drive' }
    ClearTruckBagProps()
    StartTimer(conf.timeLimit)

    if isLeader then
        CreateThread(function() SpawnTruckConvoy(conf) end)
    else

        CreateThread(function()
            while contractRunning and not (_truck and _truck.vehNet) do
                TriggerServerEvent('m3_illegaltablet:sv:truckNeed')
                Wait(3000)
            end
        end)
    end

    local lastCircle     = nil
    local dispatchSent   = false
    local targetHandle   = nil
    local engageSent     = false
    local combatIssuedAt = 0

    local function crewPedDamaged(nid)
        if not nid then return false end
        local e = NetworkGetEntityFromNetworkId(nid)
        if not e or e == 0 or not DoesEntityExist(e) then return false end
        return HasEntityBeenDamagedByAnyPed(e) or GetEntityHealth(e) < GetEntityMaxHealth(e)
    end

    while contractRunning do
        local st = _truck
        if st then

            if not engageSent and st.phase == 'drive' and not st.engaged then
                if crewPedDamaged(st.driverNet) or crewPedDamaged(st.guardNet) then
                    engageSent = true
                    st.engaged = true
                    TriggerServerEvent('m3_illegaltablet:sv:truckEngage')
                end
            end

            if st.engaged and (st.phase == 'drive' or st.phase == 'stopped') and st.guardNet
                and GetGameTimer() - combatIssuedAt > 5000 then
                local g = NetworkGetEntityFromNetworkId(st.guardNet)
                if g and g ~= 0 and DoesEntityExist(g) and not IsPedDeadOrDying(g, true)
                    and NetworkHasControlOfEntity(g) then
                    combatIssuedAt = GetGameTimer()
                    if not IsPedInCombat(g, 0) then
                        SetPedRelationshipGroupHash(g, GetHashKey('M3_TRUCK_GUARD'))
                        SetBlockingOfNonTemporaryEvents(g, false)
                        SetPedCombatAttributes(g, 46, true)
                        SetPedCombatAttributes(g, 3, true)
                        SetPedCombatAbility(g, 100)
                        SetPedCombatMovement(g, 2)
                        SetPedCombatRange(g, 2)
                        SetPedAccuracy(g, conf.guardAccuracy or 60)
                        ClearPedTasks(g)
                        TaskCombatHatedTargetsAroundPed(g, 80.0, 0)
                    end
                end
            end
            local c = st.circle
            if c and (not lastCircle or c.x ~= lastCircle.x or c.y ~= lastCircle.y) then
                lastCircle = c
                if activeRadiusBlip and DoesBlipExist(activeRadiusBlip) then RemoveBlip(activeRadiusBlip) end
                activeRadiusBlip = AddBlipForRadius(c.x, c.y, c.z, conf.circleRadius or 180.0)
                SetBlipColour(activeRadiusBlip, 1)
                SetBlipAlpha(activeRadiusBlip, 80)
            end

            local veh = st.vehNet and NetworkGetEntityFromNetworkId(st.vehNet) or 0
            if veh and veh ~= 0 and DoesEntityExist(veh) then

                if targetHandle ~= veh then
                    if targetHandle then
                        exports.ox_target:removeLocalEntity(targetHandle, { 'm3_truck_c4', 'm3_truck_drill', 'm3_truck_bag' })
                    end
                    targetHandle = veh
                    AddTruckTarget(veh, conf)
                end

                if isLeader and not dispatchSent and st.phase ~= 'drive' then
                    dispatchSent = true
                    if Dispatch and Dispatch.robbery then
                        Dispatch.robbery('robbery_truck', GetEntityCoords(veh))
                    end
                end
            end
        end
        Wait(300)
    end

    if activeRadiusBlip and DoesBlipExist(activeRadiusBlip) then
        RemoveBlip(activeRadiusBlip); activeRadiusBlip = nil
    end
    ClearBlips()
    ClearTruckBagProps()
end

function StartJewelryRobbery(conf, contract)
    _jewelry        = nil
    _jewelryZones   = {}
    _jewelryAlarmOn = false

    Notify('Drill the entrance door lock, then smash the display cases and take the jewelry.', 'inform')

    if not (contract and contract.isCrewMember) then
        TriggerServerEvent('m3_illegaltablet:sv:jewelryStart')
    end
    CreateThread(function()
        while contractRunning and not (_jewelry and _jewelry.cases) do
            TriggerServerEvent('m3_illegaltablet:sv:jewelryNeed')
            Wait(3000)
        end
    end)

    local deadline = GetGameTimer() + 30000
    while contractRunning and not (_jewelry and _jewelry.cases) and GetGameTimer() < deadline do
        Wait(100)
    end
    if not contractRunning or not (_jewelry and _jewelry.cases) then return end

    local doorZone
    local frozenDoors = {}
    if conf.door then
        local doorPos = vector3(conf.door.x, conf.door.y, conf.door.z)
        local radius  = conf.doorFreezeRadius or 1.5

        CreateThread(function()
            while contractRunning and _jewelry and not _jewelry.doorDrilled do
                for _, obj in ipairs(GetGamePool('CObject')) do
                    if DoesEntityExist(obj) and #(GetEntityCoords(obj) - doorPos) < radius then
                        frozenDoors[obj] = true
                        FreezeEntityPosition(obj, true)
                    end
                end
                Wait(250)
            end
            for obj in pairs(frozenDoors) do
                if DoesEntityExist(obj) then FreezeEntityPosition(obj, false) end
            end
        end)

        doorZone = exports.ox_target:addSphereZone({
            coords  = doorPos,
            radius  = 1.5,
            debug   = false,
            options = {{
                name  = 'jewelry_door',
                icon  = 'fas fa-screwdriver-wrench',
                label = 'Drill the door lock',
                items = conf.drillItem or 'drill',
                canInteract = function()
                    return _jewelry and not _jewelry.doorDrilled
                end,
                onSelect = function()

                    local ok = lib.callback.await('m3_illegaltablet:sv:jewelryDrillAttempt', false)
                    if not ok then return end
                    local success = DoDrillMinigame()
                    if success then
                        TriggerServerEvent('m3_illegaltablet:sv:jewelryDoorDrilled')
                    else
                        Notify('Drilling failed!', 'error')
                    end
                end,
            }},
        })
    end

    local anim = conf.smashAnim or { dict = 'missheist_jewel', clip = 'smash_case' }
    for _, idx in ipairs(_jewelry.cases) do
        local pos = conf.cases[idx]
        if pos and not _jewelry.smashed[idx] then
            local caseIdx = idx
            _jewelryZones[caseIdx] = exports.ox_target:addSphereZone({
                coords  = pos,
                radius  = 1.2,
                debug   = false,
                options = {{
                    name  = 'jewelry_case_' .. caseIdx,
                    icon  = 'fas fa-gem',
                    label = 'Smash the display case',
                    canInteract = function()
                        return _jewelry and _jewelry.doorDrilled and not _jewelry.smashed[caseIdx]
                    end,
                    onSelect = function()
                        local ok = DoProgressBar('Smashing the display case...', conf.smashTime or 4000,
                            anim.dict, anim.clip, 1)
                        if not ok then return end
                        if _jewelry and _jewelry.smashed[caseIdx] then
                            Notify('This display case is already emptied.', 'error')
                            return
                        end
                        TriggerServerEvent('m3_illegaltablet:sv:jewelrySmash', caseIdx)
                    end,
                }},
            })
        end
    end

    CreateThread(function()
        while contractRunning do Wait(500) end
        JewelryCleanupZones()
        JewelryStopAlarm()
        if doorZone then exports.ox_target:removeZone(doorZone) end
    end)
end

function StartLabsRobbery(conf, contract)
    _labs      = nil
    _labsZones = {}
    _labsProps = {}


    if not (contract and contract.isCrewMember) then
        TriggerServerEvent('m3_illegaltablet:sv:labsStart')
    end
    CreateThread(function()
        while contractRunning and not (_labs and _labs.crates) do
            TriggerServerEvent('m3_illegaltablet:sv:labsNeed')
            Wait(3000)
        end
    end)

    local deadline = GetGameTimer() + 30000
    while contractRunning and not (_labs and _labs.crates) and GetGameTimer() < deadline do
        Wait(100)
    end
    if not contractRunning or not (_labs and _labs.crates) then return end

    local function ApplyLabsDoors(locked, ratio)
        for _, dp in ipairs(conf.doors or {}) do
            local pos = vector3(dp.x, dp.y, dp.z)
            local closest, dist = nil, 5.0
            for _, obj in ipairs(GetGamePool('CObject')) do
                if DoesEntityExist(obj) then
                    local d = #(GetEntityCoords(obj) - pos)
                    if d < dist then closest, dist = obj, d end
                end
            end
            if closest then
                SetStateOfClosestDoorOfType(GetEntityModel(closest),
                    pos.x, pos.y, pos.z, locked, ratio, false)
            end
        end
    end

    if conf.doors and #conf.doors > 0 then
        CreateThread(function()
            while contractRunning and _labs do
                if _labs.doorHacked then
                    ApplyLabsDoors(false, 1.0)
                else
                    ApplyLabsDoors(true, 0.0)
                end
                Wait(2000)
            end
            ApplyLabsDoors(false, 0.0)
        end)
    end

    local panelZone
    if conf.hackPanel then
        panelZone = exports.ox_target:addSphereZone({
            coords  = vector3(conf.hackPanel.x, conf.hackPanel.y, conf.hackPanel.z),
            radius  = 1.5,
            debug   = false,
            options = {{
                name  = 'labs_hack',
                icon  = 'fas fa-keyboard',
                label = 'Hack the entry panel',
                items = Config.HackingDeviceItem or 'hacking_device',
                canInteract = function()
                    return _labs and not _labs.doorHacked
                end,
                onSelect = function()

                    local hackItem = Config.HackingDeviceItem or 'hacking_device'
                    if (exports.ox_inventory:GetItemCount(hackItem) or 0) < 1 then
                        Notify('You need ' .. hackItem .. '!', 'error')
                        return
                    end
                    TriggerServerEvent('m3_illegaltablet:sv:useHackingDevice')
                    local ok
                    if GetResourceState('bl_ui') == 'started' then
                        ok = exports.bl_ui:DigitDazzle(conf.doorHackDiff or 2,
                            { length = 4, duration = 50000 }) == true
                    else
                        ok = DoHack('hard')
                    end
                    if ok then
                        TriggerServerEvent('m3_illegaltablet:sv:labsDoorHacked')
                    else
                        Notify('Hack failed!', 'error')
                    end
                end,
            }},
        })
    end

    local crateModel = joaat(conf.crateModel or 'sm_prop_smug_crate_s_chems')
    local crateLoaded = WaitForModelLoad(crateModel)

    for _, idx in ipairs(_labs.crates) do
        local pos = conf.cratePositions[idx]
        if pos and not _labs.searched[idx] then
            local crateIdx = idx

            if crateLoaded then
                local obj = CreateObject(crateModel, pos.x, pos.y, pos.z, false, false, false)
                SetEntityHeading(obj, pos.w or 0.0)
                PlaceObjectOnGroundProperly(obj)
                FreezeEntityPosition(obj, true)
                _labsProps[crateIdx] = obj
            end

            _labsZones[crateIdx] = exports.ox_target:addSphereZone({
                coords  = vector3(pos.x, pos.y, pos.z),
                radius  = 1.3,
                debug   = false,
                options = {{
                    name  = 'labs_crate_' .. crateIdx,
                    icon  = 'fas fa-flask',
                    label = 'Search the chemical crate',
                    canInteract = function()
                        return _labs and _labs.doorHacked and not _labs.searched[crateIdx]
                    end,
                    onSelect = function()
                        local ok = DoProgressBar('Searching the crate...', conf.searchTime or 5000,
                            Config.Anims.search.dict, Config.Anims.search.clip, 1)
                        if not ok then return end
                        if _labs and _labs.searched[crateIdx] then
                            Notify('This crate is already searched.', 'error')
                            return
                        end
                        TriggerServerEvent('m3_illegaltablet:sv:labsSearch', crateIdx)
                    end,
                }},
            })
        end
    end
    SetModelAsNoLongerNeeded(crateModel)

    local sampleZone
    if conf.samplePos then
        sampleZone = exports.ox_target:addSphereZone({
            coords  = vector3(conf.samplePos.x, conf.samplePos.y, conf.samplePos.z),
            radius  = 1.3,
            debug   = false,
            options = {{
                name  = 'labs_sample',
                icon  = 'fas fa-vial',
                label = 'Take the research sample',
                canInteract = function()
                    return _labs and _labs.doorHacked and not _labs.sampleTaken
                end,
                onSelect = function()
                    local ok
                    if GetResourceState('bl_ui') == 'started' then
                        ok = exports.bl_ui:DigitDazzle(conf.sampleHackDiff or 3,
                            { length = 5, duration = 50000 }) == true
                    else
                        ok = DoHack('hard')
                    end
                    if not ok then
                        Notify('Cooling box hack failed!', 'error')
                        return
                    end
                    local done = DoProgressBar('Taking the sample...', conf.sampleTime or 8000,
                        Config.Anims.search.dict, Config.Anims.search.clip, 1)
                    if not done then return end
                    if _labs and _labs.sampleTaken then
                        Notify('The sample is already taken.', 'error')
                        return
                    end
                    TriggerServerEvent('m3_illegaltablet:sv:labsSample')
                end,
            }},
        })
    end

    local deliveryPed
    CreateThread(function()
        while contractRunning and not (_labs and _labs.sampleTaken) do Wait(300) end
        if not contractRunning or not _labs or _labs.delivered then return end

        local npcs = conf.deliveryNpcs or {}
        local pick = npcs[_labs.deliveryIdx or 1] or npcs[1]
        if not pick then return end

        ClearBlips()
        activeBlip = AddBlip(vector3(pick.coords.x, pick.coords.y, pick.coords.z),
            480, 2, 'Sample buyer')
        if Config.ContractBlipRoute then SetBlipRoute(activeBlip, true) end
        Notify('Take the sample to the buyer - the spot is marked on your map.', 'inform')

        deliveryPed = SpawnNPC(pick.model or 'g_m_m_chigoon_01', pick.coords,
            'WORLD_HUMAN_SMOKING', true)
        if deliveryPed then
            exports.ox_target:addLocalEntity(deliveryPed, {{
                name  = 'labs_deliver',
                icon  = 'fas fa-hand-holding',
                label = 'Hand over the research sample',
                items = conf.sampleItem or 'chem_vzorka',
                canInteract = function()
                    return _labs and _labs.sampleTaken and not _labs.delivered
                end,
                onSelect = function()
                    local ok = DoProgressBar('Handing over the sample...', conf.deliverTime or 4000,
                        Config.Anims.handover.dict, Config.Anims.handover.clip, 49)
                    if not ok then return end
                    TriggerServerEvent('m3_illegaltablet:sv:labsDeliver')
                end,
            }})
        end

        while contractRunning and _labs and not _labs.delivered do Wait(300) end
        if deliveryPed and DoesEntityExist(deliveryPed) then
            DeleteEntity(deliveryPed)
            deliveryPed = nil
        end
    end)

    CreateThread(function()
        while contractRunning do Wait(500) end
        LabsCleanup()
        if panelZone then exports.ox_target:removeZone(panelZone) end
        if sampleZone then exports.ox_target:removeZone(sampleZone) end
        if deliveryPed and DoesEntityExist(deliveryPed) then DeleteEntity(deliveryPed) end
    end)
end

local LOOT_BOX_PROPS = {
    'prop_cardbordbox_04a',
    'prop_cardbordbox_04b',
    'prop_box_wood01a',
    'prop_box_wood02a',
    'prop_box_wood03a',
    'prop_crate_02a',
    'prop_mp_crate_01a',
    'prop_cs_box_of_stuff',
}

local function SpawnLootBox(coords, propList, forcedProp)
    local list     = (propList and #propList > 0) and propList or LOOT_BOX_PROPS
    local propName = forcedProp or list[math.random(#list)]
    local model    = GetHashKey(propName)
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 3000 do Wait(10); t = t + 10 end
    if not HasModelLoaded(model) then

        model = GetHashKey(list[1])
        RequestModel(model)
        local tf = 0
        while not HasModelLoaded(model) and tf < 3000 do Wait(10); tf = tf + 10 end
    end

    local box = CreateObject(model, coords.x, coords.y, coords.z + 0.5, false, false, false)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    local ct = 0
    while not HasCollisionLoadedAroundEntity(box) and ct < 2000 do
        Wait(50); ct = ct + 50
    end

    if not PlaceObjectOnGroundProperly(box) then

        local found, gz = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 0.5, false)
        SetEntityCoordsNoOffset(box, coords.x, coords.y, found and gz or coords.z, false, false, false)
    end
    FreezeEntityPosition(box, true)
    SetModelAsNoLongerNeeded(model)
    return box
end

local function PickLootItem(lootTable)
    local total = 0
    for _, lt in ipairs(lootTable) do total = total + lt.weight end
    local r, w = math.random(1, total), 0
    for _, lt in ipairs(lootTable) do
        w = w + lt.weight
        if r <= w then return lt.item end
    end
    return lootTable[1].item
end

local function AddBoxTarget(box, conf, onDone)
    exports.ox_target:addLocalEntity(box, {
        {
            name     = 'search_box_' .. box,
            icon     = 'fas fa-search',
            label    = 'Search the box',
            distance = 1.5,
            onSelect = function()
                local ok = DoProgressBar('Searching...', conf.searchTime,
                    Config.Anims.search.dict, Config.Anims.search.clip, 49)
                if ok then
                    exports.ox_target:removeLocalEntity(box, 'search_box_' .. box)
                    DeleteEntity(box)
                    onDone()
                end
            end,
        }
    })
end

local function AddUnifiedBoxTarget(box, boxIndex, contractId, conf, getSearched, searchCountRef, onDone, onContractFound)

    _burglaryBoxCallbacks[boxIndex] = function()
        exports.ox_target:removeLocalEntity(box, 'search_box_' .. box)
        if DoesEntityExist(box) then DeleteEntity(box) end
        if getSearched() + 1 >= searchCountRef[1] then
            onContractFound()
            Notify('A teammate found the contract! Head to the buyer NPC.', 'success')
        end
        onDone()
    end

    exports.ox_target:addLocalEntity(box, {
        {
            name     = 'search_box_' .. box,
            icon     = 'fas fa-search',
            label    = 'Search the box',
            distance = 1.5,
            onSelect = function()
                local ok = DoProgressBar('Searching...', conf.searchTime,
                    Config.Anims.search.dict, Config.Anims.search.clip, 49)
                if ok then
                    exports.ox_target:removeLocalEntity(box, 'search_box_' .. box)
                    DeleteEntity(box)

                    _burglaryBoxCallbacks[boxIndex] = nil

                    TriggerServerEvent('m3_illegaltablet:sv:crewBoxSearched', contractId, boxIndex)

                    if getSearched() + 1 >= searchCountRef[1] then
                        TriggerServerEvent('m3_illegaltablet:sv:burglary:giveContract')
                        Notify('You found the contract! Hand it to the buyer.', 'success')
                        onContractFound()
                    else
                        local item = PickLootItem(conf.lootTable)
                        local amt  = math.random(conf.itemsPerSearch.min, conf.itemsPerSearch.max)
                        TriggerServerEvent('m3_illegaltablet:sv:foundBurglaryItem', item, amt, conf.rewardPerItem)
                    end
                    onDone()
                end
            end,
        }
    })
end

local function SafeTeleport(coords, heading)
    local ped = PlayerPedId()

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    Wait(200)
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, heading or 0.0)

    local t = 0
    while not HasCollisionLoadedAroundEntity(ped) and t < 8000 do
        Wait(100); t = t + 100
    end
    Wait(300)
    FreezeEntityPosition(ped, false)
end

function StartBurglary(contract)
    local key  = contract.burglaryKey
    local conf = Config.Burglaries[key]
    if not conf then return end

    _crewBurglaryLockpicked = false
    _burglaryBoxCallbacks   = {}
    _burglaryNpcPos         = nil
    _burglaryNpcModel       = nil
    _burglaryDelivered      = false
    _burglaryContractFound  = false
    _burglaryBoxSync        = nil
    _burglarySealedId       = nil

    local locIndex  = contract.locationIndex or 1
    local targetLoc = contract.location or conf.locations[locIndex].exterior

    activeBlip = AddBlip(vector3(targetLoc.x, targetLoc.y, targetLoc.z), conf.blipSprite or 473, 38, conf.label)
    if Config.ContractBlipRoute then SetBlipRoute(activeBlip, true) end
    StartTimer(conf.timeLimit)

    CreateThread(function()

        local breakinId, enterId, exitId = nil, nil, nil

        local function removeBreakin()
            if not breakinId then return end
            exports.ox_target:removeZone(breakinId)
            breakinId = nil
        end
        local function removeEnter()
            if not enterId then return end
            exports.ox_target:removeZone(enterId)
            enterId = nil
        end
        local function removeExit()
            if not exitId then return end
            exports.ox_target:removeZone(exitId)
            exitId = nil
        end

        local picked            = false
        local _burgDispatchSent = false

        breakinId = exports.ox_target:addSphereZone({
            coords = vector3(targetLoc.x, targetLoc.y, targetLoc.z),
            radius = 1.5,
            debug  = false,
            options = {{
                name     = 'burglary_break_' .. key,
                icon     = 'fas fa-unlock',
                label    = 'Force the door',
                onSelect = function()

                    _burgDispatchSent = SendDispatchOnce(_burgDispatchSent, 'burglary',
                        vector3(targetLoc.x, targetLoc.y, targetLoc.z))

                    local ok = DoLockpick(conf.lockpickDiff)
                    if ok then
                        picked = true
                        removeBreakin()
                        TriggerServerEvent('m3_illegaltablet:sv:crewBurglaryLockpicked')
                    end
                end,
            }},
        })

        while not picked and not _crewBurglaryLockpicked and contractRunning do Wait(250) end
        if _crewBurglaryLockpicked then removeBreakin() end
        removeBreakin()
        if not contractRunning then ClearBlips(); StopTimer(); return end

        ClearBlips()

        local _contractObtained = false

        if conf.interior then
            local entry      = conf.interior.entry
            local exitDoor   = conf.interior.exitDoor
            local boxPos     = conf.interior.boxes
            local allBoxPos  = conf.interior.allBoxPositions
            local interiorId = conf.interior.interiorId

            local isInside     = false
            local pendingEnter = false
            local pendingExit  = false
            local finalExit    = false
            local savedPos     = nil
            local sealNotified = false

            local exitPos    = vector3(exitDoor.x, exitDoor.y, exitDoor.z)
            local exitRadius = allBoxPos and 2.5 or 1.2

            local function setupEnterZone()
                if _burglarySealedId == contract.id then return end
                enterId = exports.ox_target:addSphereZone({
                    coords  = vector3(targetLoc.x, targetLoc.y, targetLoc.z),
                    radius  = 1.5,
                    debug   = false,
                    options = {{
                        name     = 'burglary_enter_' .. key,
                        icon     = 'fas fa-door-open',
                        label    = 'Enter',
                        onSelect = function()
                            if isInside or pendingEnter then return end
                            savedPos = GetEntityCoords(PlayerPedId())
                            removeEnter()
                            pendingEnter = true
                        end,
                    }},
                })
            end

            local function setupExitZone()
                exitId = exports.ox_target:addSphereZone({
                    coords  = exitPos,
                    radius  = exitRadius,
                    debug   = false,
                    options = {{
                        name     = 'burglary_exit_' .. key,
                        icon     = 'fas fa-door-open',
                        label    = 'Go outside',
                        onSelect = function()
                            if not isInside or pendingExit then return end
                            removeExit()
                            pendingExit = true
                        end,
                    }},
                })
            end

            if conf.interior.ipl then RequestIpl(conf.interior.ipl) end
            setupEnterZone()

            if conf.interior.doorFreezePos then
                local dfv = vector3(
                    conf.interior.doorFreezePos.x,
                    conf.interior.doorFreezePos.y,
                    conf.interior.doorFreezePos.z)
                CreateThread(function()
                    local frozen = nil
                    while not finalExit and contractRunning do

                        if not (frozen and DoesEntityExist(frozen) and #(GetEntityCoords(frozen) - dfv) < 2.5) then
                            local bestDist = 2.5
                            frozen = nil
                            for _, obj in ipairs(GetGamePool('CObject')) do
                                if DoesEntityExist(obj) then
                                    local d = #(GetEntityCoords(obj) - dfv)
                                    if d < bestDist then frozen = obj; bestDist = d end
                                end
                            end
                        end
                        if frozen then FreezeEntityPosition(frozen, true) end
                        Wait(100)
                    end
                    for _, obj in ipairs(GetGamePool('CObject')) do
                        if DoesEntityExist(obj) and #(GetEntityCoords(obj) - dfv) < 2.5 then
                            FreezeEntityPosition(obj, false)
                        end
                    end
                end)
            end

            local searched     = 0
            local spawnedBoxes = {}
            local boxesSpawned = false

            local selBoxes = nil
            if not contract.isCrewMember then
                local _propList = (conf.searchProps and #conf.searchProps > 0) and conf.searchProps or LOOT_BOX_PROPS
                local function pickProp() return _propList[math.random(#_propList)] end
                selBoxes = {}
                if allBoxPos and #allBoxPos > 0 then
                    local maxB = math.min(conf.maxBoxes or 8, #allBoxPos)
                    local idx  = {}
                    for i = 1, #allBoxPos do idx[i] = i end
                    for i = #idx, 2, -1 do
                        local j = math.random(i)
                        idx[i], idx[j] = idx[j], idx[i]
                    end
                    for i = 1, maxB do
                        local p = allBoxPos[idx[i]]
                        selBoxes[i] = { x = p.x, y = p.y, z = p.z, prop = pickProp() }
                    end
                else
                    local sp = conf.searchPoints
                    local sc = type(sp) == 'table' and math.random(sp.min, sp.max) or (sp or 5)
                    for i = 1, sc do
                        local p = boxPos[i]
                        if not p then break end
                        selBoxes[#selBoxes + 1] = { x = p.x, y = p.y, z = p.z, prop = pickProp() }
                    end
                end
                TriggerServerEvent('m3_illegaltablet:sv:crewBurglaryBoxSync', contract.id, selBoxes)
            else

                CreateThread(function()
                    local nextReq = 0
                    while not _burglaryBoxSync and contractRunning and not finalExit do
                        if GetGameTimer() >= nextReq then
                            TriggerServerEvent('m3_illegaltablet:sv:requestBurglaryBoxSync')
                            nextReq = GetGameTimer() + 3000
                        end
                        Wait(200)
                    end
                end)
            end

            local function TrySpawnBoxes()
                if boxesSpawned then return end
                local boxes = contract.isCrewMember and _burglaryBoxSync or selBoxes
                if not boxes or #boxes == 0 then return end
                boxesSpawned = true
                local scRef = { #boxes }
                for i, p in ipairs(boxes) do
                    local box = SpawnLootBox(vector3(p.x, p.y, p.z), conf.searchProps, p.prop)
                    table.insert(spawnedBoxes, box)
                    AddUnifiedBoxTarget(box, i, contract.id, conf,
                        function() return searched end, scRef,
                        function() searched = searched + 1 end,
                        function() _contractObtained = true end)
                end
            end

            while not finalExit and contractRunning do

                if not isInside and not pendingEnter and (_contractObtained or _burglaryContractFound) then
                    finalExit = true; break
                end

                if pendingEnter then
                    pendingEnter = false
                    isInside     = true

                    TriggerServerEvent('m3_illegaltablet:sv:enterInterior', contract.id)

                    local ped = PlayerPedId()
                    DoScreenFadeOut(400); Wait(400)
                    FreezeEntityPosition(ped, true)

                    if conf.interior.ipl then
                        RequestIpl(conf.interior.ipl)
                        local iplTimer = 0
                        while not IsIplActive(conf.interior.ipl) and iplTimer < 6000 do
                            Wait(100); iplTimer = iplTimer + 100
                        end
                    end

                    SetFocusPosAndVel(entry.x, entry.y, entry.z, 0.0, 0.0, 0.0)
                    NewLoadSceneStartSphere(entry.x, entry.y, entry.z, 60.0, 0)
                    local sceneT = GetGameTimer()
                    while not IsNewLoadSceneLoaded() and GetGameTimer() - sceneT < 5000 do
                        RequestCollisionAtCoord(entry.x, entry.y, entry.z)
                        Wait(50)
                    end

                    SetEntityCoords(ped, entry.x, entry.y, entry.z, false, false, false, false)
                    SetEntityHeading(ped, entry.w or 0.0)

                    local pinnedInt = GetInteriorAtCoords(entry.x, entry.y, entry.z)
                    if pinnedInt ~= 0 then PinInteriorInMemory(pinnedInt) end

                    if interiorId then
                        local dl = GetGameTimer() + 8000
                        while GetInteriorFromEntity(ped) ~= interiorId and GetGameTimer() < dl do
                            Wait(10)
                        end
                        if GetInteriorFromEntity(ped) == interiorId then RefreshInterior(interiorId) end
                    elseif pinnedInt ~= 0 then
                        RefreshInterior(pinnedInt)
                    end

                    local ct = GetGameTimer()
                    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() - ct < 8000 do
                        RequestCollisionAtCoord(entry.x, entry.y, entry.z)
                        Wait(0)
                    end

                    NewLoadSceneStop()
                    ClearFocus()
                    Wait(200)
                    DoScreenFadeIn(300)
                    FreezeEntityPosition(ped, false)

                    TriggerServerEvent('m3_illegaltablet:sv:burglarySiteOpen', {
                        pos   = { x = targetLoc.x, y = targetLoc.y, z = targetLoc.z },
                        entry = { x = entry.x, y = entry.y, z = entry.z, w = entry.w or 0.0 },
                        exit  = { x = exitPos.x, y = exitPos.y, z = exitPos.z, r = exitRadius },
                        ipl   = conf.interior.ipl,
                    })

                    if not boxesSpawned then
                        if contract.isCrewMember and not _burglaryBoxSync then
                            Notify('Waiting for box info from the leader...', 'inform')
                            local dl2 = GetGameTimer() + 30000
                            while not _burglaryBoxSync and contractRunning and GetGameTimer() < dl2 do
                                Wait(100)
                            end
                        end
                        TrySpawnBoxes()
                    end

                    setupExitZone()

                elseif pendingExit then
                    pendingExit = false
                    isInside    = false

                    TriggerServerEvent('m3_illegaltablet:sv:exitInterior', contract.id)
                    Wait(150)

                    if savedPos then
                        DoScreenFadeOut(500); Wait(500)
                        local ped2 = PlayerPedId()
                        FreezeEntityPosition(ped2, true)
                        SetEntityCoords(ped2, savedPos.x, savedPos.y, savedPos.z, false, false, false, false)
                        local ct2 = GetGameTimer()
                        while not HasCollisionLoadedAroundEntity(ped2) and GetGameTimer() - ct2 < 5000 do
                            Wait(0)
                        end
                        Wait(200)
                        DoScreenFadeIn(300)
                        FreezeEntityPosition(ped2, false)
                    end
                    if conf.interior.ipl then RemoveIpl(conf.interior.ipl) end

                    if _contractObtained or _burglaryContractFound then
                        finalExit = true
                    else
                        setupEnterZone()
                    end
                end

                if isInside and not boxesSpawned and _burglaryBoxSync then
                    TrySpawnBoxes()
                end

                if _burglarySealedId == contract.id and not sealNotified then
                    sealNotified = true
                    removeEnter()
                    pendingEnter = false
                end

                Wait(50)
            end

            removeEnter(); removeExit()
            for _, box in ipairs(spawnedBoxes) do
                if DoesEntityExist(box) then
                    exports.ox_target:removeLocalEntity(box, 'search_box_' .. box)
                    DeleteEntity(box)
                end
            end

            if isInside and savedPos then
                TriggerServerEvent('m3_illegaltablet:sv:exitInterior', contract.id)
                Wait(150)
                DoScreenFadeOut(500); Wait(500)
                local ped3 = PlayerPedId()
                FreezeEntityPosition(ped3, true)
                SetEntityCoords(ped3, savedPos.x, savedPos.y, savedPos.z, false, false, false, false)
                local ct3 = GetGameTimer()
                while not HasCollisionLoadedAroundEntity(ped3) and GetGameTimer() - ct3 < 5000 do
                    Wait(0)
                end
                Wait(200)
                DoScreenFadeIn(300)
                FreezeEntityPosition(ped3, false)
                if conf.interior.ipl then RemoveIpl(conf.interior.ipl) end
            end

        else

            local searched     = 0
            local spawnedBoxes = {}
            local selectedPositions = {}

            if not contract.isCrewMember then

                local _propList = (conf.searchProps and #conf.searchProps > 0) and conf.searchProps or LOOT_BOX_PROPS
                local sp = conf.searchPoints
                local searchCount = type(sp) == 'table' and math.random(sp.min, sp.max) or (sp or 5)
                for i = 1, searchCount do
                    local offset = conf.searchOffsets and conf.searchOffsets[i] or vector3(i * 1.5, 0, 0)
                    local pos    = vector3(targetLoc.x + offset.x, targetLoc.y + offset.y, targetLoc.z + offset.z)
                    selectedPositions[i] = { x = pos.x, y = pos.y, z = pos.z,
                                             prop = _propList[math.random(#_propList)] }
                end
                TriggerServerEvent('m3_illegaltablet:sv:crewBurglaryBoxSync', contract.id, selectedPositions)
            else

                local deadline = GetGameTimer() + 60000
                local nextReq  = 0
                while not _burglaryBoxSync and contractRunning and GetGameTimer() < deadline do
                    if GetGameTimer() >= nextReq then
                        TriggerServerEvent('m3_illegaltablet:sv:requestBurglaryBoxSync')
                        nextReq = GetGameTimer() + 3000
                    end
                    Wait(100)
                end
                selectedPositions = _burglaryBoxSync or {}
            end

            local searchCount = #selectedPositions
            local scRef = { searchCount }
            for i, pos in ipairs(selectedPositions) do
                local box = SpawnLootBox(vector3(pos.x, pos.y, pos.z), conf.searchProps, pos.prop)
                table.insert(spawnedBoxes, box)
                AddUnifiedBoxTarget(box, i, contract.id, conf,
                    function() return searched end,
                    scRef,
                    function() searched = searched + 1 end,
                    function() _contractObtained = true end)
            end

            Notify('Search the boxes and find the contract.', 'inform')
            while not _contractObtained and contractRunning do Wait(250) end

            for _, box in ipairs(spawnedBoxes) do
                if DoesEntityExist(box) then
                    exports.ox_target:removeLocalEntity(box, 'search_box_' .. box)
                    DeleteEntity(box)
                end
            end
        end

        if not contractRunning then StopTimer(); return end

        if not _contractObtained then StopTimer(); return end

        local npcList = Config.BurglaryDeliveryNpcs or {}
        if #npcList == 0 then

            StopTimer()
            contractRunning = false
            TriggerServerEvent('m3_illegaltablet:sv:burglaryCompleted', key)
            return
        end

        local npcData
        if contract.isCrewMember then

            local deadline = GetGameTimer() + 120000
            local nextReq  = 0
            while not _burglaryNpcPos and contractRunning and GetGameTimer() < deadline do
                if GetGameTimer() >= nextReq then
                    TriggerServerEvent('m3_illegaltablet:sv:requestBurglaryNpc')
                    nextReq = GetGameTimer() + 3000
                end
                Wait(250)
            end
            if not _burglaryNpcPos or not contractRunning then
                ClearBlips(); StopTimer(); return
            end
            npcData = { coords = _burglaryNpcPos, model = _burglaryNpcModel }
        else

            npcData = npcList[math.random(#npcList)]
            local nc = npcData.coords
            TriggerServerEvent('m3_illegaltablet:sv:crewBurglaryNpcReady',
                nc.x, nc.y, nc.z, nc.w or 0.0, npcData.model or 'a_m_m_skater_01')
        end

        local npcCoords = npcData.coords
        local npcModel  = GetHashKey(npcData.model or 'a_m_m_skater_01')
        local deliveryNpc = nil

        if WaitForModelLoad(npcModel) then
            deliveryNpc = CreatePed(4, npcModel,
                npcCoords.x, npcCoords.y, npcCoords.z, npcCoords.w or 0.0,
                false, true)
            SetEntityInvincible(deliveryNpc, true)
            SetBlockingOfNonTemporaryEvents(deliveryNpc, true)
            FreezeEntityPosition(deliveryNpc, true)
            TaskStartScenarioInPlace(deliveryNpc, 'WORLD_HUMAN_STAND_MOBILE', 0, true)
            SetModelAsNoLongerNeeded(npcModel)
        end

        ClearBlips()
        activeBlip = AddBlip(vector3(npcCoords.x, npcCoords.y, npcCoords.z), 280, 5, 'Buyer')
        if Config.ContractBlipRoute then SetBlipRoute(activeBlip, true) end
        Notify('Hand the contract over to the buyer marked on your map.', 'inform')

        local delivered = false
        if deliveryNpc then
            exports.ox_target:addLocalEntity(deliveryNpc, {{
                name     = 'burglary_deliver',
                icon     = 'fas fa-file-alt',
                label    = 'Hand over the contract',
                distance = 3.0,
                onSelect = function()
                    local ci = Config.BurglaryContractItem or 'contract'
                    if (exports.ox_inventory:GetItemCount(ci) or 0) < 1 then
                        Notify('You have no contract!', 'error')
                        return
                    end
                    delivered = true
                    exports.ox_target:removeLocalEntity(deliveryNpc, 'burglary_deliver')

                    TriggerServerEvent('m3_illegaltablet:sv:crewBurglaryDelivered')
                end,
            }})
        end

        while not delivered and not _burglaryDelivered and contractRunning do Wait(250) end

        if deliveryNpc then
            exports.ox_target:removeLocalEntity(deliveryNpc, 'burglary_deliver')
            if DoesEntityExist(deliveryNpc) then DeletePed(deliveryNpc) end
        end
        ClearBlips()
        StopTimer()
        if contractRunning and (delivered or _burglaryDelivered) then
            contractRunning = false
            if delivered then

                TriggerServerEvent('m3_illegaltablet:sv:burglary:deliverContract')
            end
        end
    end)
end

local _policeSiteZones = {}
local _policeExitZone  = nil
local _policeSavedPos  = nil
local _policeInSite    = nil

local function PoliceExitSite(site)
    if _policeExitZone then
        exports.ox_target:removeZone(_policeExitZone)
        _policeExitZone = nil
    end
    TriggerServerEvent('m3_illegaltablet:sv:exitInterior', site.contractId)
    Wait(150)

    local ped = PlayerPedId()
    DoScreenFadeOut(500); Wait(500)
    FreezeEntityPosition(ped, true)
    if _policeSavedPos then
        SetEntityCoords(ped, _policeSavedPos.x, _policeSavedPos.y, _policeSavedPos.z,
            false, false, false, false)
    end
    local ct = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() - ct < 5000 do
        Wait(0)
    end
    Wait(200)
    DoScreenFadeIn(300)
    FreezeEntityPosition(ped, false)
    if site.ipl then RemoveIpl(site.ipl) end
    _policeInSite = nil
end

local function PoliceEnterSite(site)
    if _policeInSite then return end
    _policeInSite  = site.contractId
    _policeSavedPos = GetEntityCoords(PlayerPedId())

    TriggerServerEvent('m3_illegaltablet:sv:enterInterior', site.contractId)
    Wait(150)

    if site.ipl then
        RequestIpl(site.ipl)
        local t = 0
        while not IsIplActive(site.ipl) and t < 6000 do Wait(100); t = t + 100 end
        Wait(500)
    end

    local ped = PlayerPedId()
    DoScreenFadeOut(500); Wait(500)
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, site.entry.x, site.entry.y, site.entry.z, false, false, false, false)
    SetEntityHeading(ped, site.entry.w or 0.0)
    local ct = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() - ct < 8000 do
        Wait(0)
    end
    Wait(300)
    DoScreenFadeIn(300)
    FreezeEntityPosition(ped, false)

    _policeExitZone = exports.ox_target:addSphereZone({
        coords  = vector3(site.exit.x, site.exit.y, site.exit.z),
        radius  = site.exit.r or 1.5,
        debug   = false,
        options = {{
            name     = 'police_burglary_exit_' .. site.contractId,
            icon     = 'fas fa-door-open',
            label    = 'Go outside',
            onSelect = function() PoliceExitSite(site) end,
        }},
    })
end

RegisterNetEvent('m3_illegaltablet:cl:burglaryPoliceSite', function(site)
    if not site or not site.contractId then return end
    if _policeSiteZones[site.contractId] then return end
    _policeSiteZones[site.contractId] = exports.ox_target:addSphereZone({
        coords  = vector3(site.pos.x, site.pos.y, site.pos.z),
        radius  = 1.8,
        debug   = false,
        options = {
            {
                name     = 'police_burglary_enter_' .. site.contractId,
                icon     = 'fas fa-door-open',
                label    = 'Enter the crime scene',
                onSelect = function() PoliceEnterSite(site) end,
            },
            {
                name     = 'police_burglary_seal_' .. site.contractId,
                icon     = 'fas fa-ban',
                label    = 'Seal the crime scene',
                onSelect = function()
                    TriggerServerEvent('m3_illegaltablet:sv:sealBurglarySite', site.contractId)
                end,
            },
        },
    })
end)

RegisterNetEvent('m3_illegaltablet:cl:burglaryPoliceSiteRemove', function(contractId)
    local z = _policeSiteZones[contractId]
    if z then
        exports.ox_target:removeZone(z)
        _policeSiteZones[contractId] = nil
    end
end)
