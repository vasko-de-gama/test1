#!/usr/local/bin/perl

use strict;
use utf8;
use MyDB;
use Core;
use MySettings;
use Data::Dumper;

my $LogPath = $ARGV[0] || die "undefined param 'path to log file'";

#MyDB::Do("INSERT INTO log VALUES(?,?,?,?)",'2001-11-11','2','one','two');
MyDB::Do("TRUNCATE log");
MyDB::Do("TRUNCATE message");
##exit;

my $BulkMessage = MyDB::BulkInsert(
  'sql' => 'INSERT INTO message (created,id,int_id,str)',
  'values' => '(?,?,?,?)',
  'postfix' => undef,
);

my $BulkLog = MyDB::BulkInsert(
  'sql' => 'INSERT INTO log (created,int_id,str,address)',
  'values' => '(?,?,?,?)',
  'postfix' => undef,
);


#foreach (0..1000000) {
#  $BulkMessage->do('2001-11-11','2','one','two');
#}

my $s = {bench=>{}}; #тут по идее должен быть какой-тo self, ну да и ладно

Core::_bs($s,'All','All work');

open F,'<'.$LogPath or die $!;
while (<F>) {

  my ($Date,$Time,$IDint,$Flag,$Address1,$Address2,$Other) = split /\s/,$_,7;
  my $ID;
  if ($Other =~ m#id=(.+?)[\n\r\s]#) {
    $ID = $1;
  }
  $Date = '0000-00-00' unless $Date =~ /^\d\d\d\d\-\d\d\-\d\d$/;
  $Time = '00:00:00' unless $Time =~ /^\d\d:\d\d\:\d\d$/;

  $Address1 =~ s/[<>]//g;
  $Address2 =~ s/[<>]//g;

  my $Address;
  if (ValidEMAIL($Address2)) { #тут не уверен. при '=>' иногда 2 адреса, иногда один, еще :blackhole.  будем считать, что так верно (нет)... 
   $Address = $Address2;
  } elsif (ValidEMAIL($Address1)) {
   $Address = $Address1;
  }
#  next unless $Address; #ну не, пусть весь лог пишется, чего уж

  my $Str = join ' ', ($IDint,$Flag,$Address,$Other);
  $Str=~s/[\n\r]//g;

  if ($Flag eq '<=') { #входяшие
    unless ($ID) {
#      print "ID:".$ID."\n";
#      print $_;
      next;
    }
    Core::_bs($s,'DoMessage','Prepare to "message" table');
    $BulkMessage->do($Date.' '.$Time,$ID,$IDint,$Str);
    Core::_be($s,'DoMessage');
  } else {
    Core::_bs($s,'DoLog','Prepare to "log" table');
    $BulkLog->do($Date.' '.$Time,$IDint,$Str,$Address);
    Core::_be($s,'DoLog');
  }

}
close F;
Core::_be($s,'All');

Core::_bs($s,'BulkMessage','Write to "message" table');
$BulkMessage->finish();
Core::_be($s,'BulkMessage');

Core::_bs($s,'BulkLog','Write to "log" table');
$BulkLog->finish();
Core::_be($s,'BulkLog');

print "\n".Core::_bf($s);

sub ValidEMAIL {
  my $Email = shift;
  return 0 unless $Email;
  return 0 if length($Email)>50;
  return $Email=~ /^[-+a-z0-9_]+(\.[-+a-z0-9_]+)*\@([-a-z0-9_]+\.)+[a-z]{2,10}$/i;
}
