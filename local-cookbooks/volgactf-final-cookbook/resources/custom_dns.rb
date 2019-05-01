resource_name :custom_dns

property :listen, String, required: true
property :records, Array, required: true
property :nameserver, [String, NilClass], default: nil

default_action :install

action :install do
  localdns_install 'default' do
    listen_address new_resource.listen
    bind_interfaces true
    records new_resource.records
    action :run
  end

  service 'systemd-resolved' do
    action :nothing
  end

  replace_or_add 'disable systemd-resolved' do
    path '/etc/systemd/resolved.conf'
    pattern '#DNSStubListener='
    line 'DNSStubListener=no'
    replace_only true
    action :edit
    notifies :restart, 'service[systemd-resolved]', :immediately
  end

  static_resolv_conf = '/lib/systemd/resolv.conf'
  system_resolv_conf = '/etc/resolv.conf'

  file static_resolv_conf do
    content "nameserver #{new_resource.nameserver.nil? ? new_resource.listen : new_resource.nameserver}"
    mode 0o644
    action :create
  end

  execute "ln -sf #{static_resolv_conf} #{system_resolv_conf}" do
    action :run
    not_if { ::File.realpath(system_resolv_conf) == static_resolv_conf }
  end
end
