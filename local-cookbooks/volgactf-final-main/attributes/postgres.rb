default['volgactf']['final']['postgres']['version'] = '12'
default['volgactf']['final']['postgres']['host'] = nil
default['volgactf']['final']['postgres']['port'] = 5432

default['volgactf']['final']['postgres']['dbname'] = 'volgactf_final'
default['volgactf']['final']['postgres']['dblocale'] = 'en_US.UTF-8'
default['volgactf']['final']['postgres']['username'] = 'volgactf_final'

default['volgactf']['final']['postgres']['allow_access_from'] = []

default['volgactf']['final']['postgres']['netdata']['enabled'] = false
default['volgactf']['final']['postgres']['netdata']['stream']['destination'] = nil
default['volgactf']['final']['postgres']['netdata']['stream']['name'] = 'postgres_server'
