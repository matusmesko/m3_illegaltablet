Locale = {

    tablet_open        = 'You opened the tablet',
    no_contracts       = 'No available contracts',
    contract_accepted  = 'Contract accepted!',
    contract_failed    = 'Contract failed!',
    contract_completed = 'Contract completed! Reward: $%s',
    contract_expired   = 'Time is up! Contract cancelled.',
    already_active     = 'You already have an active contract!',
    need_reputation    = 'Not enough reputation (you need %s)',

    veh_zone_hint      = 'Search the marked area (circle on the map)',
    veh_lockpick_hint  = 'Lockpick the vehicle',
    veh_hack_hint      = 'Hack the tracker',
    veh_deliver_hint   = 'Deliver the vehicle to the marked spot',
    veh_handover_hint  = 'Hand over the vehicle',
    veh_hack_fail      = 'Hack failed!',
    veh_too_damaged    = 'The vehicle is too damaged!',

    rob_break_hint     = 'Break in',
    rob_collect_hint   = 'Collect',
    rob_drill_hint     = 'Drill the vault',
    rob_hack_hint      = 'Hack the system',
    rob_breaking       = 'Breaking in...',
    rob_drilling       = 'Drilling the vault...',
    rob_hacking        = 'Hacking the system...',
    rob_collecting     = 'Collecting...',
    rob_time_left      = 'Time left: %ss',

    burg_lockpick_hint = 'Lockpick the door',
    burg_search_hint   = 'Search',
    burg_searching     = 'Searching...',
    burg_found_items   = 'You found %sx %s',
    burg_nothing       = 'You found nothing.',

    ui_contracts       = 'Available contracts',
    ui_leaderboard     = 'Leaderboard',
    ui_profile         = 'My profile',
    ui_filter          = 'Set contract intake',
    ui_filter_title    = 'Contract filtering',
    ui_filter_sub      = 'Pick the contracts you want to actively receive. Red ones are blocked.',
    ui_active          = 'ACTIVE',
    ui_blocked         = 'BLOCKED',
    ui_reputation      = 'Reputation',
    ui_accept          = 'Accept',
    ui_cancel          = 'Cancel',
    ui_back            = 'Back',
    ui_unlock          = 'Unlock',
    ui_locked          = 'LOCKED',
    ui_call            = 'Call',
    ui_sell            = 'Sell',
    ui_buy             = 'Buy',
    ui_time_left       = 'Time left: %s',
}

function T(key, ...)
    local str = Locale[key]
    if not str then return key end
    if ... then return string.format(str, ...) end
    return str
end
