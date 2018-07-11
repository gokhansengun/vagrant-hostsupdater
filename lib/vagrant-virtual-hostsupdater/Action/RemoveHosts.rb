module VagrantPlugins
  module VirtualHostsUpdater
    module Action
      class RemoveHosts
        include VirtualHostsUpdater

        def initialize(app, env)
          @app = app
          @machine = env[:machine]
          @ui = env[:ui]
        end

        def call(env)
          machine_action = env[:machine_action]
          if machine_action != :destroy || !@machine.id
            if machine_action != :suspend || false != @machine.config.virtualhostsupdater.remove_on_suspend
              if machine_action != :halt || false != @machine.config.virtualhostsupdater.remove_on_suspend
                @ui.info "[vagrant-virtual-hostsupdater] Removing hosts"
                removeHostEntries
              else
                @ui.info "[vagrant-virtual-hostsupdater] Removing hosts on suspend disabled"
              end
            end
          end
          @app.call(env)
        end

      end
    end
  end
end
