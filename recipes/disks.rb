# encoding: UTF-8
#
# Cookbook Name:: openstack-object-storage
# Recipe:: disks
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
# Author: Ron Pedde <ron.pedde@rackspace.com>
# Inspired by: Andi Abes @ Dell

class Chef::Recipe
  include IPUtils
  include DriveUtils
end

platform_options = node['openstack']['object-storage']['platform']

package 'xfsprogs' do
  options platform_options['package_overrides']
  action :upgrade
end

%w(parted util-linux).each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
  end
end

# disk_enum_expr = node['openstack']['object-storage']['disk_enum_expr']
# puts 'disk_enum_expr'
# p disk_enum_expr
# disk_test_filter = node['openstack']['object-storage']['disk_test_filter']

# disks = locate_disks(disk_enum_expr, disk_test_filter)
disks = node['openstack']['object-storage']['swift_disks']
Chef::Log.info("Located disks: #{disks}")

disks.each do |disk|
  puts 'Disk => ' + disk
  openstack_object_storage_disk "/dev/#{disk}" do
    part [{ type: platform_options['disk_format'], size: :remaining }]
    action :ensure_exists
  end
end

disk_ip = node['ipaddress']

openstack_object_storage_mounts '/srv/node' do
  action :ensure_exists
  publish_attributes 'swift/state/devs'
  devices disks.map { |x| "#{x}1" }
  ip disk_ip
  format platform_options['disk_format']
end
