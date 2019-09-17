{
  'net.ipv6.conf.all.disable_ipv6' => 1,
  'net.ipv6.conf.default.disable_ipv6' => 1,
  'net.ipv6.conf.lo.disable_ipv6' => 1
}.each do |sysctl_key, sysctl_value|
  sysctl sysctl_key do
    value sysctl_value
    action :apply
  end
end

apt_update 'default' do
  action :update
  notifies :install, 'build_essential[default]', :immediately
end

build_essential 'default' do
  action :nothing
end

locale 'en' do
  lang 'en_US.utf8'
  lc_all 'en_US.utf8'
  action :update
end

package 'net-tools'

include_recipe 'ntp::default'
include_recipe 'firewall::default'

opt = node['volgactf']['final']['redis']
secret = ::ChefCookbook::Secret::Helper.new(node)

node.default['redisio']['version'] = opt['version']
node.default['redisio']['servers'] = [
  {
    name: nil,
    address: '0.0.0.0',
    port: opt['port'],
    requirepass: secret.get('redis:password', default: nil)
  }
]

include_recipe 'redisio::default'
include_recipe 'redisio::enable'

redis_service_resource = "service[redis@#{opt['port']}]"

sysctl 'net.core.somaxconn' do
  value 512
  action :apply
  notifies :restart, redis_service_resource, :delayed
  only_if { ::File.exist?('/proc/sys/net/core/somaxconn') }
end

sysctl 'vm.overcommit_memory' do
  value 1
  action :apply
  notifies :restart, redis_service_resource, :delayed
end

systemd_unit 'disable-thp.service' do
  content(
    Unit: {
      Description: 'Disable Transparent Huge Pages (THP)'
    },
    Service: {
      Type: 'simple',
      ExecStart: '/bin/sh -c "echo \'never\' > /sys/kernel/mm/transparent_hugepage/enabled && echo \'never\' > /sys/kernel/mm/transparent_hugepage/defrag"'
    },
    Install: {
      WantedBy: 'multi-user.target'
    }
  )
  action %i[create enable start]
  notifies :restart, redis_service_resource, :delayed
end

if opt['netdata']['enabled']
  netdata_install 'default' do
    install_method 'source'
    git_repository opt['netdata']['git_repository']
    git_revision opt['netdata']['git_revision']
    git_source_directory '/opt/netdata'
    autoupdate true
    update true
  end

  netdata_config 'global' do
    owner 'netdata'
    group 'netdata'
    configurations(
      'memory mode' => 'none'
    )
  end

  netdata_stream 'stream' do
    owner 'netdata'
    group 'netdata'
    configurations(
      'enabled' => 'yes',
      'destination' => opt['netdata']['stream']['destination'],
      'api key' => secret.get("netdata:stream:api_key:#{opt['netdata']['stream']['name']}", required: opt['netdata']['enabled'], prefix_fqdn: false)
    )
  end

  redis_plugin_conf = {
    'host' => '127.0.0.1',
    'port' => opt['port'],
  }

  unless secret.get('redis:password', default: nil).nil?
    redis_plugin_conf['pass'] = secret.get('redis:password')
  end

  netdata_python_plugin 'redis' do
    owner 'netdata'
    group 'netdata'
    global_configuration(
      'retries' => 5,
      'update_every' => 1
    )
    jobs(
      'local' => redis_plugin_conf
    )
  end
end

opt['allow_access_from'].each do |ip_addr_block|
  firewall_rule "allow access to redis from #{ip_addr_block}" do
    port opt['port']
    source ip_addr_block
    protocol :tcp
    command :allow
  end
end
