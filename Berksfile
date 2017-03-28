source "https://supermarket.chef.io"

metadata

cookbook 'memcached', '= 3.0.3'
cookbook "statsd",
  github: "att-cloud/cookbook-statsd"

%w(
  common
  identity
).each do |cookbook|
    cookbook "openstack-#{cookbook}", '= 13.0.0', github: "openstack/cookbook-openstack-#{cookbook}", branch: "stable/mitaka"
end
