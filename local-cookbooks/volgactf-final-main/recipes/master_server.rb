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
include_recipe 'graphicsmagick::default'
include_recipe 'graphicsmagick::devel'
include_recipe 'agit::cleanup'

include_recipe 'nodejs::nodejs_from_binary'

opt = node['volgactf']['final']['master']
instance = ::ChefCookbook::Instance::Helper.new(node)
secret = ::ChefCookbook::Secret::Helper.new(node)

if opt['vpn']['enabled']
  vpn_connect 'default' do
    config secret.get('openvpn:config')
    action :create
  end
end

custom_ruby opt['ruby']['version'] do
  user instance.user
  group instance.group
  user_home instance.user_home
  bundler_version opt['ruby']['bundler_version']
  action :install
end

postgresql_client_install 'PostgreSQL Client' do
  version node['volgactf']['final']['postgres']['version']
  action :install
end

apt_repository 'git-core' do
  uri 'ppa:git-core/ppa'
  distribution node['lsb']['codename']
end

git_client 'default' do
  package_action :upgrade
  action :install
end

custom_dns 'default' do
  listen_address '127.0.0.1'
  bind_interfaces true
  records node['volgactf']['final']['dns']['records']
  action :install
end

ngx_http_realip_module 'default'
ngx_http_stub_status_module 'default'
ngx_http_js_module 'default'

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

realip_from = %w[127.0.0.1]
unless opt['vpn']['remote_server'].nil?
  realip_from.push(opt['vpn']['remote_server'])
end

nginx_conf 'realip' do
  cookbook 'volgactf-final-main'
  template 'nginx/realip.conf.erb'
  variables(
    header: 'X-Forwarded-For',
    from: realip_from
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

if opt['repo_mode'] == 'ssh'
  ssh_known_hosts_entry 'github.com'
end

volgactf_final_app 'default' do
  user instance.user
  user_home instance.user_home
  group instance.group

  repo_mode opt['repo_mode']
  run_mode opt['run_mode']

  ruby_version opt['ruby']['version']

  redis_host node['volgactf']['final']['redis']['host']
  redis_port node['volgactf']['final']['redis']['port']
  redis_password secret.get('redis:password', default: nil)

  postgres_host node['volgactf']['final']['postgres']['host']
  postgres_port node['volgactf']['final']['postgres']['port']
  postgres_db node['volgactf']['final']['postgres']['dbname']
  postgres_user node['volgactf']['final']['postgres']['username']
  postgres_password secret.get("postgres:password:#{node['volgactf']['final']['postgres']['username']}")

  fqdn opt['fqdn']
  extra_fqdn opt['extra_fqdn']

  auth_checker_username secret.get('volgactf-final:auth:checker:username', prefix_fqdn: false)
  auth_checker_password secret.get('volgactf-final:auth:checker:password', prefix_fqdn: false)

  auth_master_username secret.get('volgactf-final:auth:master:username', prefix_fqdn: false)
  auth_master_password secret.get('volgactf-final:auth:master:password', prefix_fqdn: false)

  flag_generator_secret secret.get('volgactf-final:flag:generator_secret', prefix_fqdn: false)
  flag_sign_key_private secret.get('volgactf-final:flag:sign_key:private', prefix_fqdn: false)
  flag_sign_key_public secret.get('volgactf-final:flag:sign_key:public', prefix_fqdn: false)

  web_processes opt['web_processes']
  queue_processes opt['queue_processes']
  stream_processes opt['stream_processes']

  log_level opt['log_level']

  config node['volgactf']['final']['config']

  branding_cookbook 'volgactf-final-main'
  branding_root 'branding-sample'
  branding_folders %w[
    images
    js
  ]
  branding_files %w[
    images/volgactf-logo.svg
    js/content.js
    js/logo.js
    js/theme.js
  ]
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

firewall_rule 'http' do
  port 80
  source '0.0.0.0/0'
  protocol :tcp
  command :allow
end
