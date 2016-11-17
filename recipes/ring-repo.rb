# encoding: UTF-8
#
# Cookbook Name:: openstack-object-storage
# Recipe:: ring-repo
#
# Copyright 2012, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# This recipe creates a git ring repository on the management node
# for purposes of ring synchronization
#

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

bash 'rebuild-rings' do
  action :nothing
  cwd '/etc/swift/ring-workspace/rings'
  user node['openstack']['object-storage']['user']
  code <<-EOF
    set -x

    # Should this be done?
    git reset --hard
    git clean -df

    ../generate-rings.sh
    for d in object account container; do swift-ring-builder ${d}.builder; done

    add=0
    if test -n "$(find . -maxdepth 1 -name '*gz' -print -quit)"
    then
        git add *builder *gz
        add=1
    else
        git add *builder
        add=1
    fi
    if [ $add -ne 0 ]
    then
        git commit -m "Autobuild of rings on $(date +%Y%m%d) by Chef" --author="chef <chef@openstack>"
        git push
    fi

  EOF
end

# search for storage nodes
devices = []
storage_nodes = Chef::Search::Query.new.search(:node, "chef_environment:#{node.chef_environment} AND roles:#{node['openstack']['object-storage']['object_server_chef_role']}")
storage_nodes.each do |get_devices|
  p get_devices[:openstack][:object - storage][:state][:devs]
  puts 'DODIZZLE devices count => ' + devices.count
end

%w(account container object).each do |_storage_type|
  puts 'storage_type'
end

# for each storage node get device, ipaddress and port #
# for each device run
# swift-ring-builder container.builder add --region 1 --zone 1 --ip 17.219.201.31 --port 6001 --device sdb1 --weight 100
# then rebuild the ring
# notifies :run, 'bash[rebuild-rings]', :immediate
