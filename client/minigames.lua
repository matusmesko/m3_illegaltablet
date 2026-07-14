
local _lockpickResolve = nil

RegisterNUICallback('lockpickSucceed', function(_, cb)
    cb({ ok = true })
    if _lockpickResolve then
        local fn = _lockpickResolve
        _lockpickResolve = nil
        fn(true)
    end
end)

RegisterNUICallback('lockpickFailed', function(_, cb)
    cb({ ok = true })
    if _lockpickResolve then
        local fn = _lockpickResolve
        _lockpickResolve = nil
        fn(false)
    end
end)

local function RunLockpickNUI(diff)
    local settings = {
        easy   = { pinDamage = 15, maxDistFromSolve = 60 },
        medium = { pinDamage = 20, maxDistFromSolve = 45 },
        hard   = { pinDamage = 30, maxDistFromSolve = 28 },
    }
    local s = settings[diff] or settings.medium

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'lockpick_start', pinDamage = s.pinDamage, maxDistFromSolve = s.maxDistFromSolve })

    local p = promise.new()
    _lockpickResolve = function(result) p:resolve(result) end
    local result = Citizen.Await(p)

    SetNuiFocus(false, false)
    return result
end

function DoLockpick(diff)
    local anim = Config.Anims.lockpick
    lib.requestAnimDict(anim.dict)

    if not contractRunning then
        ClearPedTasks(PlayerPedId())
        return false
    end

    if Config.LockpickItem and not HasItem(Config.LockpickItem) then
        Notify('You have no lockpick!', 'error')
        ClearPedTasks(PlayerPedId())
        return false
    end

    TaskPlayAnim(PlayerPedId(), anim.dict, anim.clip,
        3.0, -1.0, -1, 1, 0, false, false, false)

    local ok = RunLockpickNUI(diff)
    ClearPedTasks(PlayerPedId())

    if ok then
        return true
    end

    TriggerServerEvent('m3_illegaltablet:sv:usedLockpick')
    return false
end

local function SkillCheckConfig(diff)
    if diff == 'easy'   then return { 'easy', 'easy' }
    elseif diff == 'hard' then return { 'easy', 'medium', 'hard', 'hard', 'hard' }
    else                       return { 'easy', 'medium', 'medium' }
    end
end

function DoHack(diff)
    diff = diff or 'medium'
    local anim = Config.Anims.hack
    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(PlayerPedId(), anim.dict, anim.clip, 3.0, -1.0, -1, 49, 0, false, false, false)

    local cfg = SkillCheckConfig(diff)
    local ok = lib.skillCheck(cfg, { 'w', 'a', 's', 'd' })
    ClearPedTasks(PlayerPedId())
    return ok
end

function DoAtmHack()
    if GetResourceState('bl_ui') == 'started' then

    local ok = exports.bl_ui:DigitDazzle(3, {
        length = 4,
        duration = 50000,
    })
        return ok == true
    else

        return DoHack('hard')
    end
end

function DoProgressBar(label, duration, animDict, animClip, flags)
    animDict = animDict or Config.Anims.drill.dict
    animClip = animClip or Config.Anims.drill.clip
    flags    = flags or 1

    local ok = lib.progressBar({
        duration   = duration,
        label      = label,
        useWhileDead  = false,
        canCancel  = true,
        disable    = { move = true, car = true, combat = true, sprint = true },
        anim       = { dict = animDict, clip = animClip, flag = flags },
    })
    return ok
end

function DoSearch(label, duration)
    return DoProgressBar(
        label,
        duration,
        Config.Anims.search.dict,
        Config.Anims.search.clip,
        49
    )
end

function DoDrillMinigame()
    local cfg       = Config.DrillMinigame or {}
    local key       = cfg.key or 38
    local cancelKey = cfg.cancelKey or 177

    local sf = RequestScaleformMovie('VAULT_DRILL')
    local t = 0
    while not HasScaleformMovieLoaded(sf) and t < 5000 do Wait(10); t = t + 10 end
    if not HasScaleformMovieLoaded(sf) then return false end

    local ped   = PlayerPedId()
    local model = joaat(cfg.model or 'hei_prop_heist_drill')
    RequestModel(model)
    t = 0
    while not HasModelLoaded(model) and t < 5000 do Wait(10); t = t + 10 end

    local dict = cfg.animDict or 'anim@heists@fleeca_bank@drilling'
    local clip = cfg.animClip or 'drill_straight_idle'
    RequestAnimDict(dict)
    t = 0
    while not HasAnimDictLoaded(dict) and t < 5000 do Wait(10); t = t + 10 end

    RequestAmbientAudioBank('DLC_HEIST_FLEECA_SOUNDSET', 0)
    RequestAmbientAudioBank('DLC_MPHEIST\\HEIST_FLEECA_DRILL', 0)
    RequestAmbientAudioBank('DLC_MPHEIST\\HEIST_FLEECA_DRILL_2', 0)

    local prop = nil
    if HasModelLoaded(model) then
        prop = CreateObject(model, GetEntityCoords(ped), true, true, false)
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 28422),
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, false, 2, true)
        SetModelAsNoLongerNeeded(model)
    end

    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    FreezeEntityPosition(ped, true)
    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(ped, dict, clip, 3.0, -3.0, -1, 49, 0, false, false, false)
    end

    BeginScaleformMovieMethod(sf, 'SET_NUM_DISCS')
    ScaleformMovieMethodAddParamInt(cfg.numDiscs or 4)
    EndScaleformMovieMethod()

    local speed, temp, pos = 0.0, 0.0, 0.0
    local soundId, soundOn = nil, false
    local success, running = false, true

    local function stopSound()
        if soundOn then
            StopSound(soundId)
            ReleaseSoundId(soundId)
            StopGameplayCamShaking(true)
            soundOn = false
        end
    end

    while running do
        DisableAllControlActions(0)
        EnableControlAction(0, 220, true)
        EnableControlAction(0, 221, true)

        DrawScaleformMovie(sf, 0.5, 0.5, 0.7, 0.7, 255, 255, 255, 255, 0)
        DrawText2D(0.34, 0.9, '~INPUT_CONTEXT~ drill  |  release = cooling  |  ~INPUT_FRONTEND_RRIGHT~ cancel', 0.32)

        local holding = IsDisabledControlPressed(0, key)

        if holding then
            speed = math.min(speed + 0.05, cfg.maxSpeed or 0.7)
            if not soundOn and prop then
                soundId = GetSoundId()
                PlaySoundFromEntity(soundId, 'Drill', prop, 'DLC_HEIST_FLEECA_SOUNDSET', true, 0)
                if cfg.shakeCam then ShakeGameplayCam('SKY_DIVING_SHAKE', cfg.shakeInt or 0.4) end
                soundOn = true
            end
        else
            speed = math.max(0.0, speed - 0.05)
            if speed <= 0.0 then stopSound() end
        end

        if speed > (cfg.heatThreshold or 0.4) then
            temp = temp + speed * (cfg.heatUp or 0.01)
        else
            temp = math.max(0.0, temp - (cfg.coolRate or 0.02))
        end
        if temp < (cfg.maxTemp or 1.0) then
            pos = pos + speed * (cfg.posRate or 0.0015)
        end

        BeginScaleformMovieMethod(sf, 'SET_SPEED')
        ScaleformMovieMethodAddParamFloat(speed)
        EndScaleformMovieMethod()
        BeginScaleformMovieMethod(sf, 'SET_DRILL_POSITION')
        ScaleformMovieMethodAddParamFloat(pos)
        EndScaleformMovieMethod()
        BeginScaleformMovieMethod(sf, 'SET_TEMPERATURE')
        ScaleformMovieMethodAddParamFloat(temp)
        EndScaleformMovieMethod()

        if temp >= (cfg.maxTemp or 1.0) then
            success = false; running = false
        elseif pos >= 1.0 then
            success = true; running = false
        elseif IsDisabledControlJustPressed(0, cancelKey) then
            success = false; running = false
        end

        Wait(0)
    end

    stopSound()
    FreezeEntityPosition(ped, false)
    StopAnimTask(ped, dict, clip, 1.0)
    if prop and DoesEntityExist(prop) then
        DetachEntity(prop, true, true)
        DeleteObject(prop)
    end
    SetScaleformMovieAsNoLongerNeeded(sf)
    RemoveAnimDict(dict)
    return success
end

function PickLoot(lootTable)
    local total = 0
    for _, v in ipairs(lootTable) do total = total + v.weight end
    local roll = math.random(1, total)
    local cum  = 0
    for _, v in ipairs(lootTable) do
        cum = cum + v.weight
        if roll <= cum then return v.item end
    end
    return lootTable[1].item
end
