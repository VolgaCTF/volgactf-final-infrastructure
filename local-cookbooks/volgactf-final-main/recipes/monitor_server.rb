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

opt = node['volgactf']['final']['monitor']

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
    resolvers: %w[1.1.1.1 8.8.8.8 1.0.0.1 8.8.4.4],
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
  user 'root'
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
    'bind to' => opt['netdata']['listen']['host'],
    'default port' => opt['netdata']['listen']['port'],
    'memory mode' => 'ram'
  )
end

service 'netdata' do
  action :nothing
end

secret = ::ChefCookbook::Secret::Helper.new(node)

opt['netdata']['stream'].each do |stream_name, stream_data|
  netdata_stream stream_name do
    config_name secret.get("netdata:stream:api_key:#{stream_name}", prefix_fqdn: false)
    owner 'netdata'
    group 'netdata'
    configurations(
      'enabled' => 'yes',
      'default history' => stream_data.fetch('history', 3600),
      'default memory mode' => 'ram',
      'health enabled by default' => 'auto',
      'allow from' => stream_data['origin']
    )
  end
end

ngx_vars = {
  fqdn: opt['nginx']['fqdn'],
  default_server: opt['nginx']['default_server'],
  access_log_options: opt['nginx']['access_log_options'],
  error_log_options: opt['nginx']['error_log_options'],
  upstream_host: opt['netdata']['listen']['host'],
  upstream_port: opt['netdata']['listen']['port'],
  upstream_keepalive: 64
}

nginx_vhost 'netdata_master' do
  cookbook 'volgactf-final-main'
  template 'nginx/netdata.vhost.conf.erb'
  variables(lazy {
    ngx_vars.merge(
      access_log: ::File.join(
        node.run_state['nginx']['log_dir'],
        'netdata_master-access.log'
      ),
      error_log: ::File.join(
        node.run_state['nginx']['log_dir'],
        'netdata_master-error.log'
      )
    )
  })
  action :enable
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

opt['allow_access_from'].each do |ip_addr_block|
  firewall_rule "allow access to netdata from #{ip_addr_block}" do
    port 80
    source ip_addr_block
    protocol :tcp
    command :allow
  end
end

opt['netdata']['stream'].each do |_, stream_data|
  source_from = "#{stream_data['origin']}/32"
  firewall_rule "allow netdata access from #{source_from}" do
    port opt['netdata']['listen']['port']
    source source_from
    protocol :tcp
    command :allow
  end
end
