fx_version 'cerulean'
game 'gta5'

Author 'Samuel#0008'
Version '1.0.0'

client_scripts { 'client/main.lua', 'client/*.lua', }

shared_scripts { '@ox_lib/init.lua' }

server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua', 'server/*.lua'} 

files { 'configs/*.lua' }

lua54 'yes'