# encoding: UTF-8
#
# Cookbook Name:: openstack-object-storage
# Recipe:: identity_registration
#
# Copyright 2013, AT&T Services, Inc.
# Copyright 2013, Craig Tracey <craigtracey@gmail.com>
# Copyright 2013, Opscode, Inc.
# Copyright 2015, IBM Corp.
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

require 'uri'

class ::Chef::Recipe # rubocop:disable Documentation
  include ::Openstack
end

# auth_url = node['openstack']['object-storage']['auth_url']

# define the endpoints to register for the keystone identity service
identity_admin_endpoint = admin_endpoint 'identity'
identity_internal_endpoint = internal_endpoint 'identity'
identity_public_endpoint = public_endpoint 'identity'
auth_url = ::URI.decode identity_admin_endpoint.to_s

token = get_password 'token', 'openstack_identity_bootstrap_token'

admin_api_endpoint = admin_endpoint 'object-storage-api'
internal_api_endpoint = internal_endpoint 'object-storage-api'
public_api_endpoint = public_endpoint 'object-storage-api'

service_pass = get_password 'service', 'openstack-object-storage'
service_tenant_name = node['openstack']['object-storage']['service_tenant_name']
service_user = node['openstack']['object-storage']['service_user']
service_role = node['openstack']['object-storage']['service_role']
region = node['openstack']['object-storage']['region']

#######
identity_admin_endpoint = admin_endpoint 'identity'

auth_url = ::URI.decode identity_admin_endpoint.to_s

interfaces = {
  public: { url: public_endpoint('object-storage-api') },
  internal: { url: internal_endpoint('object-storage-api') },
  admin: { url: admin_endpoint('object-storage-api') }
}
admin_user = node['openstack']['identity']['admin_user']
admin_pass = get_password 'user', admin_user
admin_project = node['openstack']['identity']['admin_project']
admin_domain = node['openstack']['identity']['admin_domain_name']
connection_params = {
  openstack_auth_url:     "#{auth_url}/auth/tokens",
  openstack_username:     admin_user,
  openstack_api_key:      admin_pass,
  openstack_project_name: admin_project,
  openstack_domain_name:    admin_domain
}
=begin
# Register Object Storage Service
openstack_identity_register 'Register Identity Service' do
  auth_uri auth_url
  bootstrap_token token
  service_name 'swift'
  service_type 'object-store'
  service_description 'OpenStack Object Storage'
  action :create_service
end

# Register Object Storage Endpoint
openstack_identity_register 'Register Object Storage Endpoint' do
  auth_uri auth_url
  bootstrap_token token
  service_type 'object-store'
  endpoint_region region
  endpoint_adminurl admin_api_endpoint.to_s
  endpoint_internalurl internal_api_endpoint.to_s
  endpoint_publicurl public_api_endpoint.to_s
  action :create_endpoint
end

# Register Service Tenant
openstack_identity_register 'Register Service Tenant' do
  auth_uri auth_url
  bootstrap_token token
  tenant_name service_tenant_name
  tenant_description 'Service Tenant'
  action :create_tenant
end

# Register Service User
openstack_identity_register "Register #{service_user} User" do
  auth_uri auth_url
  bootstrap_token token
  tenant_name service_tenant_name
  user_name service_user
  user_pass service_pass

  action :create_user
end

## Grant Service role to Service User for Service Tenant ##
openstack_identity_register "Grant '#{service_role}' Role to #{service_user} User for #{service_tenant_name} Tenant" do
  auth_uri auth_url
  bootstrap_token token
  tenant_name service_tenant_name
  user_name service_user
  role_name service_role

  action :grant_role
end
