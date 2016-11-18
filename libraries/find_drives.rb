

module FindDrives
  def find_storage_nodes(role)
    # search chef to get list of storage nodes and
    # return an array of their devices
    devices = []
    search(:node, "chef_environment:#{node.chef_environment} AND roles:#{role}").sort.each do |result|
      devs = result['openstack']['object-storage']['state']['devs']
      devices.push(devs)
    end
    count = devices.count
    Chef::Log.info("Total devices found => #{count}")
    devices
    end
end
