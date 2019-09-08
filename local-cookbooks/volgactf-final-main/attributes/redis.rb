default['volgactf']['final']['redis']['version'] = '5.0.4'
default['volgactf']['final']['redis']['host'] = nil
default['volgactf']['final']['redis']['port'] = 6379

default['volgactf']['final']['redis']['allow_access_from'] = []

default['volgactf']['final']['redis']['netdata']['enabled'] = false
default['volgactf']['final']['redis']['netdata']['git_repository'] = 'https://github.com/netdata/netdata.git'
default['volgactf']['final']['redis']['netdata']['git_revision'] = 'v1.15.0'
default['volgactf']['final']['redis']['netdata']['stream']['destination'] = nil
default['volgactf']['final']['redis']['netdata']['stream']['name'] = 'redis_server'
