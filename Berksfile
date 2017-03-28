source "https://supermarket.chef.io"

metadata

cookbook 'memcached', '>= 1.7.2'
cookbook "statsd",
  github: "att-cloud/cookbook-statsd"

%w(
  common
  identity
).each do |cookbook|
  if ENV['ZUUL_CHANGES'] && Dir.exist?("../cookbook-openstack-#{cookbook}")
    cookbook "openstack-#{cookbook}", path: "../cookbook-openstack-#{cookbook}"
  else
    cookbook "openstack-#{cookbook}", '= 13.0.0', github: "openstack/cookbook-openstack-#{cookbook}", branch: "stable/mitaka"
  end
end
