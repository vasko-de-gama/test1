#/usr/local/bin/perl

{
package MyWebServer;

use strict;
use utf8;
use MyDB;
use Core;
use Data::Dumper;
use XML::LibXSLT;
use XML::LibXML;
use HTTP::Server::Simple::CGI;
use base qw(HTTP::Server::Simple::CGI);

my $Parser = XML::LibXML->new();
my $XSLT = XML::LibXSLT->new;

my %dispatch = (
  '/' => \&resp_index,
);

sub handle_request {
    my $self = shift;
    my $cgi  = shift;

    MyDB::_connect(); #демонезировались и потеряли коннект. хитрые реконнекты городить не охота, поступим тупо

    my $path = $cgi->path_info();
    my $handler = $dispatch{$path};

    if (ref($handler) eq "CODE") {
        print "HTTP/1.0 200 OK\r\n";
        $handler->($self,$cgi);

    } else {
        print "HTTP/1.0 404 Not found\r\n";
        print $cgi->header,
              $cgi->start_html('Not found'),
              $cgi->h1('Not found'),
              $cgi->end_html;
    }

}
 
sub resp_index {
  my $self = shift;
  my $cgi  = shift;
  return if !ref $cgi;
  $self->{'bench'} = {};

  my $ShowXML = $cgi->param('xml') || 0;
  my $Action = $cgi->param('action') || undef;
  my $Address = $cgi->param('address') || undef;

  my $Data;
  my $XML;

  if ($Action eq 'search' && $Address ne '') {
    Core::_bs($self,'getlogs',"Запрос логов");
    $Data = GetLogs($Address);
    Core::_be($self,'getlogs');
    Core::_bs($self,'obj2dom',"data => xml");
    $XML = Core::Obj2DOM(obj=>$Data->{'list'},root=>{name=>'logs'});
    Core::_be($self,'obj2dom');
  } else{
    $XML=Core::Obj2DOM(obj=>[],root=>{name=>'logs'});
  }

  $XML =~ s/<\?xml.+?>[\n\r]?//;
  $XML = '<?xml version="1.0" encoding="utf-8"?>
<root>
' . $XML 
. '<all_count>'.$Data->{'count'}.'</all_count>'
. '<search>'.Core::Escape($Address).'</search>'
. '<bench>'.Core::_bf($self).'</bench>
</root>';

  if ($ShowXML) {
    print $cgi->header(-type=>"text/xml;charset=utf8");
    print $XML;
    return;
  }

  print $cgi->header(-type=>"text/html;charset=utf8");

  my $Source = $Parser->load_xml(
    string => $XML,
  );

  my $Stylesheet = $XSLT->parse_stylesheet_file('./xsl/index.xsl');
  my $Result = $Stylesheet->transform($Source);

  #print $Source;
  print $Result;

  return;
}

sub GetLogs {
  my $EMail = shift;;

  #может чего покрасивее можно. ну вроде через UNION имеет право на жизнь
  # но limit общий на два запроса, а-я-яй. ну и ладно
  my $List = MyDB::DBQuery("
    SELECT SQL_CALC_FOUND_ROWS
      sub.created,
      sub.str,
      sub.address,
      sub.int_id
    FROM (SELECT
            l.created,
            l.str,
            l.address,
            l.int_id
            FROM log l
          WHERE l.address = ?
        UNION
          SELECT
            m.created,
            m.str,
            NULL AS address,
            -- m.id,
            m.int_id
          FROM message m
            JOIN log l ON m.int_id = l.int_id
              AND l.address = ?
          GROUP BY m.id 
    ) sub
    ORDER BY sub.int_id, sub.created ASC
    LIMIT 100
  ",
    $EMail,
    $EMail
  )->fetchall_arrayref({});

  my $Count = MyDB::Do("SELECT FOUND_ROWS()")->fetchrow;

  return {
    list => $List,
    count => $Count,
  };

}

}

my $pid = MyWebServer->new(&MySettings::SERVER_PORT)->background();
print "Use 'kill $pid' to stop server.\n";
