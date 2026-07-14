
local MAX_CREW_SIZE = 4

activeCrew    = {}
playerCrewMap = {}

xpSharesMap = {}

function GetXpShare(leaderSrc, memberSrc)
    local shares = xpSharesMap[leaderSrc]
    if shares and shares[memberSrc] then
        return shares[memberSrc]
    end

    local size = 1
    if activeCrew[leaderSrc] then
        size = #activeCrew[leaderSrc].members + 1
    end
    return math.floor(100 / size)
end

local function GetTabletName(src)
    local pd = GetPD(src)
    if pd and pd.name and pd.name ~= '' then
        return pd.name
    end
    return GetPlayerFullName(src)
end

local function BuildCrewPacket(leaderSrc, isLeader)
    local crew = activeCrew[leaderSrc]

    local members = {}
    members[#members + 1] = {
        name     = GetTabletName(leaderSrc),
        isLeader = true,
    }
    if crew then
        for _, msrc in ipairs(crew.members) do
            members[#members + 1] = {
                name     = GetTabletName(msrc),
                isLeader = false,
            }
        end
    end
    return {
        crewMembers  = members,
        crewSize     = #members,
        maxSize      = MAX_CREW_SIZE,
        isCrewLeader = isLeader == true,
        leaderName   = GetTabletName(leaderSrc),
    }
end

function GetCrewDataForSrc(src)
    local leaderSrc = activeCrew[src] and src or playerCrewMap[src]
    if not leaderSrc then return nil end
    local isLeader = (leaderSrc == src)
    return BuildCrewPacket(leaderSrc, isLeader)
end

local function BroadcastCrewUpdate(leaderSrc)
    TriggerClientEvent('m3_illegaltablet:cl:updateData', leaderSrc,
        BuildCrewPacket(leaderSrc, true))
    if activeCrew[leaderSrc] then
        for _, msrc in ipairs(activeCrew[leaderSrc].members) do
            TriggerClientEvent('m3_illegaltablet:cl:updateData', msrc,
                BuildCrewPacket(leaderSrc, false))
        end
    end
end

RegisterNetEvent('m3_illegaltablet:sv:setXpShares', function(nameShares)
    local src = source

    if not activeCrew[src] then return end

    local crew = activeCrew[src]
    local allSrcs = { src }
    for _, msrc in ipairs(crew.members) do allSrcs[#allSrcs + 1] = msrc end

    local result = {}
    local total  = 0
    for _, s in ipairs(allSrcs) do
        local name = GetTabletName(s)
        local pct  = tonumber(nameShares[name]) or 0
        result[s] = pct
        total     = total + pct
    end

    if total ~= 100 then return end
    xpSharesMap[src] = result
end)

function CleanupCrewFor(src)

    if activeCrew[src] then
        local crew = activeCrew[src]
        for _, msrc in ipairs(crew.members) do
            SetPlayerRoutingBucket(msrc, 0)
            playerCrewMap[msrc] = nil
            activeContracts[msrc] = nil
            TriggerClientEvent('m3_illegaltablet:cl:contractDone', msrc, 0)
        end
        activeCrew[src] = nil
        xpSharesMap[src] = nil
    end

    local leaderSrc = playerCrewMap[src]
    if leaderSrc and activeCrew[leaderSrc] then
        local crew = activeCrew[leaderSrc]
        for i, msrc in ipairs(crew.members) do
            if msrc == src then
                table.remove(crew.members, i)
                break
            end
        end
        playerCrewMap[src] = nil

        BroadcastCrewUpdate(leaderSrc)
    end
end

RegisterNetEvent('m3_illegaltablet:sv:inviteToCrew', function(targetPlayerId)
    local src      = source
    local contract = activeContracts[src]
    if not contract then
        Notify(src, 'You must have an active contract to invite a player.', 'error')
        return
    end

    if contract.robberyKey == 'atm' then
        Notify(src, 'The ATM robbery is single-player only.', 'error')
        return
    end

    if not activeCrew[src] then
        activeCrew[src] = { members = {} }
    end
    local crew = activeCrew[src]

    if (#crew.members + 1) >= MAX_CREW_SIZE then
        Notify(src, string.format('The crew is full (%d/%d).', #crew.members + 1, MAX_CREW_SIZE), 'error')
        return
    end

    local pid = tonumber(targetPlayerId)
    if not pid or pid < 1000 or pid > 9999 then
        Notify(src, 'Enter a valid 4-digit ID (1000-9999).', 'error')
        return
    end

    local targetSrc = GetSrcByPlayerId(pid)
    if not targetSrc then
        Notify(src, string.format('Player #%04d is not online.', pid), 'error')
        return
    end
    if targetSrc == src then
        Notify(src, 'You cannot invite yourself.', 'error')
        return
    end

    if activeCrew[targetSrc] or playerCrewMap[targetSrc] then
        Notify(src, string.format('Player #%04d is already in another crew.', pid), 'error')
        return
    end

    for _, msrc in ipairs(crew.members) do
        if msrc == targetSrc then
            Notify(src, string.format('Player #%04d is already in your crew.', pid), 'error')
            return
        end
    end

    if activeContracts[targetSrc] then
        Notify(src, string.format('Player #%04d is currently in another contract.', pid), 'error')
        return
    end

    local pd_target = GetPD(targetSrc)
    if not pd_target then

        local row = MySQL.single.await(
            'SELECT boosting_xp, burglary_xp FROM m3_tablet WHERE player_id = ?', { pid })
        if not row then
            Notify(src, 'Error: cannot load player data.', 'error')
            return
        end
        pd_target = { redXP = row.boosting_xp or 0, greenXP = row.burglary_xp or 0 }
    end

    local xpOk  = true
    local xpMsg = ''

    if contract.type == 'vehicle_theft' then
        local cat    = contract.category and Config.VehicleCategories[contract.category]
        local needed = cat and (cat.minRedXP or 0) or 0
        if pd_target.redXP < needed then
            xpOk  = false
            xpMsg = string.format(
                'Player #%04d does not have enough XP for this contract. (Needs: %d, Has: %d)',
                pid, needed, pd_target.redXP)
        end
    else

        local contractId = contract.contractKey or contract.id
        local needed     = 0
        for _, unlock in ipairs(Config.GreenXPUnlocks) do
            for _, cid in ipairs(unlock.contracts) do
                if cid == contractId then
                    needed = unlock.minXP
                    break
                end
            end
        end
        if pd_target.greenXP < needed then
            xpOk  = false
            xpMsg = string.format(
                'Player #%04d does not have enough XP for this contract. (Needs: %d, Has: %d)',
                pid, needed, pd_target.greenXP)
        end
    end

    if not xpOk then
        Notify(src, xpMsg, 'error')
        return
    end

    TriggerClientEvent('m3_illegaltablet:cl:crewInviteReceived', targetSrc, {
        leaderSrc     = src,
        leaderName    = GetTabletName(src),
        contractLabel = contract.label or 'Contract',
    })

    Notify(src, string.format('Invite sent to player #%04d.', pid), 'inform')
end)

RegisterNetEvent('m3_illegaltablet:sv:kickCrewMember', function(memberName)
    local src = source

    if not activeCrew[src] then return end
    local crew = activeCrew[src]

    local foundIdx = nil
    local foundSrc = nil
    for i, msrc in ipairs(crew.members) do
        if GetTabletName(msrc) == memberName then
            foundIdx = i
            foundSrc = msrc
            break
        end
    end
    if not foundIdx then return end

    table.remove(crew.members, foundIdx)
    playerCrewMap[foundSrc] = nil
    activeContracts[foundSrc] = nil
    if xpSharesMap[src] then xpSharesMap[src][foundSrc] = nil end

    TriggerClientEvent('m3_illegaltablet:cl:kickedFromCrew', foundSrc)

    Notify(src,      string.format('%s was kicked from the crew.', memberName), 'inform')
    Notify(foundSrc, 'You were kicked from the crew by the leader.', 'error')

    BroadcastCrewUpdate(src)
end)

RegisterNetEvent('m3_illegaltablet:sv:respondToCrewInvite', function(leaderSrc, accepted)
    local src = source
    if not accepted then

        pcall(function()
            Notify(leaderSrc, string.format('%s declined the invite.', GetTabletName(src)), 'inform')
        end)
        return
    end

    local contract = activeContracts[leaderSrc]
    if not contract then
        Notify(src, "The leader's contract is no longer active.", 'error')
        return
    end
    if not activeCrew[leaderSrc] then
        activeCrew[leaderSrc] = { members = {} }
    end
    local crew = activeCrew[leaderSrc]

    if (#crew.members + 1) >= MAX_CREW_SIZE then
        Notify(src, 'The crew is full.', 'error')
        return
    end
    if playerCrewMap[src] or activeCrew[src] then
        Notify(src, 'You are already in another crew.', 'error')
        return
    end

    table.insert(crew.members, src)
    playerCrewMap[src] = leaderSrc

    local memberContract = {}
    for k, v in pairs(contract) do memberContract[k] = v end
    memberContract.isCrewMember = true
    activeContracts[src] = memberContract

    Notify(leaderSrc, string.format('%s joined your crew!', GetTabletName(src)), 'success')

    TriggerClientEvent('m3_illegaltablet:cl:startContract', src, memberContract)

    BroadcastCrewUpdate(leaderSrc)
end)
