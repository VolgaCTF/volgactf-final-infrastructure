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
include_recipe 'latest-nodejs::default'
include_recipe 'graphicsmagick::default'
include_recipe 'graphicsmagick::devel'
include_recipe 'agit::cleanup'

opt = node['volgactf']['final']['master']
instance = ::ChefCookbook::Instance::Helper.new(node)
secret = ::ChefCookbook::Secret::Helper.new(node)

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
  listen '127.0.0.1'
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
  cookbook 'volgactf-final'
  template 'nginx/gzip.conf.erb'
  action :create
end

nginx_conf 'resolver' do
  cookbook 'volgactf-final'
  template 'nginx/resolver.conf.erb'
  variables(
    resolvers: %w[127.0.0.1],
    resolver_valid: 600,
    resolver_timeout: 10
  )
  action :create
end

nginx_conf 'realip' do
  cookbook 'volgactf-final'
  template 'nginx/realip.conf.erb'
  variables(
    header: 'X-Forwarded-For',
    from: %w[127.0.0.1]
  )
  action :create
end

stub_status_host = '127.0.0.1'
stub_status_port = 8099

nginx_vhost 'stub_status' do
  cookbook 'volgactf-final'
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
