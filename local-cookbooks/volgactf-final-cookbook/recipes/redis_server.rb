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
    requirepass: secret.get('redis:password', default: nil, prefix_fqdn: false)
  }
]

include_recipe 'redisio::default'
include_recipe 'redisio::enable'

redis_service_resource = "service[redis@#{opt['port']}]"

sysctl 'net.core.somaxconn' do
  value 512
  action :apply
  notifies :restart, redis_service_resource, :delayed
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

opt['allow_access_from'].each do |ip_addr_block|
  firewall_rule "allow access to redis from #{ip_addr_block}" do
    port opt['port']
    source ip_addr_block
    protocol :tcp
    command :allow
  end
end
