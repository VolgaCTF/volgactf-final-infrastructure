default['volgactf']['final']['checker']['fqdn'] = nil
default['volgactf']['final']['checker']['processes'] = 2
default['volgactf']['final']['checker']['environment'] = {}

default['volgactf']['final']['checker']['allow_access_from'] = []

default['volgactf']['final']['checker']['image']['name'] = nil
default['volgactf']['final']['checker']['image']['registry'] = nil
default['volgactf']['final']['checker']['image']['repo'] = nil
default['volgactf']['final']['checker']['image']['tag'] = 'latest'

default['volgactf']['final']['checker']['network']['name'] = nil
default['volgactf']['final']['checker']['network']['subnet'] = '192.168.163.0/24'
default['volgactf']['final']['checker']['network']['gateway'] = '192.168.163.1'
