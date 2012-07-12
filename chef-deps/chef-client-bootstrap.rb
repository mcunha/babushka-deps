dep('bootstrap chef client', :chef_version, :hostname_str, :chef_server_url, :init_style){
  chef_version.ask("What version of Chef do you want to install?").default("0.10.10")
  hostname_str.default(shell('hostname -f'))
  chef_server_url.ask("What is the URL of your main chef server?").default("http://chef.example.com:4000")
  init_style.choose({
      'init' => 'Uses init scripts that are included in the chef gem. Logs will be in /var/log/chef. Only usable with debian/ubuntu and red hat family distributions.',
      'runit' => 'Uses runit to set up the service. Logs will be in /etc/sv/chef-client/log/main.',
      'bluepill' => 'Uses bluepill to set up the service.',
      'daemontools' => 'uses daemontools to set up the service. Logs will be in /etc/sv/chef-client/log/main.',
      'bsd' => 'Prints a message with the chef-client command to use in rc.local.'
    }).ask("Which init style would you like to use?").default("init")

  requires [
    'system',
    'hostname'.with(:hostname_str => hostname_str),
    'ruby',
    'chef install dependencies.managed',
    'rubygems',
    'rubygems with no docs',
    'gems.chef'.with(:chef_version => chef_version),
    'chef solo configuration.chef',
    'chef client bootstrap configuration.chef'.with(:chef_server_url => chef_server_url, :init_style => init_style),
    'chef client configuration.chef'.with(:chef_server_url => chef_server_url),
    'bootstrapped chef installed.chef'.with(:chef_version => chef_version, :server_install => false)
  ]
}

dep('chef client registered') {
  requires 'bootstrap chef client'

  met? { false }
  meet {
    !shell("sudo chef-client")
    shell("rm -f /etc/chef/validation.pem")
  }

  setup {
    unmeetable("You must copy /etc/chef/validation.pem to this node from your chef server before registering a node.") unless File.exists?("/etc/chef/validation.pem")
  }
}

dep('chef client bootstrap configuration.chef', :chef_server_url, :init_style) {
  require "rubygems"
  require "json"

  chef_server_url.ask("What is the URL of your main chef server?").default("http://chef.example.com:4000")
  init_style.choose({
      'init' => 'Uses init scripts that are included in the chef gem. Logs will be in /var/log/chef. Only usable with debian/ubuntu and red hat family distributions.',
      'runit' => 'Uses runit to set up the service. Logs will be in /etc/sv/chef-client/log/main.',
      'bluepill' => 'Uses bluepill to set up the service.',
      'daemontools' => 'uses daemontools to set up the service. Logs will be in /etc/sv/chef-client/log/main.',
      'bsd' => 'Prints a message with the chef-client command to use in rc.local.'
    }).ask("Which init style would you like to use?").default("init")

  met?{ File.exists?(chef_json_path) }
  meet {
    json = {
      "chef"=>{
        "server_fqdn"=> chef_server_url,
        "client_interval"=>1800,
        "init_style"=> init_style
      },
      "recipes" => "chef-client::config"
    }.to_json

    shell("cat > '#{chef_json_path}'",
      :input => json,
      :sudo => false
    )
  }
}

dep('chef client configuration.chef', :chef_server_url){
  chef_server_url.ask("What is the URL of your main chef server?").default?("http://chef.example.com:4000")
  met?{ File.exists?("/etc/chef/client.rb") }
  meet {
    shell("mkdir -p /etc/chef", :sudo => true)
    render_erb 'chef/client.rb.erb', :to => '/etc/chef/client.rb', :perms => '755', :sudo => true
  }
}

dep('chef client on startup'){
  met?{
    File.exists?("/etc/init/chef-client.conf") &&
    File.exists?("/etc/init.d/chef-client")
  }

  meet {
    log("Copying start scripts from #{Babushka::GemHelper.gem_path_for("chef")}/distro/debian/etc/")
    shell("cp #{Babushka::GemHelper.gem_path_for("chef")}/distro/debian/etc/init/chef-client.conf /etc/init/chef-client.conf", :sudo => true)
    shell("cp #{Babushka::GemHelper.gem_path_for("chef")}/distro/debian/etc/init/chef-client.conf /etc/init.d/chef-client", :sudo => true)
  }
}