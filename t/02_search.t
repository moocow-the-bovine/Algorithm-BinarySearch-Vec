# -*- Mode: CPerl -*-
# t/02_search.t; test search

$TEST_DIR = './t';
#use lib qw(../blib/lib ../blib/arch); $TEST_DIR = '.'; # for debugging

use Algorithm::BinarySearch::Vec ':default';
my $NOKEY = $KEY_NOT_FOUND;
my $PKG   = 'Algorithm::BinarySearch::Vec';

# load common subs
do "$TEST_DIR/common.plt"
  or die("could not load $TEST_DIR/common.plt");

plan(test => 42);

##--------------------------------------------------------------
## utils

## $vec = makevec($nbits,\@vals);
sub makevec {
  my ($nbits,$vals) = @_;
  my $vec   = '';
  vec($vec,$_,$nbits)=$vals->[$_] foreach (0..$#$vals);
  return $vec;
}

## \@l = vec2list($vec,$nbits)
sub vec2list {
  use bytes;
  my ($vec,$nbits) = @_;
  return [map {vec($vec,$_,$nbits)} (0..(length($vec)*8/$nbits-1))];
}

## $str = n2str($n)
sub n2str {
  return !defined($_[0]) ? 'undef' : ($_[0]==$NOKEY ? 'NOKEY' : ($_[0]+0));
}

## $str = l2str(\@vlist)
sub l2str {
  return join(' ', map {n2str($_)} @{$_[0]});
}

## $str = h2str(\%i2j)
sub h2str {
  my $h = shift;
  no warnings 'numeric';
  return join(' ', map {(n2str($_).":".n2str($h->{$_}))} sort {$a<=>$b} keys %$h);
}

##======================================================================
## test: element-wise: generic

sub check_search {
  my ($func,$nbits,$l,$key,$want) = @_;
  print "check_search:$func(nbits=$nbits,key=$key,l=[",l2str($l),"]): ";
  my $code = eval "\\\&$func";
  my $v    = makevec($nbits,$l);
  my $i    = $code->($v,$key,$nbits); #, 0,$#$l);
  my $istr = n2str($i);
  my $wstr = n2str($want);
  my $rc   = ($istr eq $wstr);
  print
    (($rc ? "good (=$wstr)" : "BAD (want=$wstr != got=$istr)"), "\n");
  ok($rc);
  return $rc;
}

##--------------------------------------------------------------
## test: element-wise: bsearch: (0) +(5*2) = (1..10)
foreach my $func ("${PKG}::_vbsearch", "${PKG}::XS::vbsearch") {
  my $l = [qw(1 2 4 8 16 32 64 128 256)];
  check_search($func, 32,$l, 8=>3);
  check_search($func, 32,$l, 7=>$NOKEY);
  check_search($func, 32,$l, 0=>$NOKEY);
  check_search($func, 32,$l, 512=>$NOKEY);
  check_search($func, 32,[qw(0 1 1 1 2)], 1=>1);
  print "\n";
}

##--------------------------------------------------------------
## test: element-wise: bsearch_lb: (10) +(5*2) = (11..20)
foreach my $func ("${PKG}::_vbsearch_lb", "${PKG}::XS::vbsearch_lb") {
  my $l = [qw(1 2 4 8 16 32 64 128 256)];
  check_search($func,32,$l, 8=>3);
  check_search($func,32,$l, 7=>2);
  check_search($func,32,$l, 0=>$NOKEY);
  check_search($func,32,$l, 512=>8);
  check_search($func,32,[qw(0 1 1 1 2)],1=>1);
  print "\n";
}

##--------------------------------------------------------------
## test: element-wise: bsearch_ub: (20) +(5*2) = (21..30)
foreach my $func ("${PKG}::_vbsearch_ub", "${PKG}::XS::vbsearch_ub") {
  my $l = [qw(1 2 4 8 16 32 64 128 256)];
  check_search($func,32,$l, 8=>3);
  check_search($func,32,$l, 7=>3);
  check_search($func,32,$l, 0=>0);
  check_search($func,32,$l, 512=>$NOKEY);
  check_search($func,32,[qw(0 1 1 1 2)],1=>3);
  print "\n";
}

##======================================================================
## test: array-wise: generic

sub check_asearch {
  my ($func,$nbits,$l,$key2want) = @_;
  print "check_asearch:$func(nbits=$nbits,l=[",l2str($l),"],want={",h2str($key2want),"}): ";
  my $code = eval "\\\&$func";
  my $v    = makevec($nbits,$l);
  my @keys = sort {$a<=>$b} keys %$key2want;
  my $want = @$key2want{@keys};
  my $il   = $code->($v,\@keys,$nbits); #, 0,$#$l);
  my $istr = h2str({map {($keys[$_]=>$il->[$_])} (0..$#keys)});
  my $wstr = h2str($key2want);
  my $rc   = ($istr eq $wstr);
  print
    (($rc ? "good (=[$wstr])" : "BAD (want=[$wstr] != got=[$istr])"), "\n");
  ok($rc);
  return $rc;
}

##--------------------------------------------------------------
## test: array-wise: (30) +(3*2) = (31..36)

foreach my $prefix ("${PKG}::_","${PKG}::XS::") {
  my $l    = [qw(1 2 4 8 16 32 64 128 256)];
  check_asearch("${prefix}vabsearch",    32,$l,{8=>3, 7=>$NOKEY, 0=>$NOKEY, 1=>0, 512=>$NOKEY, 32=>5, 256=>8});
  check_asearch("${prefix}vabsearch_lb", 32,$l,{8=>3, 7=>2,      0=>$NOKEY, 1=>0, 512=>8,      32=>5, 256=>8});
  check_asearch("${prefix}vabsearch_ub", 32,$l,{8=>3, 7=>3,      0=>0,      1=>0, 512=>$NOKEY, 32=>5, 256=>8});
}

##--------------------------------------------------------------
## test: vec-wise: (36) +(3*2) = (37..42)

sub check_vvsearch {
  my ($func,$nbits,$l,$key2want) = @_;
  print "check_vvsearch:$func(nbits=$nbits,l=[",l2str($l),"],want={",h2str($key2want),"}): ";
  my $code = eval "\\\&$func";
  my $v    = makevec($nbits,$l);
  my @keys = sort {$a<=>$b} keys %$key2want;
  my $keyv = makevec($nbits,\@keys);
  my $want = @$key2want{@keys};
  my $iv   = $code->($v,$keyv,$nbits); #, 0,$#$l);
  my $istr = h2str($key2want);
  my $wstr = h2str({map {($keys[$_]=>vec($iv,$_,32))} (0..$#keys)});
  my $rc   = ($istr eq $wstr);
  print
    (($rc ? "good (=[$wstr])" : "BAD (want=[$wstr] != got=[$istr])"), "\n");
  ok($rc);
  return $rc;
}

foreach my $prefix ("${PKG}::_","${PKG}::XS::") {
  my $l    = [qw(1 2 4 8 16 32 64 128 256)];
  check_vvsearch("${prefix}vvbsearch",    32,$l,{8=>3, 7=>$NOKEY, 0=>$NOKEY, 1=>0, 512=>$NOKEY, 32=>5, 256=>8});
  check_vvsearch("${prefix}vvbsearch_lb", 32,$l,{8=>3, 7=>2,      0=>$NOKEY, 1=>0, 512=>8,      32=>5, 256=>8});
  check_vvsearch("${prefix}vvbsearch_ub", 32,$l,{8=>3, 7=>3,      0=>0,      1=>0, 512=>$NOKEY, 32=>5, 256=>8});
}


# end of t/02_search.t
