module VagrantPlugins
  module VirtualHostsUpdater
    module Action
      class CacheHosts
        include VirtualHostsUpdater

        def initialize(app, env)
          @app = app
          @machine = env[:machine]
        end

        def call(env)
          cacheHostEntries
          @app.call(env)
        end

      end
    end
  end
end
