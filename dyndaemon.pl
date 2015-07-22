#!/usr/bin/perl -w
#
# dyndaemon.pl v1.2
#
# Martino Dell'Ambrogio <tillo@httpdnet.com>, 2006, GPLv2

use Getopt::Long;
use Tie::File;

%options=();
$options{i} = '';
$options{d} = '';
$options{n} = '';
$options{h} = '';

GetOptions('i|iface=s' => \$options{i}, 'd|debug=i' => \$options{d}, 'n|donothing' => \$options{n}, 'h|help' => \$options{h});

$IFACE=$options{i} if $options{i} or $IFACE="ppp0";
$DEBUG=$options{d} if $options{d} or $DEBUG="0";
$DONTDOANYTHING=1 if $options{n};

print "Arguments are:

        -i, --iface IF          It makes dyndaemon look for the first v4 address of interface IF instead of ppp0
        -n, --donothing         It makes dyndaemon not to write to files nor execute commands
        -d, --debug NUM         It makes dyndaemon output debug messages. NUM can be 1, 2 or 3
        -h, --help              It makes dyndaemon output a little help message about arguments\n" and exit(0) if $options{h};

$CHKHIDDENFIELDSEPARATOR = '#';

open(CONFHANDLE, "/etc/dyndaemon.conf") or open(CONFHANDLE, "/usr/local/etc/dyndaemon.conf") or open(CONFHANDLE, "dyndaemon.conf") or die "Can't open config file!";

$BLOCK=0;
$SUCCESS=0;
$NEWIPP=$NEWIP=`/sbin/ifconfig $IFACE | grep 'inet ' | head -n 1 | awk '{print \$2}' | sed 's/addr://g' | tr -d '\n'` or die "Can't find interface \"".$IFACE."\".\n";
$NEWIPP=~s/\./\\\./g;

print "[D1] New IP is \"".$NEWIP."\".\n" if $DEBUG>=1;

print "[D3] New IP to be parsed is \"".$NEWIPP."\".\n" if $DEBUG>=3;

while(<CONFHANDLE>) {

  chomp;

  if ($_ =~ /^BEGIN$/) {

    print "[D3] BEGIN encountered.\n" if $DEBUG>=3;

    $BLOCK=1;
    $SUCCESS=0;
  
  }
  elsif ($_ =~ /^END$/) {

    print "[D3] END encountered.\n" if $DEBUG>=3;
  
    $BLOCK=0;
    $SUCCESS=0;
    
  }
  elsif ($_ =~ /^chk (.+?) (.+)$/ && $BLOCK == 1) {

    $FILENAME=$1;
    $STRING=$2;
    print "[D1] Checking \"".$FILENAME."\" for string \"".$STRING."\".\n" if $DEBUG>=1;

    if ($2 =~ /^(.+)$CHKHIDDENFIELDSEPARATOR(.+)$/) {
      print "[D3] chk's tirdh hidden field encountered.\n" if $DEBUG>=3;
      $STRINGPO=$STRINGP=$1;
      $STRINGS=$2;
    }
    elsif ($2 =~ /^([^$CHKHIDDENFIELDSEPARATOR]+)$/) {
      $STRINGPO=$STRINGS=$STRINGP=$1;
    }

    $STRINGP=~s/\{\}/\[0-9\]\{1,3\}\\\.\[0-9\]\{1,3\}\\\.\[0-9\]\{1,3\}\\\.\[0-9\]\{1,3\}/;
    print "[D3] Regexp to parse is \"".$STRINGP."\".\n" if $DEBUG>=3;
    
    $STRINGS=~s/\{\}/$NEWIP/;
    print "[D3] Substitute is \"".$STRINGS."\".\n" if $DEBUG>=3;

    tie @filelines, 'Tie::File', $FILENAME or die "Can't open file! ($FILENAME)";
    print "[D2] File opened.\n" if $DEBUG>=2;

    $i=1;
    for(@filelines) {
      
      chomp;

      if ($_ =~ /^$STRINGP$/) {

        print "[D2] Found string \"".$_."\" at line ".$i.".\n" if $DEBUG>=2;

        $STRINGPO=~s/\{\}/\(\.\+\)/;
        print "[D3] Regexp to parse for old IP is \"".$STRINGPO."\".\n" if $DEBUG>=3;

        $_=~/$STRINGPO/;
        $OLDIP=$1;

        if ($OLDIP eq $NEWIP) {
        
          print "[D3] Not replacing because IP is already good.\n" if $DEBUG>=3;

        }
        else {

          $_ = $STRINGS if not $DONTDOANYTHING;
          print "[D3] Replaced string.\n" if $DEBUG>=3;
        
          $SUCCESS=1;

        }

      }
      
      $i++;
    }

    untie @filelines;
    
  }
  elsif ($_ =~ /^exe (.+)$/ && $BLOCK == 1 && $SUCCESS == 1) {

    print "[D1] Executing \"".$1."\"\n" if $DEBUG>=1;
    
    system($1) if not $DONTDOANYTHING;

  }

}

close(CONFHANDLE);

exit 0;

