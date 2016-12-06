service 'rsyslog'

directory '/var/log/swift' do
  action :create
  owner 'syslog'
  group 'adm'
end

template '/etc/rsyslog.d/51-swift.conf' do
  source '51-swift.conf.erb'
  variables(
    swift_services: node['openstack']['swift']['services']
  )
  notifies :restart, 'service[rsyslog]', :delayed
end
