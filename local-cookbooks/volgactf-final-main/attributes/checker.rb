default['volgactf']['final']['checker']['fqdn'] = nil
default['volgactf']['final']['checker']['processes'] = 2
default['volgactf']['final']['checker']['environment'] = {}

default['volgactf']['final']['checker']['allow_access_from'] = []

default['volgactf']['final']['checker']['image']['name'] = nil
default['volgactf']['final']['checker']['image']['registry'] = nil
default['volgactf']['final']['checker']['image']['repo'] = nil
default['volgactf']['final']['checker']['image']['tag'] = 'latest'

default['volgactf']['final']['checker']['docker']['bip'] = nil

default['volgactf']['final']['checker']['network']['name'] = nil
default['volgactf']['final']['checker']['network']['subnet'] = '192.168.163.0/24'
default['volgactf']['final']['checker']['network']['gateway'] = '192.168.163.1'

default['volgactf']['final']['checker']['netdata']['enabled'] = false
default['volgactf']['final']['checker']['netdata']['git_repository'] = 'https://github.com/netdata/netdata.git'
default['volgactf']['final']['checker']['netdata']['git_revision'] = 'v1.15.0'
default['volgactf']['final']['checker']['netdata']['stream']['destination'] = nil
default['volgactf']['final']['checker']['netdata']['stream']['name'] = nil
