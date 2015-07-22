#!/usr/bin/perl -w
#
# dyndaemon.pl
#
# Martino Dell'Ambrogio <tillo@httpdnet.com>, 2006, GPLv2

use Getopt::Long;
use Tie::File;

# Options initialisation
%options=();
$options{i} = $options{d} = $options{n} = $options{h} = '';

# Long and short options' descriptions
GetOptions('i|iface=s' => \$options{i}, 'd|debug=i' => \$options{d}, 'n|donothing' => \$options{n}, 'h|help' => \$options{h});

# Default or given options
$IFACE=$options{i} if $options{i} or $IFACE="ppp0";
$DEBUG=$options{d} if $options{d} or $DEBUG="0";
$DONTDOANYTHING=1 if $options{n};

# Print help if option
print "Arguments are:

        -i, --iface IF          It makes dyndaemon look for the first v4 address of interface IF instead of ppp0
        -n, --donothing         It makes dyndaemon not to write to files nor execute commands
        -d, --debug NUM         It makes dyndaemon output debug messages. NUM can be 1, 2 or 3
        -h, --help              It makes dyndaemon output a little help message about arguments\n" and exit(0) if $options{h};

# chk's fourth hidden field separator
$CHKHIDDENFIELDSEPARATOR = '#';

# Search the config file
( open(CONFHANDLE, "/etc/dyndaemon.conf") and $CONFFILE = "/etc/dyndaemon.conf" )
or
( open(CONFHANDLE, "/usr/local/etc/dyndaemon.conf") and $CONFFILE = "/usr/local/etc/dyndaemon.conf" )
or
( open(CONFHANDLE, "dyndaemon.conf") and $CONFFILE = "dyndaemon.conf" )
or
( open(CONFHANDLE, `dirname $0 |tr -d '\n'`."/dyndaemon.conf") and $CONFFILE = `dirname $0 |tr -d '\n'`."/dyndaemon.conf" )
or
die "Can't open config file!";

print "[D2] Found config file ($CONFFILE)\n" if $DEBUG>=2;

# Config parser initialisations
$BLOCK=0;
$SUCCESS=0;

# IP address is taken from ifconfig's output and translated ('.' escaped) to be parsed with RegExp
$NEWIPP=$NEWIP=`/sbin/ifconfig $IFACE | grep 'inet ' | head -n 1 | awk '{print \$2}' | sed 's/addr://g' | tr -d '\n'` or die "Can't find interface \"".$IFACE."\".\n";
$NEWIPP=~s/\./\\\./g;

print "[D1] New IP is \"".$NEWIP."\".\n" if $DEBUG>=1;

print "[D3] New IP to be parsed is \"".$NEWIPP."\".\n" if $DEBUG>=3;

# Config parser and execution
while(<CONFHANDLE>) {

  # Remove newline char at line's end
  chomp;

  # If we are at the beginning of a block, record it
  if ($_ =~ /^BEGIN$/) {

    print "[D3] BEGIN encountered.\n" if $DEBUG>=3;

    $BLOCK=1;
    $SUCCESS=0;
  
  }
  # If we are at the end of a block, record it
  elsif ($_ =~ /^END$/) {

    print "[D3] END encountered.\n" if $DEBUG>=3;
  
    $BLOCK=0;
    $SUCCESS=0;
    
  }
  # If we are in a block and it's a chk function we take two parameters, first is without spaces
  elsif ($_ =~ /^chk (.+?) (.+)$/ && $BLOCK == 1) {

    # Parameters initialisation
    $FILENAME=$1;
    $STRING=$2;
    print "[D1] Checking \"".$FILENAME."\" for string \"".$STRING."\".\n" if $DEBUG>=1;

    # If we have the fourth hidden field separator we split the tirdh field there
    if ($2 =~ /^(.+)$CHKHIDDENFIELDSEPARATOR(.+)$/) {
      print "[D3] chk's tirdh hidden field encountered.\n" if $DEBUG>=3;
      $STRINGPO=$STRINGP=$1;
      $STRINGS=$2;
    }
    # We make sure that the separator is not there
    elsif ($2 =~ /^([^$CHKHIDDENFIELDSEPARATOR]+)$/) {
      $STRINGPO=$STRINGS=$STRINGP=$1;
    }

    # Initialisation of the 'line + anything that seems to be an address' to be parsed by RegExp
    $STRINGP=~s/\{\}/\[0-9\]\{1,3\}\\\.\[0-9\]\{1,3\}\\\.\[0-9\]\{1,3\}\\\.\[0-9\]\{1,3\}/;
    print "[D3] Regexp to parse is \"".$STRINGP."\".\n" if $DEBUG>=3;
    
    # Initialisation of the 'line + new address' to be put instead
    $STRINGS=~s/\{\}/$NEWIP/;
    print "[D3] Substitute is \"".$STRINGS."\".\n" if $DEBUG>=3;

    # We open the file with Tie::File, the one real 'line parsed per line' perl module
    tie @filelines, 'Tie::File', $FILENAME or die "Can't open file! ($FILENAME)";
    print "[D2] File opened.\n" if $DEBUG>=2;

    # We look at every line of the perviously opened file
    $i=1;
    for(@filelines) {
      
      # We don't want newline char
      chomp;

      # If we found the searched line with an address, we use it
      if ($_ =~ /^$STRINGP$/) {

        print "[D2] Found string \"".$_."\" at line ".$i.".\n" if $DEBUG>=2;

        # Initialisation of the 'old address' to be parsed by RegExp
        $STRINGPO=~s/\{\}/\(\.\+\)/;
        print "[D3] Regexp to parse for old IP is \"".$STRINGPO."\".\n" if $DEBUG>=3;

        # Execution of the RegExp
        $_=~/$STRINGPO/;
        $OLDIP=$1;

        # If we already have the new address, nothing is to do
        if ($OLDIP eq $NEWIP) {
        
          print "[D3] Not replacing because IP is already good.\n" if $DEBUG>=3;

        }
        # If the address is old, we replace it with our string and record the replacement
        else {

          $_ = $STRINGS if not $DONTDOANYTHING;
          print "[D3] Replaced string.\n" if $DEBUG>=3;
        
          $SUCCESS=1;

        }

      }
      
      $i++;
    }

    # We close the file
    untie @filelines;
    
  }
  # If we are in a block, it's an exe function and we replaced something in the same block, we take the parameter and execute it
  elsif ($_ =~ /^exe (.+)$/ && $BLOCK == 1 && $SUCCESS == 1) {

    print "[D1] Executing \"".$1."\"\n" if $DEBUG>=1;
    
    system($1) if not $DONTDOANYTHING;

  }

}

# Closing the config file
close(CONFHANDLE);

exit 0;
