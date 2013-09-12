begin
  require "vagrant"
  require Vagrant.source_root.join('plugins/commands/up/start_mixins')
rescue LoadError
  raise "The vagrant-vminfo vagrant plugin must be run with vagrant."
end

# This is a sanity check to make sure no one is attempting to install
# this into an early Vagrant version.
if Vagrant::VERSION < "1.1.0"
  raise "The vagrant-vminfo vagrant plugin is only compatible with Vagrant 1.1+"
end

module VagrantVminfo
  class Plugin < Vagrant.plugin("2")
    name "vagrant-vminfo"
    description <<-DESC
    This plugin provides the 'info' command that will display detailed information about the VM
    DESC

    command("info") do
        InfoCommand
    end
  end

  class InfoCommand < Vagrant.plugin(2, :command)
    include VagrantPlugins::CommandUp::StartMixins

    def execute
        # Not sure if this is the only way to do this?  How else would I get argv?
        argv = parse_options(OptionParser.new)

        with_target_vms(argv) do |vm|
            @env.ui.info("Name: #{vm.name}")
            @env.ui.info("ID: #{vm.id}")
            @env.ui.info("Provider: #{vm.provider}")
            @nic_count = Integer(vm.provider.driver.execute("guestproperty", "get", vm.id, "/VirtualBox/GuestInfo/Net/Count")[/Value: (\d)/, 1])
            (0..(@nic_count-1)).each do |i|
                @nic_ip = vm.provider.driver.execute("guestproperty", "get", vm.id, "/VirtualBox/GuestInfo/Net/#{i}/V4/IP")
                @nic_broadcast = vm.provider.driver.execute("guestproperty", "get", vm.id, "/VirtualBox/GuestInfo/Net/#{i}/V4/Broadcast")
                @nic_netmask = vm.provider.driver.execute("guestproperty", "get", vm.id, "/VirtualBox/GuestInfo/Net/#{i}/V4/Netmask")
                @env.ui.info("NIC #{i} IP: #{@nic_ip}")
                @env.ui.info("NIC #{i} Netmask: #{@nic_netmask}")
            end
        end

    end
  end
end
