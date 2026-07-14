
local Ox    = exports.ox_core
local OxInv = exports.ox_inventory

local tabletOpen     = false
local tabletProp     = nil
local activeContract = nil

function GetPlayerFullName()
    local data = Ox:GetPlayerData()
    if not data then return 'Player' end
    return (data.firstName or '') .. ' ' .. (data.lastName or '')
end

function HasItem(item)
    local count = OxInv:GetItemCount(item)
    return (count or 0) > 0
end

local _tabletAnimDict = 'amb@code_human_in_bus_passenger_idles@female@tablet@idle_a'
local _tabletAnimClip = 'idle_a'

CreateThread(function() lib.requestAnimDict(_tabletAnimDict) end)

local function StartTabletAnim()
    local ped = PlayerPedId()
    lib.requestAnimDict(_tabletAnimDict)

    TaskPlayAnim(ped, _tabletAnimDict, _tabletAnimClip, 3.0, -8.0, -1, 49, 0, false, false, false)

    local model = `prop_cs_tablet`
    lib.requestModel(model)
    tabletProp = CreateObject(model, GetEntityCoords(ped), true, true, false)
    local bone = GetPedBoneIndex(ped, 28422)
    AttachEntityToEntity(tabletProp, ped, bone,
        -0.05, 0.0, 0.0,
        0.0, -90.0, 0.0,
        true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
end

local function StopTabletAnim()
    ClearPedTasks(PlayerPedId())
    if tabletProp and DoesEntityExist(tabletProp) then DeleteEntity(tabletProp) end
    tabletProp = nil
end

local _cachedTabletData = nil

local function OpenTablet()
    if tabletOpen then return end
    tabletOpen = true

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = _cachedTabletData or {} })

    TriggerServerEvent('m3_illegaltablet:sv:requestTabletData')

    StartTabletAnim()
end

local function CloseTablet()
    if not tabletOpen then return end
    tabletOpen = false

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    StopTabletAnim()
end

if Config.UseItem then

    RegisterNetEvent('m3_illegaltablet:cl:useTabletItem', function()
        CreateThread(function()

            Wait(200)
            if tabletOpen then CloseTablet() else OpenTablet() end
        end)
    end)
else

    RegisterCommand('tablet', function()
        if tabletOpen then CloseTablet() else OpenTablet() end
    end, false)
    RegisterKeyMapping('tablet', 'Open / close tablet', 'keyboard', Config.TabletKeyLabel)
end

RegisterNUICallback('close', function(_, cb)
    CloseTablet()
    cb({ ok = true })
end)

RegisterNUICallback('acceptContract', function(data, cb)
    if activeContract then
        Notify(T('already_active'), 'error')
        cb({ ok = false })
        return
    end
    TriggerServerEvent('m3_illegaltablet:sv:acceptContract', data.id)
    cb({ ok = true })
end)

RegisterNUICallback('cancelContract', function(_, cb)
    if activeContract then
        TriggerServerEvent('m3_illegaltablet:sv:cancelContract')
        CancelActiveContract()
    end
    cb({ ok = true })
end)

RegisterNUICallback('setReceiving', function(data, cb)
    TriggerServerEvent('m3_illegaltablet:sv:setReceiving', data and data.enabled == true)
    cb({ ok = true })
end)

RegisterNUICallback('setXpShares', function(data, cb)

    TriggerServerEvent('m3_illegaltablet:sv:setXpShares', data)
    cb({ ok = true })
end)

RegisterNUICallback('updateFilter', function(data, cb)
    TriggerServerEvent('m3_illegaltablet:sv:updateFilter', data.filter)
    cb({ ok = true })
end)

RegisterNUICallback('inviteToCrew', function(data, cb)
    TriggerServerEvent('m3_illegaltablet:sv:inviteToCrew', data.playerId)
    cb({ ok = true })
end)

RegisterNUICallback('kickCrewMember', function(data, cb)
    TriggerServerEvent('m3_illegaltablet:sv:kickCrewMember', data.name)
    cb({ ok = true })
end)

RegisterNUICallback('setPlayerName', function(data, cb)
    TriggerServerEvent('m3_illegaltablet:sv:setPlayerName', data.name)
    cb({ ok = true })
end)

RegisterNUICallback('respondToCrewInvite', function(data, cb)
    TriggerServerEvent('m3_illegaltablet:sv:respondToCrewInvite', data.leaderSrc, data.accepted)
    cb({ ok = true })
end)

local function MergeTabletCache(data)
    if not _cachedTabletData or type(data) ~= 'table' then return end
    for k, v in pairs(data) do
        _cachedTabletData[k] = v
    end
end

RegisterNetEvent('m3_illegaltablet:cl:openTablet', function(data)
    _cachedTabletData = data

    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNetEvent('m3_illegaltablet:cl:updateData', function(data)
    MergeTabletCache(data)
    SendNUIMessage({ action = 'update', data = data })
end)

RegisterNetEvent('m3_illegaltablet:cl:startContract', function(contract)
    activeContract = contract
    StartContractExecution(contract)
    local nuiData = { activeContract = contract }
    if not contract.isCrewMember then

        nuiData.initAsLeader = true
        nuiData.isCrewLeader = true
    end
    MergeTabletCache(nuiData)
    SendNUIMessage({ action = 'update', data = nuiData })
end)

local function ResetContractNuiState()
    local data = {
        activeContract = false,
        initAsLeader   = false,
        isCrewLeader   = false,
        crewMembers    = {},
        crewSize       = 1,
    }
    MergeTabletCache(data)
    SendNUIMessage({ action = 'update', data = data })
end

RegisterNetEvent('m3_illegaltablet:cl:contractDone', function(reward)
    contractRunning = false
    activeContract  = nil
    if ClearBlips then ClearBlips() end
    if StopTimer then StopTimer() end
    if reward and reward > 0 then
        Notify(T('contract_completed', reward), 'success')
    end
    ResetContractNuiState()
end)

RegisterNetEvent('m3_illegaltablet:cl:contractFailed', function(reason)
    activeContract = nil
    Notify(reason or T('contract_failed'), 'error')
    ResetContractNuiState()
end)

RegisterNetEvent('m3_illegaltablet:cl:leaderboardData', function(data)
    SendNUIMessage({ action = 'leaderboardData', data = data })
end)

RegisterNUICallback('fetchLeaderboard', function(_, cb)
    TriggerServerEvent('m3_illegaltablet:sv:fetchLeaderboard')
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end

    if tabletProp and DoesEntityExist(tabletProp) then DeleteEntity(tabletProp) end
    ClearPedTasks(PlayerPedId())
end)

RegisterNetEvent('m3_illegaltablet:cl:kickedFromCrew', function()
    activeContract = nil

    ResetContractNuiState()
end)

RegisterNetEvent('m3_illegaltablet:cl:crewInviteReceived', function(inviteData)

    SendNUIMessage({ action = 'crewInvite', data = inviteData })
end)

RegisterNUICallback('respondToCrewInvite', function(data, cb)
    TriggerServerEvent('m3_illegaltablet:sv:respondToCrewInvite',
        data.leaderSrc, data.accepted == true)
    cb({ ok = true })
end)

local _globalAlertRadius = nil

RegisterNetEvent('m3_illegaltablet:cl:globalAlert', function(cx, cy, cz, radius)
    if _globalAlertRadius and DoesBlipExist(_globalAlertRadius) then RemoveBlip(_globalAlertRadius) end
    _globalAlertRadius = AddBlipForRadius(vector3(cx, cy, cz), radius * 1.0)
    SetBlipColour(_globalAlertRadius, 1)
    SetBlipAlpha(_globalAlertRadius, 60)
end)

RegisterNetEvent('m3_illegaltablet:cl:globalAlertClear', function()
    if _globalAlertRadius and DoesBlipExist(_globalAlertRadius) then
        RemoveBlip(_globalAlertRadius); _globalAlertRadius = nil
    end
end)

RegisterNetEvent('m3_illegaltablet:cl:policeAlert', function(x, y, z, radius, duration)
    CreateThread(function()
        local blip = AddBlipForRadius(x, y, z, radius)
        SetBlipColour(blip, 1)
        SetBlipAlpha(blip, 120)
        Wait((duration or 6) * 1000)
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)

RegisterNetEvent('m3_illegaltablet:cl:resetFleecaInterior', function()
    local conf = Config.Robberies and Config.Robberies.fleeca
    if not conf then return end
    for _, loc in ipairs(conf.locations or {}) do
        if loc.vaultDoorHash and loc.vaultDoorPos then
            local dp = loc.vaultDoorPos
            AddDoorToSystem(loc.vaultDoorHash, loc.vaultDoorHash,
                dp.x, dp.y, dp.z, false, false, false)
            DoorSystemSetDoorState(loc.vaultDoorHash, 0, false, false)
        end
    end
end)

function GetActiveContract()  return activeContract  end
function SetActiveContract(c) activeContract = c     end
function CancelActiveContract()

    if activeContract and activeContract.id then
        TriggerServerEvent('m3_illegaltablet:sv:exitInterior', activeContract.id)
    end
    contractRunning = false
    activeContract  = nil
    ClearBlips()
    StopTimer()
    CleanupSpawnedVehicle()
    ClearPedTasks(PlayerPedId())
    SendNUIMessage({
        action = 'update',
        data = { activeContract = false }
    })
end
