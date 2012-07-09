dep 'hostname', :hostname_str, :for => :linux do
  def hostname
    hostname_str.default(shell('hostname -f'))
  end
  met? {
    stored_hostname = '/etc/hostname'.p.read
    !stored_hostname.blank? && hostname == stored_hostname
  }
  meet {
    sudo "echo #{hostname_str.default(shell('hostname -f'))} > /etc/hostname"
    sudo "sed -ri 's/^127.0.0.1.*$/127.0.0.1 #{hostname_str} #{hostname_str.sub(/\..*$/, '')} localhost.localdomain localhost/' /etc/hosts"
    sudo "hostname #{hostname_str}"
  }
end
