Capistrano::Configuration.instance.load do
  set(:cookbook_path, 'chef/cookbooks') unless exists?(:cookbook_path)
  set(:node_json_path, 'chef/node.json') unless exists?(:node_json_path)

  namespace :chef do
    desc "Bootstrap a fresh server with chef"
    task :bootstrap do
      chef.ssh.transfer_keys
      run "curl -fsSL opscode.com/chef/install.sh | bash"
      chef.default
    end

    desc "Do a chef-solo run on the remote servers"
    task :default do
      chef.setup
      run "#{sudo} chef-solo -j node.json -r chef-solo.tar.gz"
    end

    task :setup do
      chef.cookbooks
      chef.node
    end

    task :cookbooks do
      system "tar -zcf chef-solo.tar.gz #{cookbook_path}"
      upload "chef-solo.tar.gz", "chef-solo.tar.gz"
      system "rm chef-solo.tar.gz"
    end

    task :node do
      upload node_json_path, "node.json"
    end

    namespace :ssh do
      desc "Transfer SSH keys to the remote server"
      task :transfer_keys do
        public_key = ssh_authorized_pub_file rescue false
        known_hosts = ssh_known_hosts rescue false
        if public_key || known_hosts
          run "mkdir -p ~/.ssh"
          put(File.read(public_key), ".ssh/authorized_keys", :mode => "0600") if public_key
          put(known_hosts, ".ssh/known_hosts", :mode => "0600") if known_hosts
        end
      end

      desc "Set any defined SSH options"
      task :set_options do
        ssh_options[:paranoid] = ssh_options_paranoid rescue nil
        ssh_options[:keys] = ssh_options_keys rescue nil
        ssh_options[:forward_agent] = ssh_options_forward_agent rescue nil
        ssh_options[:username] = ssh_options_username rescue user rescue nil
        ssh_options[:port] = ssh_options_port rescue nil
      end
    end

    before "ssh:transfer_keys", "ssh:set_options"
  end
end
