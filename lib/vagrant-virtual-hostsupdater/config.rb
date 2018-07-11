require "vagrant"

module VagrantPlugins
  module VirtualHostsUpdater
    class Config < Vagrant.plugin("2", :config)
        attr_accessor :aliases
        attr_accessor :id
        attr_accessor :remove_on_suspend
    end
  end
end
