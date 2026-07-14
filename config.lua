Config = {}

Config.TabletKey      = 20
Config.TabletKeyLabel = 'Z'

Config.UseItem   = true
Config.TabletItem = 'illegal_tablet'

Config.ContractRotationInterval = 60

Config.ContractOffersCount = 3

Config.DebugContracts = true

Config.ContractDistribution = {
    interval       = 60,

    minPolice      = 0,

    debugLog       = true,

    acceptCooldown = 1800,
    cooldowns      = {
        robbery_fleeca     = 3600,
        robbery_bobcat     = 5400,
        robbery_truck      = 3600,
        robbery_jewelry    = 2700,
        robbery_humanelabs = 5400,
        vehicle_S          = 2700,
    },

    defaultMaxPerInterval = 3,
    maxPerInterval = {
        vehicle_D = 5, vehicle_C = 4, vehicle_B = 3, vehicle_A = 2, vehicle_S = 1,
        robbery_supermarket = 4, robbery_atm = 4,
        robbery_fleeca = 1, robbery_bobcat = 1, robbery_jewelry = 2, robbery_truck = 1,
        robbery_humanelabs = 1,
        burglary_small_house = 5, burglary_house = 4, burglary_better_house = 3,
        burglary_luxury_house = 2, burglary_warehouse = 2,
    },

    recentWeight = 0.3,
    recentWindow = 1800,

    offerLifetime = 1200,
}

Config.ContractBlipRoute = false

Config.LockpickItem = 'lockpick'

Config.CarHackItem = 'laptop_blue'

Config.HackingDeviceItem = 'hacking_device'

Config.PoliceJob = 'ox_core'

Config.PoliceGroups = { 'police', 'lspd', 'bcso', 'sasp' }

Config.Notify = 'ox_lib'

Config.Dispatch = 'cd_dispatch'

Config.RedXPTiers = {
    { id = 'D', label = 'D Tier', minXP = 0    },
    { id = 'C', label = 'C Tier', minXP = 100  },
    { id = 'B', label = 'B Tier', minXP = 300  },
    { id = 'A', label = 'A Tier', minXP = 700  },
    { id = 'S', label = 'S Tier', minXP = 1500 },
}

Config.GreenXPUnlocks = {
    { minXP = 0,    contracts = { 'burglary_small_house', 'robbery_atm' } },
    { minXP = 100,  contracts = { 'burglary_house' } },
    { minXP = 250,  contracts = { 'robbery_supermarket' } },
    { minXP = 350,  contracts = { 'robbery_jewelry' } },
    { minXP = 500,  contracts = { 'robbery_fleeca', 'robbery_truck' } },
    { minXP = 750,  contracts = { 'burglary_warehouse' } },
    { minXP = 850,  contracts = { 'robbery_humanelabs' } },
    { minXP = 1000, contracts = { 'robbery_bobcat', 'burglary_luxury_house' } },
}

Config.VehicleCategories = {
    D = {
        id           = 'vehicle_D',
        label        = 'Boosting (D)',
        vehicles     = { 'blista', 'futo', 'prairie', 'sentinel', 'stanier', 'stratum', 'issi2' },
        spawnZones   = {
            { coords = vector3(113.0,  -1943.0, 20.6), radius = 150.0 },
            { coords = vector3(-700.0, -935.0,  19.2), radius = 150.0 },
            { coords = vector3(409.0,  -1636.0, 29.3), radius = 150.0 },
            { coords = vector3(-1608.0,-1050.0, 13.2), radius = 150.0 },
        },
        deliveryPoints = {
            { coords = vector4(-67.0, -1754.0, 29.5, 302.0), npcModel = 's_m_m_movalien_01', label = 'Scrapyard' },
            { coords = vector4(879.0, -39.0,  78.0, 357.0), npcModel = 's_m_m_dockwork_01', label = 'Docks'    },
        },
        reward       = { min = 3000,  max = 7000  },
        redXPReward  = { min = 5,     max = 15    },
        timeLimit    = 900,
        needsLocator = false,
        lockpickDiff = 'easy',
        minRedXP     = 0,
        tuning       = 10,
    },
    C = {
        id           = 'vehicle_C',
        label        = 'Boosting (C)',
        vehicles     = { 'buffalo', 'carbonizzare', 'surano', 'feltzer', 'jackal', 'oracle2' },
        spawnZones   = {
            { coords = vector3(-830.498, -114.949, 37.589), radius = 180.0 },
            { coords = vector3(1217.753, -735.278, 61.911), radius = 180.0 },
            { coords = vector3(-348.179, 286.560, 85.010), radius = 180.0 },
        },
        deliveryPoints = {
            { coords = vector4(-67.0,   -1754.0, 29.5, 302.0), npcModel = 's_m_m_movalien_01', label = 'Scrapyard'   },
            { coords = vector4(1757.0,   3286.0, 41.2, 295.0), npcModel = 'g_m_y_azteca_01',   label = 'Sandy Shores' },
        },
        reward       = { min = 8000,  max = 15000 },
        redXPReward  = { min = 10,    max = 25    },
        timeLimit    = 900,
        needsLocator = false,
        lockpickDiff = 'medium',
        minRedXP     = 100,
        tuning       = 50,
    },
    B = {
        id           = 'vehicle_B',
        label        = 'Boosting (B)',
        vehicles     = { 'sultan', 'elegy', 'jester', 'comet2', 'kuruma', 'massacro' },
        spawnZones   = {
            { coords = vector3(-743.0,  -74.0,  37.6), radius = 180.0 },
            { coords = vector3(-185.0,  490.0,  63.8), radius = 180.0 },
            { coords = vector3(-1395.0, -594.0, 30.1), radius = 180.0 },
        },
        deliveryPoints = {
            { coords = vector4(-67.0,  -1754.0, 29.5, 302.0), npcModel = 's_m_m_movalien_01', label = 'Scrapyard'   },
            { coords = vector4(1757.0,  3286.0, 41.2, 295.0), npcModel = 'g_m_y_azteca_01',   label = 'Sandy Shores' },
        },
        reward       = { min = 15000, max = 25000 },
        redXPReward  = { min = 20,    max = 40    },
        timeLimit    = 900,
        needsLocator = false,
        lockpickDiff = 'medium',
        minRedXP     = 300,
        tuning       = 10,
    },
    A = {
        id           = 'vehicle_A',
        label        = 'Boosting (A)',
        vehicles     = { 'adder', 'zentorno', 't20', 'turismor', 'osiris', 'reaper' },
        spawnZones   = {
            { coords = vector3(-737.0,  -74.0,  37.6), radius = 220.0 },
            { coords = vector3(-209.0, -1113.0, 37.2), radius = 220.0 },
            { coords = vector3(-1650.0,-1088.0, 13.1), radius = 220.0 },
        },
        deliveryPoints = {
            { coords = vector4(-67.0,  -1754.0, 29.5, 302.0), npcModel = 's_m_m_movalien_01', label = 'Scrapyard'       },
            { coords = vector4(1757.0,  3286.0, 41.2, 295.0), npcModel = 'g_m_y_azteca_01',   label = 'Sandy Shores' },
        },
        reward       = { min = 35000, max = 65000 },
        redXPReward  = { min = 35,    max = 70    },
        timeLimit    = 3600,
        needsLocator = false,
        lockpickDiff = 'hard',
        minRedXP     = 700,
        tuning       = 25,

        carHack = {
            count               = 10,
            hackDiff            = 'hard',
            cooldown            = 30,
            policeAlertInterval = 10,
            policeAlertRadius   = 200,
            policeAlertDuration = 6,
            globalAlertInterval = 10,
            globalAlertRadius   = 160,
            globalAlertDuration = 8,
        },
    },
    S = {
        id           = 'vehicle_S',
        label        = 'Boosting (S)',
        vehicles     = { 'tyrus', 'xa21', 'fmj', 'le7b', 'reaper' },
        spawnZones   = {
            { coords = vector3(-737.0, -74.0, 37.6), radius = 220.0 },
            { coords = vector3(-1574.292, -1025.149, 13.018), radius = 220.0 },
        },
        deliveryPoints = {
            { coords = vector4(-196.0, -2657.0, 6.0, 0.0), npcModel = 'g_m_y_ballaorig_01', label = 'Airport cargo' },
        },
        reward       = { min = 80000, max = 150000 },
        redXPReward  = { min = 60,    max = 120    },
        timeLimit    = 3600,
        needsLocator = false,
        lockpickDiff = 'hard',
        minRedXP     = 1500,
        tuning       = 10,

        carHack = {
            count               = 20,
            hackDiff            = 'hard',
            cooldown            = 30,
            policeAlertInterval = 10,
            policeAlertRadius   = 180,
            policeAlertDuration = 8,
            globalAlertInterval = 10,
            globalAlertRadius   = 120,
            globalAlertDuration = 8,
        },
    },
}

Config.Robberies = {

    truck = {
        id            = 'robbery_truck',
        label         = 'Gruppe 6 heist',
        blipSprite    = 477,
        blipColor     = 5,
        timeLimit     = 2700,
        greenXPReward = { min = 25, max = 40 },

        truckModel  = 'stockade',
        driverModel = 's_m_m_armoured_01',
        guardModel  = 's_m_m_armoured_02',
        guardArmor  = 100,

        guardWeapon   = 'WEAPON_COMBATPISTOL',
        guardAccuracy = 60,

        spawnPoints = {
            vector4(-622.5,  -857.2, 24.9,  90.0),
            vector4( 120.4, -1730.4, 29.3,  50.0),
            vector4(-1421.0, -276.5, 46.2, 130.0),
            vector4( 1136.0, -469.0, 66.2, 260.0),
            vector4( 431.0,  -650.0, 28.5, 180.0),
        },

        posUpdateInterval = 10,
        circleRadius      = 180.0,

        c4Item      = 'c4',
        c4PlantTime = 6000,
        c4FuseTime  = 5000,

        drillItem       = 'drill',
        drillDurability = 20,

        bagCount     = { min = 3, max = 5 },
        rewardPerBag = { min = 4000, max = 9000 },
        bagTakeTime  = 4000,
        bagProp      = 'prop_money_bag_01',

        bagOffsets   = {
            vec3(-0.45, -1.4, 0.45),
            vec3( 0.45, -1.4, 0.45),
            vec3(-0.45, -2.1, 0.45),
            vec3( 0.45, -2.1, 0.45),
            vec3( 0.0,  -0.8, 0.45),
        },

        wreckCleanupDelay = 600,
    },

    jewelry = {
        id            = 'robbery_jewelry',
        label         = 'Jewelry store robbery',
        location      = vector3(-630.07, -236.33, 38.06),
        blipSprite    = 617,
        blipColor     = 48,
        timeLimit     = 1200,
        wantedLevel   = 3,
        greenXPReward = { min = 15, max = 25 },

        door             = vector4(-631.5823, -237.6707, 38.0752, 304.4332),
        doorFreezeRadius = 1.5,
        drillItem        = 'drill',
        drillDurability  = 20,
        alarmSound       = true,

        smashTime        = 4000,
        casesPerContract = 12,
        requiredCases    = 8,

        itemsPerCase = { min = 5, max = 10 },
        lootTable = {
            { item = 'jewelry',    weight = 45 },
            { item = 'gold_chain', weight = 25 },
            { item = 'watch',      weight = 20 },
            { item = 'diamond',    weight = 10 },
        },

        smashAnim = { dict = 'missheist_jewel', clip = 'smash_case' },

        cases = {
            vector3(-626.8724, -235.4725, 38.0571),
            vector3(-625.7296, -234.6531, 38.0571),
            vector3(-626.9098, -233.0439, 38.0571),
            vector3(-628.0395, -233.8625, 38.0571),
            vector3(-624.6265, -230.9431, 38.0571),
            vector3(-623.0342, -233.1349, 38.0571),
            vector3(-619.2234, -233.6242, 38.0571),
            vector3(-620.2731, -234.3918, 38.0571),
            vector3(-617.6519, -230.5338, 38.0570),
            vector3(-618.3824, -229.5518, 38.0570),
            vector3(-619.7073, -227.7203, 38.0569),
            vector3(-620.4385, -226.6985, 38.0569),
            vector3(-623.9160, -227.1813, 38.0570),
            vector3(-624.8693, -227.8155, 38.0570)
        },
    },

    humanelabs = {
        id            = 'robbery_humanelabs',
        label         = 'Humane Labs',
        location      = vector3(3626.06, 3743.22, 28.69),
        blipSprite    = 499,
        blipColor     = 2,
        timeLimit     = 2700,
        wantedLevel   = 4,
        greenXPReward = { min = 30, max = 45 },

        hackPanel    = vector4(3632.5525, 3747.2852, 28.5157, 300.9033),
        doorHackDiff = 2,

        doors = {
            vector3(3627.9688, 3747.0161, 28.6933),
            vector3(3621.4407, 3751.5833, 28.6934),
        },

        guardModel  = 's_m_m_chemsec_01',
        guardHealth = 400,
        guards = {
            { coords = vector4(3538.41, 3647.17, 27.12,  80.22), weapon = 'WEAPON_SMG',    armor = 100, accuracy = 55 },
            { coords = vector4(3548.88, 3657.83, 27.12, 170.22), weapon = 'WEAPON_SMG',    armor = 100, accuracy = 55 },
            { coords = vector4(3566.14, 3697.27, 27.12, 170.22), weapon = 'WEAPON_PISTOL', armor = 100, accuracy = 50 },
            { coords = vector4(3596.26, 3689.52, 27.82, 145.22), weapon = 'WEAPON_SMG',    armor = 100, accuracy = 55 },
            { coords = vector4(3590.64, 3710.48, 28.69, 170.22), weapon = 'WEAPON_PISTOL', armor = 100, accuracy = 50 },
            { coords = vector4(3611.02, 3722.03, 28.69, 150.22), weapon = 'WEAPON_SMG',    armor = 100, accuracy = 55 },
            { coords = vector4(3620.45, 3743.62, 27.69, 150.22), weapon = 'WEAPON_SMG',    armor = 100, accuracy = 55 },
            { coords = vector4(3609.05, 3740.89, 27.69, 240.22), weapon = 'WEAPON_PISTOL', armor = 100, accuracy = 50 },
        },

        crateModel        = 'sf_prop_sf_crate_animal_01a',
        cratesPerContract = 8,
        searchTime        = 5000,
        itemsPerCrate     = { min = 1, max = 3 },
        lootTable = {
            { item = 'toluen',          weight = 30 },
            { item = 'peroxid',         weight = 25 },
            { item = 'acetone',         weight = 20 },
            { item = 'amoniak',         weight = 15 },
            { item = 'kyselina_sirova', weight = 8  },
            { item = 'cisty_fosfor',    weight = 2  },
        },
        cratePositions = {
            vector4(3536.98, 3663.10, 27.12, 164.0),
            vector4(3560.04, 3671.96, 27.12, 3.0),
            vector4(3560.96, 3681.62, 27.12, 172.0),
            vector4(3551.43, 3655.55, 27.12, 170.0),
            vector4(3568.48, 3694.83, 27.12, 170.0),
            vector4(3597.68, 3686.54, 27.82, 145.0),
            vector4(3592.83, 3708.43, 28.69, 170.0),
            vector4(3613.17, 3718.74, 28.69, 150.0),
            vector4(3626.30, 3734.96, 27.69, 50.0),
            vector4(3611.10, 3746.44, 27.69, 240.0),
        },

        samplePos      = vector4(3558.75, 3669.71, 28.12, 0.0),
        sampleItem     = 'chem_vzorka',
        sampleHackDiff = 3,
        sampleTime     = 8000,

        deliveryNpcs = {
            { coords = vector4(2433.87, 4968.62, 42.35, 44.0),   model = 'g_m_m_chigoon_01'   },
            { coords = vector4(1392.75, 3605.55, 34.98, 200.0),  model = 'g_m_y_salvagoon_01' },
            { coords = vector4(159.98, 6641.92, 31.58, 130.0),   model = 'g_m_y_lost_01'      },
        },
        sampleReward = { min = 15000, max = 25000 },
        deliverTime  = 4000,
    },

    atm = {
        id            = 'robbery_atm',
        label         = 'ATM robbery',

        locations = {
            vector3(5.0257, -919.7172, 29.5599),
            vector3(-27.9546, -724.6412, 44.2290),
            vector3(-866.5861, -187.7157, 37.8351),
            vector3(-1205.7164, -324.7504, 37.8595),
            vector3(-1285.7103, -224.2506, 42.445),
            vector3(-821.6575, -1082.0035, 11.1324),
        },
        blipSprite    = 500,
        blipColor     = 38,
        drillTime     = 18000,
        extractTime   = 6000,

        drillItem       = 'drill',
        drillDurability = 20,
        item          = 'moneybag',
        itemsCount    = { min = 1, max = 2 },
        rewardPerItem = { min = 2000, max = 4000 },
        timeLimit     = 900,
        wantedLevel   = 2,
        greenXPReward = { min = 3,  max = 8   },
    },
    supermarket = {
        id            = 'robbery_supermarket',
        label         = '24/7 store robbery',

        locations = {
            { cashierPos = vector4(2676.61,  3280.18, 54.24, 328.88) },
            { cashierPos = vector4(-2966.25,  391.53, 15.04,  86.90) },
            { cashierPos = vector4(1959.43,  3741.15, 32.34, 300.68) },
            { cashierPos = vector4(1697.53,  4923.12, 42.06, 325.96) },
            { cashierPos = vector4( 372.85,   327.87,103.57, 247.13) },
            { cashierPos = vector4(1134.15,  -983.28, 46.42, 277.94) },
            { cashierPos = vector4(1164.93,  -323.53, 69.21, 103.01) },
            { cashierPos = vector4(-706.09,  -914.60, 19.22,  91.94) },
            { cashierPos = vector4(-1221.29, -908.03, 12.33,  34.85) },
            { cashierPos = vector4(-1486.70, -377.50, 40.16, 138.08) },
            { cashierPos = vector4(  -47.17,-1758.37, 29.42,  50.71) },
            { cashierPos = vector4(   24.14,-1345.66, 28.50, 272.08) },
        },
        blipSprite    = 52,
        blipColor     = 38,
        cashierModel  = 'mp_m_shopkeep_01',
        fearFillTime  = 10.0,
        fearDecayTime = 20.0,
        item          = 'moneybag',
        itemsCount    = { min = 1, max = 1 },
        rewardPerItem = { min = 1500, max = 3000 },
        timeLimit     = 900,
        wantedLevel   = 2,
        greenXPReward = { min = 12, max = 20  },
    },
    fleeca = {
        id          = 'robbery_fleeca',
        label       = 'Fleeca bank robbery',
        blipSprite  = 278,
        blipColor   = 38,
        timeLimit   = 3600,
        wantedLevel = 4,
        greenXPReward = { min = 25, max = 40  },
        vaultHackIterations = 3,
        vaultHackDifficulty = 22,
        barsHackIterations  = 4,
        barsHackDifficulty  = 14,
        moneyPerTrolley  = { min = 3000, max = 7000  },
        money2PerTrolley = { min = 5000, max = 12000 },

        interiorResetDelay = 10,

        locations = {
            {
                coords        = vector3(-2963.4, 481.9, 15.7),
                vaultZonePos  = vector3(-2956.7021, 481.5758, 15.6971),
                vaultDoorPos  = vector3(-2956.68, 481.34, 15.70),
                vaultDoorHash = 4231427725,
                trolleys1 = {
                    { pos = vector3(-2957.3999, 485.5679, 15.15), heading = 180.0 },

                },
                barsZonePos       = vector3(-2956.9011, 483.3231, 15.6753),
                barsObjPos        = vector3(-2956.6506, 484.5703, 15.6753),
                barsLockedHeading = 284.0716,
                trolleys2 = {
                    { pos = vector3(-2953.2229, 483.1495, 15.15), heading = 270.0  },
                },
            },

        },
    },
    bobcat = {
        id            = 'robbery_bobcat',
        label         = 'BobCat Security heist',
        location      = vector3(881.072, -2264.086, 32.442),
        blipSprite    = 150,
        blipColor     = 38,
        timeLimit     = 3600,
        greenXPReward = { min = 30, max = 50  },

        ipl            = 'prologue06_int_np',
        interiorCoords = vector3(883.4142, -2282.372, 31.44168),
        exitCoords     = vector3(881.072, -2262.0, 32.442),

        doorHackPos   = vector4(881.072, -2264.086, 32.442, 169.69),
        doorHackDiff  = 1,

        doorFreezePos = vector3(881.1776, -2264.2673, 32.4416),

        doorBlockerModel = 'prop_sec_gate_01a',
        doorBlockerPos   = vector4(881.072, -2264.5, 32.0, 169.69),

        guardSpawnOutside = vector4(881.0, -2256.0, 32.4, 350.0),
        guardModel  = 's_m_m_security_01',
        guardHealth = 400,
        guards = {

            { coords = vector4(880.910, -2272.435, 32.442, 176.48), weapon = 'WEAPON_PISTOL',       armor = 150, accuracy = 50 },

            { coords = vector4(889.088, -2276.621, 32.442,  97.93), weapon = 'WEAPON_CARBINERIFLE', armor = 250, accuracy = 60 },
            { coords = vector4(893.314, -2275.330, 32.442, 267.47), weapon = 'WEAPON_CARBINERIFLE', armor = 250, accuracy = 60 },
            { coords = vector4(893.356, -2289.170, 32.442, 349.88), weapon = 'WEAPON_CARBINERIFLE', armor = 250, accuracy = 60 },
        },

        vaultPos       = vector4(890.873, -2284.554, 32.441, 101.78),
        vaultC4Item    = 'c4',
        vaultPlantTime = 6000,
        vaultFuseTime  = 3000,

        crateModel   = 'ex_prop_crate_ammo_sc',
        cratePos     = vector4(883.828, -2283.794, 32.442, 71.70),
        crateTime    = 8000,
        crateCount   = { min = 1, max = 3 },
        crateWeapons = {
            'weapon_carbinerifle',
            'weapon_specialcarbine',
            'weapon_assaultrifle',
            'weapon_smg',
            'weapon_bullpuprifle',
            'weapon_sniperrifle',
        },
    },
}

Config.Burglaries = {
    small_house = {
        id            = 'burglary_small_house',
        label         = 'Small house burglary',
        locations     = {
            { exterior = vector4(282.8253, -1899.0708, 27.2675, 233.9036) },
            { exterior = vector4(500.6147, -1697.1704, 29.7893, 312.7709) },
            { exterior = vector4(-1122.8534, -1557.4709, 5.3812, 41.1187) },
        },

        interior = {
            interiorId = 149761,
            entry    = vector4(266.07, -1007.39, -101.96, 4.0),
            exitDoor = vector3(265.9882, -1007.2980, -101.0088),
            boxes    = {
                vector3(258.7203, -996.5426, -98.5675),
                vector3(262.1847, -996.5596, -99.0087),
                vector3(263.0692, -1000.5095, -98.3032),
                vector3(254.5643, -1000.9375, -98.9274),
                vector3(262.5345, -1004.1096, -98.2631),
            },
        },
        searchPoints  = { min = 2, max = 3 },
        searchTime    = 5000,

        searchProps   = {
            'v_ret_gc_box1',
            'bkr_prop_coke_boxeddoll',
            'v_ret_ps_box_01',
            'v_ret_247_cereal1',
            'v_res_tt_pharm1',
        },

        lootTable     = {
            { item = 'house_loot',  weight = 40 },
            { item = 'jewelry',     weight = 18 },
            { item = 'laptop',      weight = 15 },
            { item = 'moneybag',    weight = 12 },
            { item = 'watch',       weight = 8  },
            { item = 'gold_chain',  weight = 5  },
            { item = 'credit_card', weight = 2  },
        },
        itemsPerSearch  = { min = 2, max = 3 },
        rewardPerItem   = { min = 500,  max = 1500 },
        timeLimit       = 900,
        lockpickDiff    = 'easy',
        blipSprite      = 40,
        greenXPReward   = { min = 3,  max = 8  },
    },
    house = {
        id            = 'burglary_house',
        label         = 'House burglary',
        locations     = {
            { exterior = vector4(-704.1223, 588.3888, 142.2801, 172.3178) },
            { exterior = vector4(-459.1534, 537.0770, 121.4602, 171.8612) },
            { exterior = vector4(-600.0609, 807.5119, 191.5249, 8.9928) },
        },

        interior = {
            interiorId  = 148225,
            entry       = vector4(346.54, -1013.21, -99.9, 2.84),
            exitDoor    = vector3(346.54, -1013.21, -99.9),
            boxes    = {
                vector3(339.4569, -995.2816, -98.6582),
                vector3(343.1784, -993.9444, -98.6674),
                vector3(344.6391, -993.6702, -99.1963),
                vector3(339.7719, -1001.2630, -98.4632),
                vector3(347.9719, -1002.5551, -99.1963),
                vector3(350.7665, -999.8038, -98.1083),
                vector3(352.5486, -998.8683, -98.6370),
                vector3(352.2960, -992.8856, -98.5126),
            },
        },
        searchPoints  = { min = 3, max = 4 },
        searchTime    = 6000,
        searchProps   = {
            'v_ret_gc_box1',
            'bkr_prop_coke_boxeddoll',
            'v_ret_ps_box_01',
            'v_ret_247_cereal1',
            'v_res_tt_pharm1',
        },
        lootTable     = {
            { item = 'house_loot',  weight = 30 },
            { item = 'jewelry',     weight = 22 },
            { item = 'laptop',      weight = 16 },
            { item = 'moneybag',    weight = 12 },
            { item = 'watch',       weight = 10 },
            { item = 'gold_chain',  weight = 6  },
            { item = 'diamond',     weight = 3  },
            { item = 'credit_card', weight = 1  },
        },
        itemsPerSearch  = { min = 2, max = 4 },
        rewardPerItem   = { min = 1000, max = 3000 },
        timeLimit       = 900,
        lockpickDiff    = 'medium',
        blipSprite      = 40,
        greenXPReward   = { min = 8,  max = 15  },
    },
    warehouse = {
        id            = 'burglary_warehouse',
        label         = 'Warehouse burglary',
        locations     = {
            { exterior = vector4(850.290, -1995.427, 29.980, 260.80) },
            { exterior = vector4(-711.353, -2526.744, 13.944, 50.84) },
        },

        interior = {
            entry    = vector4(993.562, -3097.988, -38.996, 272.37),
            exitDoor = vector3(992.346,  -3097.893, -38.996),

            allBoxPositions = {
                vector4(1003.628, -3097.427, -39.000, 356.85),
                vector4(1006.134, -3097.047, -39.000, 357.91),
                vector4(1008.459, -3097.200, -39.000, 344.61),
                vector4(1010.894, -3097.167, -39.000, 355.03),
                vector4(1013.154, -3097.088, -39.000, 340.86),
                vector4(1015.646, -3097.316, -39.000, 354.48),
                vector4(1018.225, -3096.967, -39.000, 355.25),
                vector4(1018.359, -3091.694, -39.000, 355.07),
                vector4(1015.835, -3102.687, -39.000, 177.68),
                vector4(1010.942, -3102.728, -39.000, 174.81),
                vector4(1006.051, -3102.686, -39.000, 176.01),
                vector4(1003.613, -3108.403, -39.000, 177.01),
                vector4(1008.649, -3108.014, -39.000, 179.41),
                vector4(1013.363, -3108.127, -39.000, 179.41),
                vector4(1018.179, -3108.229, -39.000, 179.41),
            },
        },
        searchProps   = {
            'prop_boxpile_04a',
            'xm3_prop_xm3_box_pile_tq_01a',
            'prop_boxpile_02b',
            'h4_prop_h4_boxpile_01a',
        },
        maxBoxes      = 8,
        searchTime    = 5000,
        lootTable     = {
            { item = 'warehouse_goods', weight = 32 },
            { item = 'weapon_cache',    weight = 25 },
            { item = 'container_goods', weight = 15 },
            { item = 'ammo_rifle',      weight = 12 },
            { item = 'moneybag',        weight = 8  },
            { item = 'thermite',        weight = 5  },
            { item = 'c4',              weight = 2  },
            { item = 'ammo_pistol',     weight = 1  },
        },
        itemsPerSearch  = { min = 1, max = 4 },
        rewardPerItem   = { min = 2000, max = 5000 },
        timeLimit       = 3600,
        lockpickDiff    = 'medium',
        greenXPReward   = { min = 20, max = 35  },
    },
    luxury_house = {
        id            = 'burglary_luxury_house',
        label         = 'Luxury house burglary',
        locations     = {
            { exterior = vector4(-601.4045, -347.2439, 35.2410, 296.8317) },
            { exterior = vector4(169.8781, -567.4705, 43.8729, 272.4722) },
            { exterior = vector4(-266.0975, -735.2853, 34.4167, 80.7600) }
        },

        interior = {
            interiorId   = 260097,
            entry        = vector4(-1452.2245, -540.4974, 74.0443, 34.8144),
            exitDoor     = vector3(-1452.2245, -540.4974, 74.0443),
            boxes    = {
                vector3(-1458.0358, -528.0757, 74.7708),
                vector3(-1471.3202, -526.1777, 73.4437),
                vector3(-1467.0396, -524.4365, 74.1614),
                vector3(-1469.8375, -539.8167, 74.2644),
                vector3(-1471.5300, -541.8289, 74.2644),
                vector3(-1465.5325, -546.7299, 73.7222),
                vector3(-1466.0948, -552.5399, 73.2441),
                vector3(-1453.3761, -550.2798, 73.2964),
                vector3(-1457.7517, -549.6063, 73.8394),
                vector3(-1448.4600, -549.1999, 72.8436),
            },
        },
        searchPoints  = { min = 4, max = 6 },
        searchTime    = 5000,
        searchProps   = {
            'v_ret_gc_box1',
            'bkr_prop_coke_boxeddoll',
            'v_ret_ps_box_01',
            'v_ret_247_cereal1',
            'v_res_tt_pharm1',
        },
        lootTable     = {
            { item = 'jewelry',     weight = 30 },
            { item = 'diamond',     weight = 22 },
            { item = 'gold_chain',  weight = 18 },
            { item = 'moneybag',    weight = 12 },
            { item = 'watch',       weight = 10 },
            { item = 'laptop',      weight = 4  },
            { item = 'credit_card', weight = 3  },
            { item = 'weapon_cache',weight = 1  },
        },
        itemsPerSearch  = { min = 3, max = 6 },
        rewardPerItem   = { min = 3000, max = 8000 },
        timeLimit       = 3600,
        lockpickDiff    = 'hard',
        blipSprite      = 40,
        greenXPReward   = { min = 20, max = 35  },
    },
}

Config.BurglaryContractItem = 'contract'

Config.BurglaryDeliveryNpcs = {
    { coords = vector4(-1668.071, -230.141, 54.849, 248.17), model = 'g_m_y_ballaeast_01' },
    { coords = vector4(504.753, -2122.943, 5.918, 297.25), model = 'g_m_y_lost_01'      },
    { coords = vector4(-339.556, 76.324, 64.582, 97.37), model = 'g_m_y_famdnf_01'    },
}

Config.RequiredItems = {

    vehicle_D = { 'Lockpick' },
    vehicle_C = { 'Lockpick' },
    vehicle_B = { 'Lockpick' },
    vehicle_A = { 'Lockpick', 'Laptop' },
    vehicle_S = { 'Lockpick', 'Laptop' },

    burglary_small_house  = { 'Lockpick' },
    burglary_house        = { 'Lockpick' },
    burglary_warehouse    = { 'Lockpick' },
    burglary_luxury_house = { 'Lockpick' },

    robbery_atm         = { 'Hacking device / Drill' },
    robbery_jewelry     = { 'Drill' },
    robbery_humanelabs  = { 'Hacking device' },
    robbery_supermarket = { 'Weapon' },
    robbery_fleeca      = { 'Hacking device (x2)' },
    robbery_truck       = { 'C4 / Drill' },
    robbery_bobcat      = { 'Hacking device', 'C4' },
}

Config.DrillMinigame = {
    key       = 38,
    cancelKey = 177,

    model    = 'hei_prop_heist_drill',
    animDict = 'anim@heists@fleeca_bank@drilling',
    animClip = 'drill_straight_idle',

    numDiscs      = 4,
    maxSpeed      = 0.7,
    heatThreshold = 0.4,
    heatUp        = 0.01,
    coolRate      = 0.02,
    maxTemp       = 1.0,
    posRate       = 0.0015,

    shakeCam = true,
    shakeInt = 0.4,
}

Config.Anims = {
    lockpick = { dict = 'anim@heists@ornate_bank@hack',                clip = 'hack_loop'          },
    hack     = { dict = 'amb@world_human_stand_mobile@male@text@base', clip = 'base'               },
    drill    = { dict = 'amb@prop_human_parking_meter@male@idle_a',    clip = 'idle_a'             },
    search   = { dict = 'amb@medic@standing@tendtodead@idle_a',        clip = 'idle_a'             },
    handover = { dict = 'mp_common',                                   clip = 'givetake1_a'        },
}

Config.Items = {
    lockpick        = 'lockpick',
    thermite        = 'thermite',
    jewelry         = 'jewelry',
    moneybag        = 'moneybag',
    weapon_cache    = 'weapon_cache',
    house_loot      = 'house_loot',
    container_goods = 'container_goods',
    warehouse_goods = 'warehouse_goods',
}
