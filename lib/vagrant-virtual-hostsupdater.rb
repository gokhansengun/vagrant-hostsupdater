require "vagrant-virtual-hostsupdater/version"
require "vagrant-virtual-hostsupdater/plugin"

module VagrantPlugins
  module VirtualHostsUpdater
    def self.source_root
      @source_root ||= Pathname.new(File.expand_path('../../', __FILE__))
    end
  end
end

