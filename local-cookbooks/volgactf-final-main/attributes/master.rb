default['volgactf']['final']['master']['ruby']['version'] = '2.5.5'
default['volgactf']['final']['master']['ruby']['bundler_version'] = '2.0.1'

default['volgactf']['final']['master']['repo_mode'] = 'https'
default['volgactf']['final']['master']['run_mode'] = 'production'
default['volgactf']['final']['master']['log_level'] = 'INFO'

default['volgactf']['final']['master']['web_processes'] = 2
default['volgactf']['final']['master']['queue_processes'] = 2
default['volgactf']['final']['master']['stream_processes'] = 2

default['volgactf']['final']['master']['fqdn'] = nil
default['volgactf']['final']['master']['extra_fqdn'] = []

default['volgactf']['final']['master']['netdata']['enabled'] = false
default['volgactf']['final']['master']['netdata']['git_repository'] = 'https://github.com/netdata/netdata.git'
default['volgactf']['final']['master']['netdata']['git_revision'] = 'v1.15.0'
default['volgactf']['final']['master']['netdata']['stream']['destination'] = nil
default['volgactf']['final']['master']['netdata']['stream']['name'] = 'master_server'

default['volgactf']['final']['master']['vpn']['enabled'] = false
default['volgactf']['final']['master']['vpn']['remote_server'] = nil
