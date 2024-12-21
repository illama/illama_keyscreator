fx_version 'cerulean'
game 'gta5'

name 'illama_keyscreator'
description 'Illama Keys Creator est conçu pour gérer les clés des véhicules sur un serveur FiveM sous ESX. Ce script permet une gestion avancée des véhicules en combinant la distribution des clés, la protection contre les vols, et des fonctionnalités intégrées avec Illama Garages Creator. Fonctionnalités Principales'
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
