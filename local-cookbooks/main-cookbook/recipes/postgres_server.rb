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

opt = node['volgactf']['final']['postgres']
secret = ::ChefCookbook::Secret::Helper.new(node)

postgresql_server_install 'PostgreSQL Server' do
  setup_repo true
  version opt['version']
  password secret.get('postgres:password:postgres', prefix_fqdn: false)
  action %i[install create]
end

service 'postgresql' do
  action :nothing
end

postgres_service_resource = 'service[postgresql]'

postgresql_server_conf 'PostgreSQL Config' do
  version opt['version']
  port opt['port']
  additional_config 'listen_addresses' => '0.0.0.0'
  action :modify
  notifies :reload, postgres_service_resource, :delayed
end

postgresql_user opt['username'] do
  password secret.get("postgres:password:#{opt['username']}", prefix_fqdn: false)
  action :create
end

postgresql_database opt['dbname'] do
  locale opt['dblocale']
  owner opt['username']
  action :create
end

opt['allow_access_from'].each do |ip_addr_block|
  postgresql_access "#{opt['username']} database access from #{ip_addr_block}" do
    access_type 'host'
    access_db opt['dbname']
    access_user opt['username']
    access_addr ip_addr_block
    access_method 'md5'
    action :grant
    notifies :reload, postgres_service_resource, :delayed
  end

  firewall_rule "allow access to postgres from #{ip_addr_block}" do
    port opt['port']
    source ip_addr_block
    protocol :tcp
    command :allow
  end
end
