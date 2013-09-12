# -*- encoding: utf-8 -*-
require File.expand_path('../lib/vagrant-vminfo/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Lin Salisbury"]
  gem.email         = ["lin.salisbury@gmail.com"]
  gem.description   = %q{Plugin to get detailed VM info from Vagrant}
  gem.summary       = %q{Gets detailed information about the VM, including network interfaes}
  gem.homepage      = "https://github.com/d3vz3r0/vagrant-vminfo"

  # The following block of code determines the files that should be included
  # in the gem. It does this by reading all the files in the directory where
  # this gemspec is, and parsing out the ignored files from the gitignore.
  # Note that the entire gitignore(5) syntax is not supported, specifically
  # the "!" syntax, but it should mostly work correctly.
  root_path      = File.dirname(__FILE__)
  all_files      = Dir.chdir(root_path) { Dir.glob("**/{*,.*}") }
  all_files.reject! { |file| [".", ".."].include?(File.basename(file)) }
  gitignore_path = File.join(root_path, ".gitignore")
  gitignore      = File.readlines(gitignore_path)
  gitignore.map!    { |line| line.chomp.strip }
  gitignore.reject! { |line| line.empty? || line =~ /^(#|!)/ }

  unignored_files = all_files.reject do |file|
    # Ignore any directories, the gemspec only cares about files
    next true if File.directory?(file)

    # Ignore any paths that match anything in the gitignore. We do
    # two tests here:
    #
    #   - First, test to see if the entire path matches the gitignore.
    #   - Second, match if the basename does, this makes it so that things
    #     like '.DS_Store' will match sub-directories too (same behavior
    #     as git).
    #
    gitignore.any? do |ignore|
      File.fnmatch(ignore, file, File::FNM_PATHNAME) ||
        File.fnmatch(ignore, File.basename(file), File::FNM_PATHNAME)
    end
  end

  gem.files         = unignored_files
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "vagrant-vminfo"
  gem.require_paths = ["lib"]
  gem.version       = VagrantVminfo::VERSION

  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec-core", "~> 2.12.2"
  gem.add_development_dependency "rspec-expectations", "~> 2.12.1"
  gem.add_development_dependency "rspec-mocks", "~> 2.12.1"
end
