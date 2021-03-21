package Core;

use strict;
use utf8;
use Time::HiRes qw(gettimeofday sleep);

my $Doc;
sub Obj2DOM {
  my %Args = @_;

  my $Obj = $Args{'obj'};
  my $Parent = $Args{'parent'} || undef;
  my $Sub = $Args{'sub'} || 0;
  my $Root = $Args{'root'} || {name=>'root'};

  #параметры, влияющие на поведение отрисовки DOM
  my $ArrayNodeNameLikeParent = $Args{'like_parent'} || 0; # title1 =>[{},{}] ==> <title1><title1/><title1/></title1>
  my $Compact = $Args{'compact'} || 0;  # like_parent не актуально. элементы не обрамляются в item-контейнеры

  undef $Doc unless $Sub; #первый заход парсинга. $Doc fresh and virginity

  unless ($Doc) {
    $Doc = XML::LibXML::Document->new('1.0', 'utf-8');
  }

  my $First=0;
  if (!$Parent) {
    $First=1;
    $Parent = $Doc->createElement($Root->{'name'});
    if ($Root->{'attributes'}) {
      foreach my $RAttr ( keys %{$Root->{'attributes'}}) {
        $Parent->addChild($Doc->createAttribute( $RAttr => $Root->{'attributes'}->{$RAttr} ));
      }
    }
  }

  if (ref $Obj eq 'HASH') {

    foreach my $Key (sort keys %$Obj) {
      my $Value = $Obj->{$Key};

      if ($Key eq 'attributes') {
        foreach (sort keys %{$Obj->{'attributes'}}) {
          $Compact = 1 if $_ eq 'CP_compact' && $Obj->{'attributes'}->{$_}; #все следующие вложенные ноды - в формате compact
          $Parent->addChild($Doc->createAttribute( $_ => $Obj->{'attributes'}->{$_} )) unless $First;
        }
      } elsif ($Key eq 'value') {
        Obj2DOM(sub=>1, obj => $Obj->{$Key}, parent => $Parent, like_parent => $ArrayNodeNameLikeParent, compact => $Compact);
      } else {
        my $Child = $Doc->createElement($Key);
        Obj2DOM(sub=>1, obj => $Obj->{$Key}, parent => $Child, like_parent => $ArrayNodeNameLikeParent, compact => $Compact);            
        $Parent->addChild($Child); 
      }

    }

  } elsif (ref $Obj eq 'ARRAY') {
    foreach my $Item (@$Obj) {
      if (ref $Item eq ''
         || (!$Compact && ref $Item eq 'HASH')
         ) {
        my $Child;
        $Child = $Doc->createElement($ArrayNodeNameLikeParent?$Parent->nodeName:'item') unless $Compact;
        Obj2DOM(sub=>1, obj => $Item, parent => ($Compact ? $Parent : $Child), like_parent => $ArrayNodeNameLikeParent, compact => $Compact);            
        $Parent->addChild($Child) unless $Compact;     
      } else {
        Obj2DOM(sub=>1, obj => $Item, parent => $Parent, like_parent => $ArrayNodeNameLikeParent, compact => $Compact);
      }
    }
  } elsif (ref $Obj eq '') {
    $Parent->appendTextNode($Obj);
  }

  $Doc->setDocumentElement($Parent) unless $Sub;
  return $Doc;
}

sub Escape {
  my $Str = shift;
  $Str =~ s/</&lt;/g;
  $Str =~ s/>/&gt;/g;
  $Str =~ s/"/&quot;/g;
  return $Str;
}
 
### BENCHMARK

#Точка старта
sub _bs {
  my $self = shift;
  my $Key = shift;
  my $Desc = shift || undef;
  return if ( !(exists $self->{'bench'} && $self->{'bench'}) );

  $self->Error("Bench: _bs(); key not defined in string format") unless $Key;
  $self->Error("Bench: _bs(): Key is not a string") if ref $Key;

    $self->{'bench_list'}->{$Key} = {
      'desc' => $Desc,
      'timers' => []
    } unless exists $self->{'bench_list'}->{$Key};
  
  my $Timers = $self->{'bench_list'}->{$Key}->{'timers'};

  if (@$Timers) {
    die("Bench: last timer don't closed with X->_be('$Key') function")
      if exists $Timers->[scalar @$Timers - 1]->{'start'} && !exists $Timers->[scalar @$Timers - 1]->{'end'};
  }

  my $ts = gettimeofday();
  push @$Timers, {
    'start' => $ts,
  };
}

#Точка окончания
sub _be {
  my $self = shift;
  my $Key = shift;
  return if ( !(exists $self->{'bench'} && $self->{'bench'}) );

  die("Bench: _be(); key not defined in string format") unless $Key;
  die("Bench: _be(): Key is not a string") if ref $Key;

  die("Bench: _be(); Key '$Key' not exists. Do you make X->_bs($Key)??") unless exists $self->{'bench_list'}->{$Key};

  my $Timers = $self->{'bench_list'}->{$Key}->{'timers'};
  die("Bench: _be(): Can't close timer. Two o more calls of _be($Key)??")
    if exists $Timers->[scalar @$Timers - 1]->{'end'};
  my $te = gettimeofday();
  $Timers->[scalar @$Timers - 1]->{'end'} = $te;
}

#Сброс статистики
sub _bf {
  my $self = shift;

  return if ( !(exists $self->{'bench'} && $self->{'bench'}) );

  my $Out;

  $Out = "BENCHMARK ".localtime().":\n\n" if scalar keys %{$self->{'bench_list'}};

  foreach my $Key (sort keys %{$self->{'bench_list'}}) {
    my $Item = $self->{'bench_list'}->{$Key};
    my $Cnt = scalar @{$Item->{'timers'}};
    my $Summ=0;
    $Out .= "[key: '$Key'] ";
    $Out .= "[cnt: $Cnt] ";
    foreach my $t ( @{$Item->{'timers'}} ) {
      $Summ += ($t->{'end'} - $t->{'start'});
    }
    $Out .= "[time: ".sprintf('%.4f',$Summ)." sec] ";
    $Out .= "[avg: ".sprintf('%.4f',$Summ/$Cnt)." sec]\n";
    $Out .= "desc: ".$Item->{'desc'}."\n\n" if $Item->{'desc'};
  }

  $self->{'bench_list'} = {};

  return $Out if $self->{'bench'};
}

1;
