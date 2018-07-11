require 'open3'

module VagrantPlugins
  module VirtualHostsUpdater
    module VirtualHostsUpdater
      if ENV['VAGRANT_HOSTSUPDATER_PATH']
        @@hosts_path = ENV['VAGRANT_HOSTSUPDATER_PATH']
      else
        @@hosts_path = Vagrant::Util::Platform.windows? ? File.expand_path('system32/drivers/etc/hosts', ENV['windir']) : '/etc/hosts'
      end
      @isWindowsHost = Vagrant::Util::Platform.windows?

      # Get a hash of hostnames indexed by ip, e.g. { 'ip1': ['host1'], 'ip2': ['host2', 'host3'] }
      def getHostnames()
        @ui.info '[vagrant-virtual-hostsupdater] retrieving the hostnames'
        hostnames = Hash.new { |h, k| h[k] = [] }

        case @machine.config.virtualhostsupdater.aliases
        when Hash
          # complex definition of aliases for various ips
          @machine.config.virtualhostsupdater.aliases.each do |ip, hosts|
            hostnames[ip] += Array(hosts)
        # else
        #   @ui.error "[vagrant-virtual-hostsupdater] this version only supports the hash format!"
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
        if !File.writable_real?(@@hosts_path)
          @ui.info "[vagrant-virtual-hostsupdater] This operation requires administrative access. You may " +
                       "skip it by manually adding equivalent entries to the hosts file."
          if !sudo(%Q(sh -c 'echo "#{content}" >> #@@hosts_path'))
            @ui.error "[vagrant-virtual-hostsupdater] Failed to add hosts, could not use sudo"
            adviseOnSudo
          end
        elsif Vagrant::Util::Platform.windows?
          require 'tmpdir'
          uuid = @machine.id || @machine.config.virtualhostsupdater.id
          tmpPath = File.join(Dir.tmpdir, 'hosts-' + uuid + '.cmd')
          File.open(tmpPath, "w") do |tmpFile|
          entries.each { |line| tmpFile.puts(">>\"#{@@hosts_path}\" echo #{line}") }
          end
          sudo(tmpPath)
          File.delete(tmpPath)
        else
          content = "\n" + content + "\n"
          hostsFile = File.open(@@hosts_path, "a")
          hostsFile.write(content)
          hostsFile.close()
        end
      end

      def removeFromHosts(options = {})
        uuid = @machine.id || @machine.config.virtualhostsupdater.id
        hashedId = Digest::MD5.hexdigest(uuid)
        if !File.writable_real?(@@hosts_path) || Vagrant::Util::Platform.windows?
          if !sudo(%Q(sed -i -e '/#{hashedId}/ d' #@@hosts_path))
            @ui.error "[vagrant-virtual-hostsupdater] Failed to remove hosts, could not use sudo"
            adviseOnSudo
          end
        else
          hosts = ""
          File.open(@@hosts_path).each do |line|
            hosts << line unless line.include?(hashedId)
          end
          hosts.strip!
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
          require 'win32ole'
          args = command.split(" ")
          command = args.shift
          sh = WIN32OLE.new('Shell.Application')
          sh.ShellExecute(command, args.join(" "), '', 'runas', 0)
        else
          return system("sudo #{command}")
        end
      end

      def adviseOnSudo
        @ui.error "[vagrant-virtual-hostsupdater] Consider adding the following to your sudoers file:"
        @ui.error "[vagrant-virtual-hostsupdater]   https://github.com/cogitatio/vagrant-hostsupdater#suppressing-prompts-for-elevating-privileges"
      end

      def getAwsPublicIp
        return nil if ! Vagrant.has_plugin?("vagrant-aws")
        aws_conf = @machine.config.vm.get_provider_config(:aws)
        return nil if ! aws_conf.is_a?(VagrantPlugins::AWS::Config)
        filters = ( aws_conf.tags || [] ).map {|k,v| sprintf('"Name=tag:%s,Values=%s"', k, v) }.join(' ')
        return nil if filters == ''
        cmd = 'aws ec2 describe-instances --filter '+filters
        stdout, stderr, stat = Open3.capture3(cmd)
        @ui.error sprintf("Failed to execute '%s' : %s", cmd, stderr) if stderr != ''
        return nil if stat.exitstatus != 0
        begin
          return JSON.parse(stdout)["Reservations"].first()["Instances"].first()["PublicIpAddress"]
        rescue => e
          @ui.error sprintf("Failed to get IP from the result of '%s' : %s", cmd, e.message)
          return nil
        end
      end
    end
  end
end
