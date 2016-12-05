

module FindMemcached
  if Chef::Config[:solo]
    Chef::Log.warn('This recipe uses search. Chef Solo does not support search.')
  else
    def find_memcached_nodes
      devices = []
      search(:node, "chef_environment:#{node.chef_environment} AND roles:iforms_openstack_swift_storage").sort.each do |result|
        devs = result['ipaddress']
        devices.push(devs)
      end
      count = devices.count
      Chef::Log.info("Memcached servers found => #{count}")
      devices
      end
  end
end
