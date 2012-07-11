dep 'chef user' do
  requires [
    'system',
    'admins can sudo',
    'user exists with password',
    'can sudo without password',
    'passwordless ssh logins',
    'secured system'
  ]
end

dep 'can sudo without password', :username do
  username.default!('chef')
  requires 'sudo.bin'
  met? { !sudo('cat /etc/sudoers').split("\n").grep(/(^#{username})?.(NOPASSWD:ALL)/).empty? }
  meet { append_to_file "#{username}  ALL=(ALL) NOPASSWD:ALL", '/etc/sudoers', :sudo => true }
end

dep 'passwordless ssh logins', :username, :your_ssh_public_key do
  username.default!('chef') 
  def ssh_dir
    "/home/#{username}" / '.ssh'
  end
  def group
    shell "id -gn #{username}"
  end

  requires 'public key'

  met? {
    sudo "mkdir -p '#{ssh_dir}'"
    shell("touch '#{ssh_dir / 'authorized_keys'}'")
    sudo "grep '#{your_ssh_public_key}' '#{ssh_dir / 'authorized_keys'}'"
  }
  before {
    sudo "mkdir -p '#{ssh_dir}'"
    sudo "chmod 700 '#{ssh_dir}'"
  }
  meet {
    append_to_file your_ssh_public_key, (ssh_dir / 'authorized_keys'), :sudo => true
  }
  after {
    sudo "chown -R #{username}:#{group} '#{ssh_dir}'"
    sudo "chmod 600 #{(ssh_dir / 'authorized_keys')}"
  }
end

dep 'public key', :username do
  username.default!('deploy')
  def ssh_dir
    "/home/#{username}" / '.ssh'
  end
  def present_in_file? (filename)
    catres = sudo("cat #{filename}")
    if catres.nil?; then return false; end
    !catres.split("\n").grep(/^ssh-rsa/).empty?
  end
  met? { present_in_file?("#{ssh_dir}/id_rsa.pub") }
  meet {
    log shell("ssh-keygen -t rsa -f #{ssh_dir}/id_rsa -N ''", :sudo => true, :as => username )
  }
end

dep 'dot files', :github_user, :dot_files_repo do
  github_user.default!('benhoskings') 
  dot_files_repo.default!('dot-files') 
  requires 'user exists', 'git', 'curl.bin', 'git-smart.gem'
  met? { File.exists?(ENV['HOME'] / ".dot-files/.git") }
  meet { shell %Q{curl -L "http://github.com/#{github_user}/#{dot_files_repo}/raw/master/clone_and_link.sh" | bash} }
end

dep 'user exists with password', :username, :password do
  username.default!('chef') 
  requires 'user exists'.with(:username => username)
  on :linux do
    met? { shell('sudo cat /etc/shadow')[/^#{username}:[^\*!]/] }
    meet {
      sudo "echo '#{username}:#{password}' | chpasswd"
    }
  end
end

dep 'user exists', :username do
  username.default!('deploy')
  def home_dir_base
      username['.'] ? '/srv/http' : '/home'
  end
  setup {
    unmeetable("You cannot call your user 'chef' - this name is reserved for chef") if username == "chef"
  }
  on :linux do
    met? { '/etc/passwd'.p.grep(/^#{username}:/) }
    meet {
      sudo "mkdir -p #{home_dir_base}" and
      sudo "useradd -m -s /bin/bash -b #{home_dir_base} -G admin #{username}" and
      sudo "chmod 701 #{home_dir_base / username}"
    }
  end
end
