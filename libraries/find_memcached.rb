

module FindMemcached
  if Chef::Config[:solo]
    Chef::Log.warn('This recipe uses search. Chef Solo does not support search.')
  else
    def find_memcached_nodes
      devices = []
      search(:node, "chef_environment:#{node.chef_environment} AND roles:iforms_openstack_swift_storage").sort.each do |result|
        ips = result['ipaddress']
        port = result['memcached']['port']
        instance = ips.to_s + ':' + port.to_s
        devices.push(instance)
      end
      count = devices.count
      Chef::Log.info("Memcached servers found => #{count}")
      devices
      end
  end
end
