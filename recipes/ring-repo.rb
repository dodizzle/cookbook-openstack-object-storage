

# This recipe creates a git ring repository on the management node
# for purposes of ring synchronization
#
class Chef::Recipe
  include FindDrives
end
platform_options = node['openstack']['object-storage']['platform']
ring_options = node['openstack']['object-storage']['ring']
git_config_email = "git config user.email 'chef@openstack.org'"
git_config_name = "git config user.name 'Chef'"

platform_options['git_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
  end
end

service 'xinetd' do
  supports status: false, restart: true
  action [:enable, :start]
  only_if { platform_family?('rhel') }
end

execute 'create empty git repo' do
  cwd '/tmp'
  umask 0o22
  command "mkdir $$; cd $$; git init; echo \"backups\" \> .gitignore; #{git_config_email} ; #{git_config_name} ; git add .gitignore; git commit -m 'initial commit' --author='chef <chef@openstack>'; git push file:///#{platform_options['git_dir']}/rings master"
  user node['openstack']['object-storage']['user']
  action :nothing
end

directory 'git-directory' do
  path "#{platform_options['git_dir']}/rings"
  owner node['openstack']['object-storage']['user']
  group node['openstack']['object-storage']['group']
  mode 0o0755
  recursive true
  action :create
end

execute 'initialize git repo' do
  cwd "#{platform_options['git_dir']}/rings"
  umask 0o22
  user node['openstack']['object-storage']['user']
  command 'git init --bare && touch git-daemon-export-ok'
  creates "#{platform_options['git_dir']}/rings/config"
  action :run
  notifies :run, 'execute[create empty git repo]', :immediately
end

case node['platform_family']
when 'rhel'
  service 'git-daemon' do
    service_name platform_options['git_service']
    action [:enable]
  end
when 'debian'
  service 'git-daemon' do
    service_name platform_options['git_service']
    action [:enable, :start]
  end
end

cookbook_file '/etc/default/git-daemon' do
  owner 'root'
  group 'root'
  mode 0o0644
  source 'git-daemon.default'
  action :create
  notifies :restart, 'service[git-daemon]', :immediately
  not_if { platform_family?('rhel') }
end

directory '/etc/swift/ring-workspace' do
  owner node['openstack']['object-storage']['user']
  group node['openstack']['object-storage']['group']
  mode 0o0755
  action :create
end

execute 'checkout-rings' do # ~FC040
  cwd '/etc/swift/ring-workspace'
  command "git clone file://#{platform_options['git_dir']}/rings"
  user node['openstack']['object-storage']['user']
  creates '/etc/swift/ring-workspace/rings'
end

%w(account container object).each do |ring_type|
  part_power = ring_options['part_power']
  min_part_hours = ring_options['min_part_hours']
  replicas = ring_options['replicas']

  Chef::Log.info("Building initial ring #{ring_type} using part_power=#{part_power}, "\
                 "min_part_hours=#{min_part_hours}, replicas=#{replicas}")
  execute "add #{ring_type}.builder" do
    cwd '/etc/swift/ring-workspace/rings'
    command "git add #{ring_type}.builder && #{git_config_email} ; #{git_config_name} && git commit -m 'initial ring builders' --author='chef <chef@openstack>'"
    user node['openstack']['object-storage']['user']
    action :nothing
  end

  execute "create #{ring_type} builder" do
    cwd '/etc/swift/ring-workspace/rings'
    command "swift-ring-builder #{ring_type}.builder create #{part_power} #{replicas} #{min_part_hours}"
    user node['openstack']['object-storage']['user']
    creates "/etc/swift/ring-workspace/rings/#{ring_type}.builder"
    notifies :run, "execute[add #{ring_type}.builder]", :immediate
  end
end

# search for storage nodes
# using the find_drives library
role = node['openstack']['object-storage']['object_server_chef_role']
devices = find_storage_nodes(role)

# build array of ip addresses and disks
drives = []
devices.each do |res|
  res.each do |_k, v|
    device = v['device']
    ip = v['ip']
    Chef::Log.info("device => #{device} & ip => #{ip}")
    drives.push('device' => device, 'ip' => ip)
  end
end

storage_services = { 'object' => '6000', 'container' => '6001', 'account' => '6002' }
storage_services.each do |_k, _v|
  drives.each do |kk, _vv|
    execute 'add disks to ring' do
      Chef::Log.info("Disks being added are: #{kk['device']}@#{kk['ip']}")
      Chef::Log.info("swift-ring-builder #{_k}.builder add --region 1 --zone 1 --ip #{kk['ip']} --port #{_v} --device #{kk['device']} --weight 100")
      command "/usr/bin/swift-ring-builder /etc/swift/ring-workspace/rings/#{_k}.builder add --region 1 --zone 1 --ip #{kk['ip']} --port #{_v} --device #{kk['device']} --weight 100"
      not_if "/usr/bin/swift-ring-builder /etc/swift/ring-workspace/rings/#{_k}.builder | grep #{kk['ip']}| grep #{_v}| grep #{kk['device']} "
    end
  end
end
