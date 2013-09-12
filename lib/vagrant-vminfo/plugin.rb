begin
  require "vagrant"
  require Vagrant.source_root.join('plugins/commands/up/start_mixins')
rescue LoadError
  raise "The vagrant-vminfo vagrant plugin must be run with vagrant."
end

require "yaml"

# This is a sanity check to make sure no one is attempting to install
# this into an early Vagrant version.
if Vagrant::VERSION < "1.1.0"
  raise "The vagrant-vminfo vagrant plugin is only compatible with Vagrant 1.1+"
end

module VagrantVminfo
  class Plugin < Vagrant.plugin("2")
    name "vagrant-vminfo"
    description <<-DESC
    This plugin provides the 'info' command that will display detailed information about the VM in YAML for easy parsing
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

        info = {}

        with_target_vms(argv) do |vm|
            info["name"] = vm.name.id2name
            info["id"] = vm.id
            info["provider"] = vm.provider_name.id2name
            info["networks"] = []

            @nic_count = Integer(vm.provider.driver.execute("guestproperty", "get", vm.id, "/VirtualBox/GuestInfo/Net/Count")[/Value: (\d)/, 1])
            (0..(@nic_count-1)).each do |i|
                nic = {}

                @nic_ip = vm.provider.driver.execute("guestproperty", "get", vm.id, "/VirtualBox/GuestInfo/Net/#{i}/V4/IP")[/Value: (.*)/, 1]
                @nic_mac = vm.provider.driver.execute("guestproperty", "get", vm.id, "/VirtualBox/GuestInfo/Net/#{i}/MAC")[/Value: (.*)/, 1]
                @nic_broadcast = vm.provider.driver.execute("guestproperty", "get", vm.id, "/VirtualBox/GuestInfo/Net/#{i}/V4/Broadcast")[/Value: (.*)/, 1]
                @nic_netmask = vm.provider.driver.execute("guestproperty", "get", vm.id, "/VirtualBox/GuestInfo/Net/#{i}/V4/Netmask")[/Value: (.*)/, 1]

                # Get the number of this network device based on the mac address
                # TODO: probably just should just get a hash of all of this info somehow, my ruby foo is weak
                @nic_number = vm.provider.driver.execute("showvminfo", vm.id, "--machinereadable")[/\w*(\d)=\"#{@nic_mac}\"/, 1]
                @nic_type = vm.provider.driver.execute("showvminfo", vm.id, "--machinereadable")[/nic#{@nic_number}=\"(.*)\"/, 1]
                
                nic['ip'] = @nic_ip
                nic['mac'] = @nic_mac
                nic['netmask'] = @nic_netmask
                nic['broadcast'] = @nic_broadcast
                nic['type'] = @nic_type

                # Append to the networks array
                info["networks"] << nic
            end
        end
        
        puts info.to_yaml
    end
  end
end
