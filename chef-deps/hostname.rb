dep 'hostname', :hostname_str, :for => :linux do
  hostname_str.default(shell('hostname -f'))
  def myhostname
    hostname_str.to_s
  end
  met? {
    stored_hostname = '/etc/hostname'.p.read
    !stored_hostname.blank? && myhostname == stored_hostname
  }
  meet {
    sudo "echo #{myhostname} > /etc/hostname"
    sudo "sed -ri 's/^127.0.0.1.*$/127.0.0.1 #{myhostname} #{myhostname.sub(/\..*$/, '')} localhost.localdomain localhost/' /etc/hosts"
    sudo "hostname #{myhostname}"
  }
end
