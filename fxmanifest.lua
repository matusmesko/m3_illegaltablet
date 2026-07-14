fx_version 'cerulean'
game 'gta5'

name 'm3_illegaltablet'
description 'Illegal Tablet - Crime Contracts System (ox_core)'
version 'Beta 1.0.0'
author 'm3sk1'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/notify/*.lua',
    'bridge/dispatch/*.lua',
    'client/main.lua',
    'client/contracts.lua',
    'client/minigames.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/police/*.lua',
    'server/main.lua',
    'server/contracts.lua',
    'server/crew.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/images/fleeca.png',
    'html/images/shop.png',
    'html/images/allcars.png',
    'html/images/smallhouse.png',
    'html/images/mediumhouse.png',
    'html/images/luxuryhouse.png',
    'html/images/bobcat.png',
    'html/images/atm.png',
    'html/images/warehouse.png',
    'html/images/group6.png',
    'html/images/humanlabs.png',
    'html/images/jewelrystore.png',
    'html/images/lockpick/collar.png',
    'html/images/lockpick/cylinder.png',
    'html/images/lockpick/driver.png',
    'html/images/lockpick/pinTop.png',
    'html/images/lockpick/pinBott.png',
}

lua54 'yes'

dependencies {
    'oxmysql',
    'ox_lib',
    'ox_core',
    'ox_inventory',
    'ox_target',
}
