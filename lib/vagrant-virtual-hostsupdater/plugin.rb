require "vagrant-virtual-hostsupdater/Action/UpdateHosts"
require "vagrant-virtual-hostsupdater/Action/CacheHosts"
require "vagrant-virtual-hostsupdater/Action/RemoveHosts"

module VagrantPlugins
  module VirtualHostsUpdater
    class Plugin < Vagrant.plugin('2')
      name 'VirtualHostsUpdater'
      description <<-DESC
        This plugin manages the /etc/hosts file for the host machine. An entry is
        created for the hostname attribute in the vm.config.
      DESC

      config(:virtualhostsupdater) do
        require_relative 'config'
        Config
      end

      action_hook(:virtualhostsupdater, :machine_action_up) do |hook|
        hook.append(Action::UpdateHosts)
      end

      action_hook(:virtualhostsupdater, :machine_action_provision) do |hook|
        hook.before(Vagrant::Action::Builtin::Provision, Action::UpdateHosts)
      end

      action_hook(:virtualhostsupdater, :machine_action_halt) do |hook|
        hook.append(Action::RemoveHosts)
      end

      action_hook(:virtualhostsupdater, :machine_action_suspend) do |hook|
        hook.append(Action::RemoveHosts)
      end

      action_hook(:virtualhostsupdater, :machine_action_destroy) do |hook|
        hook.prepend(Action::CacheHosts)
      end

      action_hook(:virtualhostsupdater, :machine_action_destroy) do |hook|
        hook.append(Action::RemoveHosts)
      end

      action_hook(:virtualhostsupdater, :machine_action_reload) do |hook|
        hook.prepend(Action::RemoveHosts)
        hook.append(Action::UpdateHosts)
      end

      action_hook(:virtualhostsupdater, :machine_action_resume) do |hook|
        hook.prepend(Action::RemoveHosts)
        hook.append(Action::UpdateHosts)
      end

      command(:virtualhostsupdater) do
        require_relative 'command'
        Command
      end
    end
  end
end
