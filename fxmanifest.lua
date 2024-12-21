fx_version 'cerulean'
game 'gta5'

name 'illama_keyscreator'
description 'Système simple pour des cclés de véhicules pour la version 1.1X.X de ESX.'
author 'Illama'
version '1.0.0'


shared_script '@es_extended/imports.lua'

client_scripts {
    '@es_extended/locale.lua',
    'client.lua'
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    '@es_extended/locale.lua',
    'server.lua'
}

dependency 'ox_target'

ui_page 'html/index.html'

files {
    'html/index.html'
}