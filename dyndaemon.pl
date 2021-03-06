#!/usr/bin/perl -w
#
# dyndaemon.pl
#
# $Id: dyndaemon.pl,v 1.20 2006/09/23 22:21:07 tillo Exp $
#
# Martino Dell'Ambrogio <tillo@httpdnet.com>, 2006, GPLv2

use strict;

use Getopt::Long;

use Tie::File;

use Term::ANSIColor;
$Term::ANSIColor::AUTORESET = 1;

# Options initialisation
my %options = (
  'i' => '',
  'd' => '',
  'p' => '',
  'c' => '',
  'h' => ''
);

# Long and short options' descriptions
GetOptions(
  'i|iface=s' => \$options{i},
  'd|debug=i' => \$options{d},
  'p|pretend' => \$options{p},
  'c|nocolor' => \$options{c},
  'h|help'    => \$options{h}
);

# Default or given options
my $IFACE = 'ppp0';
$IFACE = $options{i} if $options{i};

my $PRETEND = 1 if $options{p};

my $DEBUG = 0;
$DEBUG = $options{d} if $options{d};

my $NOCOLOR = 1 if $options{c};

my $HELP = 1 if $options{h};

# Print help if option
print "Options are:

          -i, --iface IF          look for the first v4 address of interface IF instead of ppp0
          -p, --pretend           don't write to files nor execute commands
          -c, --nocolor           don't colorize output
          -d, --debug NUM         output debug messages. NUM can be 1, 2 or 3
          -h, --help              output this little help message about options
" and exit(0) if $HELP;

# chk's fourth hidden field separator
my $CHKHIDDENFIELDSEPARATOR = '#';

# Search the config file
my $CONFFILE = '';

print color 'red' if not $NOCOLOR;
( open( CONFHANDLE,      `pwd |tr -d '\n'` . "/dyndaemon.conf" )                            and $CONFFILE = `pwd |tr -d '\n'` . "/dyndaemon.conf" )
  or ( open( CONFHANDLE, "/etc/dyndaemon.conf" )                                            and $CONFFILE = "/etc/dyndaemon.conf" )
  or ( open( CONFHANDLE, "/usr/local/etc/dyndaemon.conf" )                                  and $CONFFILE = "/usr/local/etc/dyndaemon.conf" )
  or ( open( CONFHANDLE, `pwd |tr -d '\n'` . `dirname $0 |tr -d '\n'` . "/dyndaemon.conf" ) and $CONFFILE = `pwd |tr -d '\n'` . `dirname $0 |tr -d '\n'` . "/dyndaemon.conf" )
  or ( print "Can't open config file!" and die "$!" );

print color 'yellow'                         if not $NOCOLOR;
print "[D2] Found config file ($CONFFILE)\n" if $DEBUG >= 2;

# Config parser initialisations
my $BLOCK   = 0;
my $SUCCESS = 0;

# IP address is taken from ifconfig's output and translated ('.' escaped) to be parsed with RegExp
print color 'red' if not $NOCOLOR;
my $NEWIP = `/sbin/ifconfig $IFACE | grep 'inet ' | head -n 1 | awk '{print \$2}' | sed 's/addr://g' | tr -d '\n'` or print "Can't find an address on interface \"" . $IFACE . "\"!" and die "$!";
my $NEWIPP = $NEWIP;
$NEWIPP =~ s/\./\\\./g;

print color 'green'                          if not $NOCOLOR;
print "[D1] New IP is \"" . $NEWIP . "\".\n" if $DEBUG >= 1;

print color 'blue'                                         if not $NOCOLOR;
print "[D3] New IP to be parsed is \"" . $NEWIPP . "\".\n" if $DEBUG >= 3;

# Config parser and execution
while (<CONFHANDLE>) {

  # Remove newline char at line's end
  chomp;

  # If we are at the beginning of a block, record it
  if ( $_ =~ /^BEGIN$/ ) {
    print color 'blue'                if not $NOCOLOR;
    print "[D3] BEGIN encountered.\n" if $DEBUG >= 3;

    $BLOCK   = 1;
    $SUCCESS = 0;
  }

  # If we are at the end of a block, record it
  elsif ( $_ =~ /^END$/ ) {
    print color 'blue'              if not $NOCOLOR;
    print "[D3] END encountered.\n" if $DEBUG >= 3;

    $BLOCK   = 0;
    $SUCCESS = 0;
  }

  # If we are in a block and it's a chk function we take two parameters, first is without spaces
  elsif ( $_ =~ /^chk (.+?) (.+)$/ && $BLOCK == 1 ) {

    # Parameters initialisation
    my $FILENAME = $1;
    my $STRING   = $2;
    my $STRINGP  = $2;
    my $STRINGPO = $2;
    my $STRINGS  = $2;

    print color 'green'                                                           if not $NOCOLOR;
    print "[D1] Checking \"" . $FILENAME . "\" for string \"" . $STRING . "\".\n" if $DEBUG >= 1;

    # If we have the fourth hidden field separator we split the tirdh field there
    if ( $STRING =~ /^(.+)$CHKHIDDENFIELDSEPARATOR(.+)$/ ) {
      print color 'blue'                                   if not $NOCOLOR;
      print "[D3] chk's tirdh hidden field encountered.\n" if $DEBUG >= 3;

      $STRINGP  = $1;
      $STRINGPO = $1;
      $STRINGS  = $2;
    }

    # Initialisation of the 'line + anything that seems to be an address' to be parsed by RegExp
    $STRINGP =~ s/\{\}/\[0-9\]\{1,3\}\\\.\[0-9\]\{1,3\}\\\.\[0-9\]\{1,3\}\\\.\[0-9\]\{1,3\}/;

    print color 'blue'                                      if not $NOCOLOR;
    print "[D3] Regexp to parse is \"" . $STRINGP . "\".\n" if $DEBUG >= 3;

    # Initialisation of the 'line + new address' to be put instead
    $STRINGS =~ s/\{\}/$NEWIP/;

    print color 'blue'                                 if not $NOCOLOR;
    print "[D3] Substitute is \"" . $STRINGS . "\".\n" if $DEBUG >= 3;

    # We open the file with Tie::File, the one real 'line parsed per line' perl module
    my @filelines = ();
    tie @filelines, 'Tie::File', $FILENAME or warn "Can't open file! ($FILENAME) $!";

    print color 'yellow'        if not $NOCOLOR;
    print "[D2] File opened.\n" if $DEBUG >= 2;

    # We look at every line of the perviously opened file
    my $i = 1;
    for (@filelines) {

      # We don't want newline char
      chomp;

      # If we found the searched line with an address, we use it
      if ( $_ =~ /^$STRINGP$/ ) {
        print color 'yellow'                                           if not $NOCOLOR;
        print "[D2] Found string \"" . $_ . "\" at line " . $i . ".\n" if $DEBUG >= 2;

        # Initialisation of the 'old address' to be parsed by RegExp
        $STRINGPO =~ s/\{\}/\(\.\+\)/;

        print color 'blue'                                                  if not $NOCOLOR;
        print "[D3] Regexp to parse for old IP is \"" . $STRINGPO . "\".\n" if $DEBUG >= 3;

        # Execution of the RegExp
        $_ =~ /$STRINGPO/;
        my $OLDIP = $1;

        # If we already have the new address, nothing is to do
        if ( $OLDIP eq $NEWIP ) {
          print color 'blue'                                       if not $NOCOLOR;
          print "[D3] Not replacing because IP is already good.\n" if $DEBUG >= 3;
        }

        # If the address is old, we replace it with our string and record the replacement
        else {
          $_ = $STRINGS if not $PRETEND;

          print color 'blue'              if not $NOCOLOR;
          print color 'red'               if ( not $NOCOLOR and $PRETEND );
          print "[D3] Replaced string.\n" if $DEBUG >= 3;

          $SUCCESS = 1;
        }
      }
      $i++;
    }

    # We close the file
    untie @filelines;
  }

  # If we are in a block, it's an exe function and we replaced something in the same block, we take the parameter and execute it
  elsif ( $_ =~ /^exe (.+)$/ && $BLOCK == 1 && $SUCCESS == 1 ) {
    print color 'green'                     if not $NOCOLOR;
    print color 'red'                       if ( not $NOCOLOR and $PRETEND );
    print "[D1] Executing \"" . $1 . "\"\n" if $DEBUG >= 1;

    system($1) if not $PRETEND;
  }
}

# Closing the config file
close(CONFHANDLE);

0;
