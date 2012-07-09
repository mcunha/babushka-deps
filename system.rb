def ssh_conf_path file
  "/etc#{'/ssh' if Babushka.host.linux?}/#{file}_config"
end

dep 'system', :hostname_str do
  requires 'hostname'.with(hostname_str), 'tmp cleaning grace period', 'core software'
end

dep 'secured system' do
  requires 'secured ssh logins', 'lax host key checking', 'admins can sudo'#, 'set.locale'
  setup {
    unmeetable "This dep has to be run as root." unless shell('whoami') == 'root'
  }
end

dep 'tmp cleaning grace period', :for => :ubuntu do
  met? { !"/etc/default/rcS".p.grep(/^[^#]*TMPTIME=0/) }
  meet { change_line "TMPTIME=0", "TMPTIME=30", "/etc/default/rcS" }
end

dep 'secured ssh logins' do
  requires ['sshd.managed'] #, 'passwordless ssh logins']
  met? {
    # -o NumberOfPasswordPrompts=0
    output = raw_shell('ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no nonexistentuser@localhost').stderr
    if output.downcase['connection refused']
      log_ok "sshd doesn't seem to be running."
    elsif (auth_methods = output.scan(/Permission denied \((.*)\)\./).join.split(/[^a-z]+/)).empty?
      log_error "sshd returned unexpected output."
    else
      (auth_methods == %w[publickey]).tap {|result|
        log "sshd #{'only ' if result}accepts #{auth_methods.to_list} logins.", :as => (result ? :ok : :error)
      }
    end
  }
  meet {
    shell("sed -i '' -e 's/^PasswordAuthentication\\s+\\w+\\b//' '/etc/ssh/sshd_config'")
    shell("sed -i '' -e 's/^ChallengeResponseAuthentication\\s+\\w+\\b//' '/etc/ssh/sshd_config'")
    '/etc/ssh/sshd_config'.p.append("PasswordAuthentication no")
    '/etc/ssh/sshd_config'.p.append("ChallengeResponseAuthentication no")
  }
  after { sudo "/etc/init.d/ssh restart" }
end

dep 'lax host key checking', :ssh do
  ssh.default!('ssh')
  met? { ssh_conf_path(ssh).p.grep /^StrictHostKeyChecking[ \t]+no/ }
  meet { 
    shell("sed -i '' -e 's/^StrictHostKeyChecking\\s+\\w+\\b//' #{ssh_conf_path(ssh)}") 
    ssh_conf_path(ssh).p.append("StrictHostKeyChecking no")
  }
end
