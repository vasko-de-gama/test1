package MyDB;

use strict;
use MySettings;
use DBI;
use Carp;

my $DBH;
_connect();

sub Do {
  my $SqlQuery = shift;
  my @Params = @_;

  my $sth = $DBH->prepare($SqlQuery) or _err($DBH->errstr);
  my $c=1;
  foreach (@Params) {
    $sth->bind_param($c,$_) or _err($sth->errstr);
    $c++;
  }
  $sth->execute() or _err($sth->errstr);
  $DBH->commit();
  return $sth;
}

sub DBQuery {
  my $SqlQuery = shift;
  my @Params = @_;
  return Do($SqlQuery,@Params);
}

#а вот если сотни тысяч строк, то хорошо инсертить пакетами. а то серверам от этого плохо бывает
sub BulkInsert {
  my %Args = @_;
  my $Sql = $Args{'sql'};
  my $Values = $Args{'values'};
  my $Postfix = $Args{'postfix'}; #тут по идее всякие 'on dublicate key', да ну их пока

  my $sth = new Bulk(
    sql => $Sql,
    values => $Values,
  );

  return $sth;
}

sub _connect {
  my $DBName = &MySettings::DB_NAME;
  my $Host = &MySettings::DB_HOST;
  my $Port = &MySettings::DB_PORT;
  my $Login = &MySettings::DB_LOGIN;
  my $Pwd = &MySettings::DB_PASSWORD;
  my $ConnectTimeOut = 10;

  my %Attr = (RaiseError=>0, AutoCommit=>0);
  my $dbh = DBI->connect("dbi:mysql:database=$DBName;host=$Host;port=$Port;mysql_connect_timeout=$ConnectTimeOut", $Login, $Pwd, \%Attr);
  $DBH = $dbh;
  return $dbh;
}

sub _err {
  my $Err = shift;
  print localtime();
  Carp::confess($Err);
}

package Bulk;

sub new {
  my $Class = shift;
  my %Args = @_;
  my $self = {
    sth => [], #сюда складываем sth на exec
    bulks => [], #копим params для бинда
    sql => $Args{'sql'}, #кусок sql insert 
    value => $Args{'values'}, #кусок sql от values(blabla)
  };
  return bless $self,$Class;
}

sub do {
  my $self = shift;
  my @Args = @_;

  push @{$self->{'bulks'}}, [@Args];
  BulkPrepare($self) if scalar @{$self->{'bulks'}} >= 10000; #переполнение сразу отдаем в prepare
}

sub BulkPrepare {
  my $self = shift;
  return unless scalar @{$self->{'bulks'}};

  my $SQL = $self->{'sql'}.' VALUES ' . join ',', map { $self->{'value'} } (0..scalar @{$self->{'bulks'}}-1);
  ##print $SQL."\n";

  my $sth = $DBH->prepare($SQL) or MyDB::_err($DBH->errstr);

  my $c=1;
  foreach (@{$self->{'bulks'}}) {
    next unless ref $_ eq 'ARRAY';
    foreach my $Val (@$_) {
      ##print $Val."\n";
      $sth->bind_param($c,$Val) or MyDB::_err($sth->errstr);
      $c++;
    }
  }
  push @{$self->{'sth'}}, $sth;
  $self->{'bulks'} = []; #собрали sth, обнулим хранилище

  return $sth;
}

sub finish {
  my $self = shift;
  my $s = BulkPrepare($self); #соберем недобитышей

  eval {
    ##$DBH->begin_work;
    foreach (@{$self->{'sth'}}) {
      ##print "executed\n";
      $_->execute() or MyDB::_err($_->errstr);
    }
  };

  if ($@) {
    MyDB::_err('Bulk insert error: '.$@);
    $DBH->rollback();
    return;
  }
  $DBH->commit();

}

1;
