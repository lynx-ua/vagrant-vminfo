require "pathname"

module VagrantVminfo

  def self.vagrant_vminfo_root
    @vagrant_vminfo_root ||= Pathname.new(File.expand_path("../../", __FILE__))
  end

  def self.load_script(script_file_name)
    File.read(expand_script_path(script_file_name))
  end

  def self.load_script_template(script_file_name, options)
    Vagrant::Util::TemplateRenderer.render(expand_script_path(script_file_name), options)
  end

end

require "vagrant-vminfo/plugin"
