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
package 'dnsutils'

include_recipe 'ntp::default'
include_recipe 'firewall::default'

opt = node['volgactf']['final']['checker']
instance = ::ChefCookbook::Instance::Helper.new(node)
secret = ::ChefCookbook::Secret::Helper.new(node)

custom_dns 'default' do
  listen_address '0.0.0.0'
  bind_interfaces true
  nameserver '127.0.0.1'
  records node['volgactf']['final']['dns']['records']
  action :install
end

%i[tcp udp].each do |proto|
  firewall_rule "allow access to dnsmasq/#{proto.to_s} from #{opt['network']['subnet']}" do
    port 53
    source opt['network']['subnet']
    protocol proto
    command :allow
  end
end

ngx_http_realip_module 'default'
ngx_http_stub_status_module 'default'

nginx_install 'default' do
  with_ipv6 false
  with_threads false
  with_debug false
  directives(
    main: {
      worker_processes: 'auto'
    },
    events: {
      worker_connections: 1024,
      multi_accept: 'on'
    },
    http: {
      server_tokens: 'off',
      sendfile: 'on',
      tcp_nopush: 'on',
      tcp_nodelay: 'on',
      keepalive_requests: 250,
      keepalive_timeout: 100
    }
  )
  action :run
end

nginx_conf 'gzip' do
  cookbook 'volgactf-final-main'
  template 'nginx/gzip.conf.erb'
  action :create
end

nginx_conf 'resolver' do
  cookbook 'volgactf-final-main'
  template 'nginx/resolver.conf.erb'
  variables(
    resolvers: %w[127.0.0.1],
    resolver_valid: 600,
    resolver_timeout: 10
  )
  action :create
end

stub_status_host = '127.0.0.1'
stub_status_port = 8099

nginx_vhost 'stub_status' do
  cookbook 'volgactf-final-main'
  template 'nginx/stub_status.conf.erb'
  variables(
    host: stub_status_host,
    port: stub_status_port
  )
  action :enable
end

service 'cron' do
  action :nothing
end

execute 'run logrotate hourly' do
  command 'mv /etc/cron.daily/logrotate /etc/cron.hourly/logrotate'
  user instance.root
  group node['root_group']
  notifies :restart, 'service[cron]', :delayed
  action :run
  not_if { ::File.exist?('/etc/cron.hourly/logrotate') }
end

logrotate_app 'nginx' do
  path(lazy { ::File.join(node.run_state['nginx']['log_dir'], '*.log') })
  frequency 'hourly'
  rotate 24 * 7
  options [
    'missingok',
    'compress',
    'delaycompress',
    'notifempty',
    'dateext',
    'dateformat .%Y-%m-%d-%s'
  ]
  postrotate(lazy { "[ ! -f #{node.run_state['nginx']['pid']} ] || kill -USR1 `cat #{node.run_state['nginx']['pid']}`" })
  action :enable
end

docker_service 'default' do
  unless opt['docker']['bip'].nil?
    bip opt['docker']['bip']
  end
  action %i[create start]
end

docker_network opt['network']['name'] do
  subnet opt['network']['subnet']
  gateway opt['network']['gateway']
end

repo_name = opt['image']['repo']

unless opt['image']['registry'].nil?
  registry_addr = "#{opt['image']['registry']}"
  registry_port = secret.get("docker:#{opt['image']['registry']}:port", default: 443, prefix_fqdn: false)
  unless registry_port == 443
    registry_addr += ":#{registry_port}"
  end

  docker_registry opt['image']['registry'] do
    serveraddress "https://#{registry_addr}/"
    username secret.get("docker:#{opt['image']['registry']}:username", prefix_fqdn: false)
    password secret.get("docker:#{opt['image']['registry']}:password", prefix_fqdn: false)
  end

  repo_name = registry_addr + "/#{repo_name}"
end

volgactf_final_checker opt['image']['name'] do
  fqdn opt['fqdn']
  docker_image_repo repo_name
  docker_image_tag opt['image']['tag']
  docker_network_name opt['network']['name']
  docker_network_gateway opt['network']['gateway']
  auth_checker_username secret.get('volgactf-final:auth:checker:username', prefix_fqdn: false)
  auth_checker_password secret.get('volgactf-final:auth:checker:password', prefix_fqdn: false)
  auth_master_username secret.get('volgactf-final:auth:master:username', prefix_fqdn: false)
  auth_master_password secret.get('volgactf-final:auth:master:password', prefix_fqdn: false)
  flag_sign_key_public secret.get('volgactf-final:flag:sign_key:public', prefix_fqdn: false)
  upstream_processes opt['processes']
  environment opt['environment']
  action :install
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

  netdata_python_plugin 'nginx' do
    owner 'netdata'
    group 'netdata'
    global_configuration(
      'retries' => 5,
      'update_every' => 1
    )
    jobs(
      'local' => {
        'url' => "http://#{stub_status_host}:#{stub_status_port}/stub_status"
      }
    )
  end
end

opt['allow_access_from'].each do |ip_addr_block|
  firewall_rule "allow access to checker from #{ip_addr_block}" do
    port 80
    source ip_addr_block
    protocol :tcp
    command :allow
  end
end
