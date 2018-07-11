module VagrantPlugins
  module VirtualHostsUpdater
    module VirtualHostsUpdater
      @@hosts_path = Vagrant::Util::Platform.windows? ? File.expand_path('system32/drivers/etc/hosts', ENV['windir']) : '/etc/hosts'

      # Get a hash of hostnames indexed by ip, e.g. { 'ip1': ['host1'], 'ip2': ['host2', 'host3'] }
      def getHostnames()
        @ui.info '[vagrant-virtual-hostsupdater] retrieving the hostnames'
        hostnames = Hash.new { |h, k| h[k] = [] }

        case @machine.config.virtualhostsupdater.aliases
        when Hash
          # complex definition of aliases for various ips
          @machine.config.virtualhostsupdater.aliases.each do |ip, hosts|
            hostnames[ip] += Array(hosts)
          end
        end

        return hostnames
      end

      def addHostEntries
        hostnames = getHostnames()
        file = File.open(@@hosts_path, "rb")
        hostsContents = file.read
        uuid = @machine.id
        name = @machine.name
        entries = []
        hostnames.each do |ip, hosts|
          hosts.each do |hostname|
            entryPattern = hostEntryPattern(ip, hostname)

            if hostsContents.match(/#{entryPattern}/)
              @ui.info "[vagrant-virtual-hostsupdater]   found entry for: #{ip} #{hostname}"
            else
              hostEntry = createHostEntry(ip, hostname, name, uuid)
              entries.push(hostEntry)
            end
          end
        end
        addToHosts(entries)
      end

      def cacheHostEntries
        @machine.config.virtualhostsupdater.id = @machine.id
      end

      def removeHostEntries
        if !@machine.id and !@machine.config.virtualhostsupdater.id
          @ui.info "[vagrant-virtual-hostsupdater] No machine id, nothing removed from #@@hosts_path"
          return
        end
        file = File.open(@@hosts_path, "rb")
        hostsContents = file.read
        uuid = @machine.id || @machine.config.virtualhostsupdater.id
        hashedId = Digest::MD5.hexdigest(uuid)
        if hostsContents.match(/#{hashedId}/)
            removeFromHosts
        end
      end

      def host_entry(ip, hostnames, name, uuid = self.uuid)
        %Q(#{ip}  #{hostnames.join(' ')}  #{signature(name, uuid)})
      end

      def createHostEntry(ip, hostname, name, uuid = self.uuid)
        %Q(#{ip}  #{hostname}  #{signature(name, uuid)})
      end

      # Create a regular expression that will match *any* entry describing the
      # given IP/hostname pair. This is intentionally generic in order to
      # recognize entries created by the end user.
      def hostEntryPattern(ip, hostname)
        Regexp.new('^\s*' + ip + '\s+' + hostname + '\s*(#.*)?$')
      end

      def addToHosts(entries)
        return if entries.length == 0
        content = entries.join("\n").strip

        @ui.info "[vagrant-virtual-hostsupdater] Writing the following entries to (#@@hosts_path)"
        @ui.info "[vagrant-virtual-hostsupdater]   " + entries.join("\n[vagrant-virtual-hostsupdater]   ")
        @ui.info "[vagrant-virtual-hostsupdater] This operation requires administrative access. You may " +
          "skip it by manually adding equivalent entries to the hosts file."
        if !File.writable_real?(@@hosts_path)
          if !sudo(%Q(sh -c 'echo "#{content}" >> #@@hosts_path'))
            @ui.error "[vagrant-virtual-hostsupdater] Failed to add hosts, could not use sudo"
            adviseOnSudo
          end
        else
          content = "\n" + content
          hostsFile = File.open(@@hosts_path, "a")
          hostsFile.write(content)
          hostsFile.close()
        end
      end

      def removeFromHosts(options = {})
        uuid = @machine.id || @machine.config.virtualhostsupdater.id
        hashedId = Digest::MD5.hexdigest(uuid)
        if !File.writable_real?(@@hosts_path)
          if !sudo(%Q(sed -i -e '/#{hashedId}/ d' #@@hosts_path))
            @ui.error "[vagrant-virtual-hostsupdater] Failed to remove hosts, could not use sudo"
            adviseOnSudo
          end
        else
          hosts = ""
          File.open(@@hosts_path).each do |line|
            hosts << line unless line.include?(hashedId)
          end
          hostsFile = File.open(@@hosts_path, "w")
          hostsFile.write(hosts)
          hostsFile.close()
        end
      end



      def signature(name, uuid = self.uuid)
        hashedId = Digest::MD5.hexdigest(uuid)
        %Q(# VAGRANT: #{hashedId} (#{name}) / #{uuid})
      end

      def sudo(command)
        return if !command
        if Vagrant::Util::Platform.windows?
          `#{command}`
        else
          return system("sudo #{command}")
        end
      end

      def adviseOnSudo
        @ui.error "[vagrant-virtual-hostsupdater] Consider adding the following to your sudoers file:"
        @ui.error "[vagrant-virtual-hostsupdater]   https://github.com/gokhansengun/vagrant-virtual-hostsupdater#passwordless-sudo"
      end
    end
  end
end
