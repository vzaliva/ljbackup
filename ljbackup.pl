#!/usr/bin/perl
#
# $Id: ljbackup.pl,v 1.13 2012/02/01 23:24:37 lord Exp $
#
# Perl script to backup user live journal (http://www.livejournal.com/)
#
# Usage example: 
#   ljbackup.pl --user=user_name --password=pass_word --dir /home/user/ljbackup --verbose 
# Could be used from cron(8).
#
# Requires perl(1) and followinf perl modules (could be found on CPAN(3pm)):
#
# 1. RPC::XML
# 2. Digest::MD5
# 3. XML::Parser
# 4. URI::Escape
#
# Author Vadim Zaliva <lord@crocodile.org>
#
# This program is free software which we release under the GNU General Public
# License. You may redistribute and/or modify this program under the terms
# of that license as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#

use RPC::XML::Client;
use Getopt::Long;
use Digest::MD5  qw(md5 md5_hex);
use URI::Escape;

my $user;
my $pass;
my $dir;
my $verbose='';

sub backup_day
  {
      $client = $_[0];
      $day    = $_[1];
      $pdate  = $day->{date};
      $pcount = $day->{count};
      ($year, $month, $mday) = split('-',$pdate);
      
      $pfile = $dir . '/day-' . $pdate . ".html";
      if(-f $pfile)
      {
          if($verbose)
          {
              print "File $pfile already exists\n";
          }
          return 0;
      } 

      
      if($verbose)
      {
          print "Backing up $pcount posts from $pdate to $pfile\n";
      }
      
      my $params = RPC::XML::struct->new(username    => $user          , 
                                         hpassword   => md5_hex($pass) ,
                                         ver	     => 1      ,
                                         noprops     => 1      ,
                                         selecttype  => "day"  ,
                                         year        => $year  ,
                                         month       => $month ,
                                         day         => $mday  ,
                                         lineendings => "unix"
                                        );
      my $req = RPC::XML::request->new('LJ.XMLRPC.getevents', $params);
      my $res = $client->send_request($req);
      if(UNIVERSAL::isa($res,'RPC::XML::fault'))
      {
          print "Error getting posts for day $pdate. Error message: " . $res->string() ."\n";
          return 1;
      }
      if(!UNIVERSAL::isa($res, 'RPC::XML::datatype'))
      {
          print "Error getting posts for day $pdate. Error message: $res\n";
          return 1;
      }

      my @evtarr = @{$res->{events}->value};
      if($verbose) 
      {
          print "\t" . @evtarr . " posts downloaded\n";
      }

      if(!open(PF,">$pfile"))
      {
          print "Error opening file $pfile. Reason: $!\n";
          return 2;
      }
      binmode PF;

      print PF "<!doctype HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\">\n";
      print PF "<html><head>";
      print PF "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />\n";
      print PF "<title> $user live journal posts for $pdate </title>\n";
      print PF "</head><body>\n\n";
      print PF "<h1>$user live journal posts for $pdate </h1>\n";
      foreach(@evtarr)
      {
          my $evt = $_;
          print PF "<p>\n";
          print PF "<b>Subject:</b> " . $evt->{subject} . "<br>\n";
          print PF "<b>Date:</b> " . $evt->{eventtime} . "<br><br>\n";
          print PF uri_unescape($evt->{event});
          print PF "<hr>\n";
      }
      print PF "</html>";
      close PF;

      return 0;
  }

my $optres=GetOptions("password=s"   => \$pass,
                      "user=s"   => \$user, 
                      "dir=s"   => \$dir, 
                      "verbose!"  => \$verbose
                     );

if(!$optres || !$user || !$pass || !$dir)
{
    print "Usage: ljbackup --user=<user> --password=<password> --dir=<dir> [--[no]verbose]\n";
    exit 2;
}

if($verbose)
{
    print "Connecting to LiveJournal.com as user $user\n";
    print "Fetching post counts\n";
}

my $client = new RPC::XML::Client 'http://www.livejournal.com/interface/xmlrpc';
my $params = RPC::XML::struct->new(username => $user, hpassword => md5_hex($pass));
my $req = RPC::XML::request->new('LJ.XMLRPC.getdaycounts', $params);
my $res = $client->send_request($req);
if(UNIVERSAL::isa($res, 'RPC::XML::fault'))
{
    print "Error getting lists of posts. Error message: " . $res->string() ."\n";
    exit(1);
}
if(!UNIVERSAL::isa($res, 'RPC::XML::datatype'))
{
    print "Error getting lists of posts.  Error message: $res\n";
    exit(1);
}

my @dayarr = @{$res->{daycounts}->value};
if($verbose) 
{
    print @dayarr . " days have posts\n";
}

foreach(@dayarr)
{
    backup_day($client, $_) && die "Terminating backup due to errors";
}

if($verbose)
{
    print "backup done\n";
}
exit(0);


