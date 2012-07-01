dep('easylodge stack bootstrap') {
  setup {
    unmeetable! "This dep has to be run as root." unless shell('whoami') == 'root'
  }

  requires [
    'benhoskings:system',
    'ivanvanderbyl:ruby.src'.with('1.9.2','p290'),
    'benhoskings:user setup for provisioning',
    'testpilot:core dependencies',
    'testpilot:build essential installed',
    'libv8-dev.managed',
    'benhoskings:core software',
    'benhoskings:passwordless sudo'
  ]
}

dep('easylodge stack') {
  setup {
    unmeetable! "This dep cannot be run as root." if shell('whoami') == 'root'
  }

  requires 'easylodge stack bootstrap'

}