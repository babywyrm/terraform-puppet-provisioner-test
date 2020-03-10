node default {
  notify { "Hello world from ${facts['hostname']}!": }
}

node 'puppet.agent' { # Applies only to mentioned node; if nothing mentioned, applies to all.
file { '/tmp/PUPPETDEATH_LOL': # Resource type file

## ensure => 'directory', # Create as a directory
 ensure => 'present', # Make sure it exists
 owner => 'root', # Ownership
 group => 'root', # Group Name
 mode => '0755', # Directory permissions
 content => "This File is created by the Puppet Master, Obvi"

}
}
