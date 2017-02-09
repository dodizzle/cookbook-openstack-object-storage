%w(swift-account
   swift-account-auditor
   swift-account-reaper
   swift-account-replicator
   swift-container
   swift-container-auditor
   swift-container-replicator
   swift-container-sync
   swift-container-updater
   swift-object
   swift-object-auditor
   swift-object-reconstructor
   swift-object-replicator
   swift-object-updater
   swift-proxy).each do |svc|
  service svc do
    action :start
  end
end
