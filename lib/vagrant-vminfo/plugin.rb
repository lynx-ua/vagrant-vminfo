begin
  require "vagrant"
  require Vagrant.source_root.join('plugins/commands/up/start_mixins')
rescue LoadError
  raise "The vagrant-vminfo vagrant plugin must be run with vagrant."
end

require "yaml"
require "time"

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

    def get_vm_info(vm)
        # Get some provider specific details for vm
        provider = vm.provider_name.id2name
        if provider == 'virtualbox'
            return get_vm_info_virtualbox(vm)
        elsif provider == 'vmware_workstation' or provider == 'vmware_fusion'
            return get_vm_info_vmware(vm)
        end
    end

    def get_vm_info_virtualbox(vm)
        # Get VM info by virtualbox provider
        # All we need is network interfaces details

        networks = []
        begin
            nic_count = vm.provider.driver.execute("guestproperty", "get", vm.id, "/VirtualBox/GuestInfo/Net/Count")[/Value: (\d)/, 1]
        rescue Exception => e
            @logger.warn(e.message)
            nic_count = 0
        else
            nic_count = Integer(nic_count)
        end
        # Check nic_count is not defined in case of VBox Guest Additions not install, or some other issue
        vminfo = vm.provider.driver.execute("showvminfo", vm.id, "--machinereadable")
        if nic_count > 0
            (0..(nic_count-1)).each do |i|
                nic_ip = vm.provider.driver.execute("guestproperty", "get", vm.id, "/VirtualBox/GuestInfo/Net/#{i}/V4/IP")[/Value: (.*)/, 1]
                nic_mac = vm.provider.driver.execute("guestproperty", "get", vm.id, "/VirtualBox/GuestInfo/Net/#{i}/MAC")[/Value: (.*)/, 1]
                nic_broadcast = vm.provider.driver.execute("guestproperty", "get", vm.id, "/VirtualBox/GuestInfo/Net/#{i}/V4/Broadcast")[/Value: (.*)/, 1]
                nic_netmask = vm.provider.driver.execute("guestproperty", "get", vm.id, "/VirtualBox/GuestInfo/Net/#{i}/V4/Netmask")[/Value: (.*)/, 1]
                # Get the number of this network device based on the mac address
                # TODO: probably just should just get a hash of all of this info somehow, my ruby foo is weak
                nic_number = vminfo[/\w*(\d)=\"#{nic_mac}\"/, 1]
                nic_type = vminfo[/nic#{nic_number}=\"(.*)\"/, 1]
                networks << {'ip' => nic_ip,
                             'mac' => nic_mac,
                             'netmask' => nic_netmask,
                             'broadcast' => nic_broadcast,
                             'type' => nic_type}
            end
        end
        # If VM is running - VMStateChangeTime is actually it's launch time 
        state_change_time = vminfo[/VMStateChangeTime=\"(.*)\"/, 1]
        return {"launch_time" => Time.parse(state_change_time).strftime("%Y-%m-%d %H:%M:%S"),
                "networks" => networks}

    end

    def get_vm_info_vmware(vm)
        # Get VM info by virtualbox provider
        # We can get some network interfaces details and current IP address

        # Collect details for all the network interfaces
        nics = {}
        vm.provider.driver.send(:read_vmx_data).each do |key, val|
            key1, key2 = key.split('.')
            m = /^ethernet\d+$/.match(key1)
            if m
                if !nics.include?(m[0])
                    nics[m[0]] = {}
                end
                nics[m[0]][key2] = val
            end
        end

        # Check and normalize collected network information
        networks = []
        nics.values.each do |nic|
            nic_type = nic['connectiontype']
            nic_addresstype = nic['addresstype']
            nic_mac = nic_addresstype == 'generated' ? nic['generatedaddress'] : nic['address']
            #TODO: For now I don't know simple way to retrieve these details
            #nic_ip = nil
            #nic_netmask = nil
            #nic_broadcast = nil

            networks << {#'ip' => nic_ip,
                         'mac' => nic_mac,
                         #'netmask' => nic_netmask,
                         #'broadcast' => nic_broadcast,
                         'type' => nic_type}
        end

        # We can try to get IP address for VM but can not assign it to any network interface
        ip = nil
        begin
            resp =  vm.provider.driver.send(:vmrun, *['getGuestIPAddress', vm.id])
        rescue Exception => e
            @logger.warn(e.message)
        else
            m = /(?<ip>\d{1,3}\.\d{1,3}.\d{1,3}\.\d{1,3})/.match(resp.stdout)
            ip = (resp.exit_code == 0 and m) ? m['ip'] : nil
        end

        return {'ip' => ip,
                'networks' => networks }
    end

    def execute
        # Not sure if this is the only way to do this?  How else would I get argv?
        argv = parse_options(OptionParser.new)

        info = {}

        with_target_vms(argv) do |vm|
            info["name"] = vm.name.id2name
            info["status"] = vm.state.id.id2name

            # Check if vm is running - try to get some provider specific details
            if vm.state.id == :running
                info["id"] = vm.id
                info["provider"] = vm.provider_name.id2name
                info.merge!(get_vm_info(vm))
            end
        end
        puts info.to_yaml
    end
  end
end
