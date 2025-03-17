fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'ParadymLabs'
description 'Ped Spawner using ox_lib'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua'
}

client_scripts {
    'client.lua',
    'models.lua',
    'animations.lua'
}

dependencies {
    'ox_lib'
}