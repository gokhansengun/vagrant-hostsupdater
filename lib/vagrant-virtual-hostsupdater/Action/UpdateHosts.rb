require_relative "../VirtualHostsUpdater"
module VagrantPlugins
  module VirtualHostsUpdater
    module Action
      class UpdateHosts
        include VirtualHostsUpdater


        def initialize(app, env)
          @app = app
          @machine = env[:machine]
          @ui = env[:ui]
        end

        def call(env)
          @ui.info "[vagrant-virtual-hostsupdater] Checking for host entries"
          addHostEntries()
          @app.call(env)
        end

      end
    end
  end
end