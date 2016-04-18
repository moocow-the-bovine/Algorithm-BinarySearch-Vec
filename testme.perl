#!/usr/bin/perl -w
#-*- Mode: CPerl; coding: utf-8 -*-

use lib qw(./blib/lib ./blib/arch);
use Algorithm::BinarySearch::Vec ':all';
use Benchmark qw(cmpthese timethese);
use Test::More;
no warnings 'portable'; ##-- avoid "Bit vector size > 32 non-portable" errors

our $NOKEY = $KEY_NOT_FOUND;
our $PKG   = 'Algorithm::BinarySearch::Vec';
print STDERR "Algorithm::BinarySearch::Vec::HAVE_XS = $Algorithm::BinarySearch::Vec::HAVE_XS\n";

BEGIN {
  #binmode(\*STDOUT,':utf8');
}

##--------------------------------------------------------------
## utils: generic

## $vec = makevec($nbits,\@vals)
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

sub check_search {
  my ($func,$nbits,$l,$key,$want) = @_;
  print "check_search:$func(nbits=$nbits,key=$key,l=[",l2str($l),"]): ";
  my $code = (main->can($func)
	      || $PKG->can($func)
	      || "${PKG}::XS"->can($func)
	      || $PKG->can("_$func")
	      || die("check_search:${func}: could not find function '$func'"));
  my $v    = makevec($nbits,$l);
  my $i    = $code->($v,$key,$nbits); #, 0,$#$l);
  my $istr = n2str($i);
  my $wstr = n2str($want);
  my $rc   = ($istr eq $wstr);
  print
    (($rc ? "good (=$wstr)" : "BAD (want=$wstr != got=$istr)"), "\n");
  return $rc;
}

##--------------------------------------------------------------
## test: vget

sub checkvec {
  use bytes;
  my ($v,$nbits,$label,$verbose) = @_;
  $label   = "checkvec($nbits)" if (!$label);
  $verbose = 1 if (!defined($verbose));
  my $ok = 1;
  my ($i,$vval,$xval);
  foreach $i (0..(length($v) * (8.0/$nbits) - 1)) {
    $vval = vec($v,$i,$nbits);
    $xval = vget($v,$i,$nbits);
    print "$label\[$i]: ", ($vval==$xval ? "ok ($vval)" : "NOT ok (v:$vval != x:$xval)"), "\n" if ($verbose);
    $ok &&= ($vval==$xval);
  }
  print "\n" if ($verbose);
  return $ok;
}

sub test_vget {
  my $v1 = makevec(1, [qw(0 1 1 0 1 1 0 1)]);
  my $v2 = makevec(2, [qw(0 1 2 3 3 2 1 0)]);
  my $v4 = makevec(4, [qw(0 1 2 4 8 15)]);
  my $v8 = makevec(8, [qw(0 1 2 4 8 16 32 64 128 255)]);
  my $v16 = makevec(16, [qw(100 500 1000 65000)]);
  my $v32 = makevec(32, [qw(100 500 1000 100000)]);
  my $v64 = makevec(64, [qw(1 1000 1000000 1000000000 1000000000000)]);

  ##-- debug
  if (0) {
    checkvec($v1,1);
    checkvec($v2,2);
    checkvec($v4,4);
    checkvec($v8,8);
    checkvec($v16,16);
    checkvec($v32,32);
    checkvec($v64,64);
    exit 0;
  }

  ##-- random
  my $ok = 1;
  foreach my $nbits (qw(1 2 4 8 16 32 64)) {
    my $nelem = 100;
    my $l     = [map {int(rand(2**$nbits))} (1..$nelem)];
    my $v     = makevec($nbits, $l);
    $ok       = checkvec($v,$nbits,undef,0);
    if (!$ok) {
      die "NOT ok: get:random(nbits=$nbits,l=[",join(' ',@$l),"])\n";
    } else {
      print "ok: get:random(nbits=$nbits,nelem=$nelem)\n";
    }
  }
  print "\n";
}
#test_vget();

##--------------------------------------------------------------
## test: vset

sub check_set {
  my ($nbits,$l,$i,$val, $verbose) = @_;
  my $label = "checkset(nbits=$nbits,i=$i,val=$val)";
  $verbose  = 1 if (!defined($verbose));

  my $v0 = ref($l) ? makevec($nbits,$l) : $l;
  my $vv = $v0;
  my $vx = $v0;

  vec($vv,$i,$nbits) = $val;
  vset($vx,$i,$nbits,$val);

  my $vgot = vec($vv,$i,$nbits);
  my $xgot = vec($vx,$i,$nbits);
  my $rc  = ($vgot==$xgot);
  if ($verbose || !$rc) {
    print "$label: ", ($rc ? "ok ($vgot)" : "NOT ok (v:$vgot != x:$xgot)"), "\n";
  }
  return $rc;
}

sub test_vset {

  ##-- debug
  if (0) {
    check_set(1,[qw(0 1 1 0 1 1 0 1)],3=>1);
    check_set(1,[qw(1 1 1 0 0 1 1 1 0 0 0 0 0 0 0 0)],7=>0);
    check_set(2,[qw(0 1 2 3 3 2 1 0)], 6=>2);
    check_set(4,[qw(0 1 2 4 8 15)],5=>7);
    check_set(8,[qw(0 1 2 4 8 16 32 64 128 255)],1=>255);
    check_set(16,[qw(100 500 1000 65000)], 3=>12345);
    check_set(32,[qw(100 500 1000 100000)], 2=>98765);
    exit 0;
  }

  ##-- random
  foreach my $nbits (qw(1 1 1 1 1)) { #qw(1 2 4 8 16 32)) {
    my $nelem = 10;
    my $v     = makevec($nbits,[map {int(rand(2**$nbits))} (1..$nelem)]);
    my $i     = int(rand($nelem));
    foreach $i (0..($nelem-1)) {
      my $val = int(rand(2**$nbits));
      $l      = vec2list($v,$nbits); ##-- save
      my $ok  = check_set($nbits,$v,$i,$val, 0);
      if (!$ok) {
	die "NOT ok: set:random(nbits=$nbits,l=[".join(' ',@$l)."],i=$i,val=$val)\n";
      } else {
	print "ok: set:random(nbits=$nbits,nelem=$nelem,i=$i,val=$val)\n";
      }
    }
  }
  print "\n";
}
#test_vset();

##======================================================================
## test: element-wise: generic


##--------------------------------------------------------------
## test: bsearch (raw)

sub check_bsearch {
  check_search('vbsearch',@_);
}

sub test_bsearch {
  my ($l,$i);
  $l = [qw(1 2 4 8 16 32 64 128 256)];
  my $rc = 1;
  $rc &&= check_bsearch(32,$l, 8=>3);
  $rc &&= check_bsearch(32,$l, 7=>$NOKEY);
  $rc &&= check_bsearch(32,$l, 0=>$NOKEY);
  $rc &&= check_bsearch(32,$l, 512=>$NOKEY);
  $rc &&= check_bsearch(32,[qw(0 1 1 1 2)], 1=>1);
  die("test_bsearch() failed!\n") if (!$rc);
  print "\n";
}
#test_bsearch();


##--------------------------------------------------------------
## test: lower_bound

sub check_lb {
  check_search('vbsearch_lb',@_);
}

sub test_lb {
  my ($l,$i);
  $l = [qw(1 2 4 8 16 32 64 128 256)];
  my $rc = 1;
  $rc &&= check_lb(32,$l, 8=>3);
  $rc &&= check_lb(32,$l, 7=>2);
  $rc &&= check_lb(32,$l, 0=>$NOKEY);
  $rc &&= check_lb(32,$l, 512=>$#$l);
  $rc &&= check_lb(32,[qw(0 1 1 1 2)], 1=>1);
  die("test_lb() failed!\n") if (!$rc);
  print "\n";
}
#test_lb();

##-- test: lb: sx.vec
sub test_lb_sx {
  local $/=undef;
  open(my $fh, "<:raw", "sx.vec") or die("$0: could not open sx.vec: $!");
  my $sxv = <$fh>;
  close $fh;

  ##-- check lb
  my $func = Algorithm::BinarySearch::Vec->can('_vbsearch_lb');
  my ($lb);
  #$lb = $func->($sxv,4576,32);
  #die("BAD: sx (want=0; got=$lb)") if ( $lb != 0 );

  my $sxv0 = substr($sxv,0,16);
  $lb = $func->($sxv0,4576,32);
  die("BAD: sx (want=0; got=$lb)!") if ( $lb != 0 );
}
#test_lb_sx();



##--------------------------------------------------------------
## test: upper_bound

sub check_ub {
  check_search('vbsearch_sub',@_);
}

sub test_ub {
  my ($l,$i);
  $l = [qw(1 2 4 8 16 32 64 128 256)];
  my $rc = 1;
  $rc &&= check_ub(32,$l, 8=>3);
  $rc &&= check_ub(32,$l, 7=>3);
  $rc &&= check_ub(32,$l, 0=>0);
  $rc &&= check_ub(32,$l, 512=>$NOKEY);
  $rc &&= check_ub(32,[qw(0 1 1 1 2)], 1=>3);
  die("test_ub() failed!\n") if (!$rc);
  print "\n";
}
#test_ub();


##--------------------------------------------------------------
## test: bsearch: array


sub check_asearch {
  my ($func,$nbits,$l,$key2want) = @_;
  print "check_asearch:$func(nbits=$nbits,l=[",l2str($l),"],want={",h2str($key2want),"}): ";
  my $code = (main->can($func)
	      || $PKG->can($func)
	      || "${PKG}::XS"->can($func)
	      || $PKG->can("_$func")
	      || die("check_asearch:${func}: could not find function '$func'"));
  my $v    = makevec($nbits,$l);
  my @keys = sort {$a<=>$b} keys %$key2want;
  my $want = @$key2want{@keys};
  my $il   = $code->($v,\@keys,$nbits); #, 0,$#$l);
  my $wstr = h2str($key2want);
  my $istr = h2str({map {($keys[$_]=>$il->[$_])} (0..$#keys)});
  my $rc   = ($istr eq $wstr);
  print 
    (($rc ? "good\n" : ("BAD:\n",
			"> BAD: want=[$wstr] !=\n",
			"> BAD:  got=[$istr]\n")));
  return $rc;
}

sub test_absearch {
  my ($l,$i);
  my $rc = 1;
  $l = [qw(1 2 4 8 16 32 64 128 256)];
  my $keys = [qw(8 7 0 1 512 32 256)];
  $rc &&= check_asearch('vabsearch',    32,$l, {8=>3, 7=>$NOKEY, 0=>$NOKEY, 1=>0, 512=>$NOKEY, 32=>5, 256=>8});
  $rc &&= check_asearch('vabsearch_lb', 32,$l, {8=>3, 7=>2,      0=>$NOKEY, 1=>0, 512=>8,      32=>5, 256=>8});
  $rc &&= check_asearch('vabsearch_ub', 32,$l, {8=>3, 7=>3,      0=>0,      1=>0, 512=>$NOKEY, 32=>5, 256=>8});
  die("test_absearch() failed!\n") if (!$rc);
  print "\n";
}
#test_absearch(); exit 0;

##--------------------------------------------------------------
## test: bsearch: vec-wise

sub check_vvsearch {
  my ($func,$nbits,$l,$key2want) = @_;
  print "check_vvsearch:$func(nbits=$nbits,l=[",l2str($l),"],want={",h2str($key2want),"}): ";
  my $code = (main->can($func)
	      || $PKG->can($func)
	      || "${PKG}::XS"->can($func)
	      || $PKG->can("_$func")
	      || die("check_vvsearch:${func}: could not find function '$func'"));
  my $v    = makevec($nbits,$l);
  my @keys = sort {$a<=>$b} keys %$key2want;
  my $keyv = makevec($nbits,\@keys);
  my $want = @$key2want{@keys};
  my $iv   = $code->($v,$keyv,$nbits); #, 0,$#$l);
  my $istr = h2str($key2want);
  my $wstr = h2str({map {($keys[$_]=>vec($iv,$_,32))} (0..$#keys)});
  my $rc   = ($istr eq $wstr);
  print 
    (($rc ? "good\n" : ("BAD:\n",
			"> BAD: want=[$wstr] !=\n",
			"> BAD:  got=[$istr]\n")));
  return $rc;
}

sub test_vvsearch {
  my ($l,$i);
  my $rc = 1;
  $l = [qw(1 2 4 8 16 32 64 128 256)];
  my $keys = [qw(8 7 0 1 512 32 256)];
  $rc &&= check_vvsearch('vvbsearch',    32,$l, {8=>3, 7=>$NOKEY, 0=>$NOKEY, 1=>0, 512=>$NOKEY, 32=>5, 256=>8});
  $rc &&= check_vvsearch('vvbsearch_lb', 32,$l, {8=>3, 7=>2,      0=>$NOKEY, 1=>0, 512=>8,      32=>5, 256=>8});
  $rc &&= check_vvsearch('vvbsearch_ub', 32,$l, {8=>3, 7=>3,      0=>0,      1=>0, 512=>$NOKEY, 32=>5, 256=>8});
  die("test_absearch() failed!\n") if (!$rc);
  print "\n";
}
#test_vvsearch();

##--------------------------------------------------------------
## quads

no warnings 'portable';

sub test_quad {
  my $val = '9876543210';

  my ($v32,$v64);
  vec($v32, 0, 32) = $val;
  vec($v64, 0, 64) = $val;
  my $got32 = vec($v32,0,32);
  my $got64 = vec($v64,0,64);
  my $vgot64 = Algorithm::BinarySearch::Vec::XS::vget($v64,0,64);

  ##-- vget: test initial item
  ok("$got32" ne "$val", "vec(\$v,0,32) ne $val");
  ok("$got64" eq "$val", "vec(\$v,0,64) eq $val");
  ok("$vgot64" eq "$val", "vget(\$v,0,64) eq $val");

  ##-- vget: test non-initial item
  my $i = 17;
  vec($v64,$i,64) = $val;
  $got64  = vec($v64,$i,64);
  $vgot64 = Algorithm::BinarySearch::Vec::XS::vget($v64,$i,64);
  ok("$got64" eq "$val", "vec(\$v,$i,64) eq $val");
  ok("$vgot64" eq "$val", "vget(\$v,$i,64) eq $val");

  ##-- vset: test initial item
  ++$val;
  $i = 0;
  Algorithm::BinarySearch::Vec::XS::vset($v64,$i,64,$val);
  $got64  = vec($v64,$i,64);
  ok("$got64" eq "$val", "vset: vec(\$v,$i,64) eq $val");

  ##-- vset: test non-initial item
  ++$val;
  $i = 17;
  Algorithm::BinarySearch::Vec::XS::vset($v64,$i,64,$val);
  $got64  = vec($v64,$i,64);
  ok("$got64" eq "$val", "vset: vec(\$v,$i,64) eq $val");

  print STDERR "test_quad() done.\n";
}
#test_quad();

##--------------------------------------------------------------
## set ops: union

sub test_union {
  my $nbits = shift || 8;
  my $avec = makevec($nbits, [qw(1 2 3 4 5 6 7 8 9)]);
  my $bvec = makevec($nbits, [qw(2 4 6 8 10 12 14)]);
  my $cvec = vvunion($avec,$bvec,$nbits);

  my $clist = vec2list($cvec,$nbits);
  is_deeply($clist, [(1..9),(12,14)], "vvunion");

  print STDERR "test_union(): done.\n";
}
#test_union @ARGV;

##--------------------------------------------------------------
## set ops: intersect

sub test_intersect {
  my $nbits = shift || 8;
  my $avec = makevec($nbits, [qw(1 2 3 4 5 6 7 8 9)]);
  my $bvec = makevec($nbits, [qw(2 4 6 8 10 12 14)]);
  my $cvec = vvintersect($avec,$bvec,$nbits);

  my $clist = vec2list($cvec,$nbits);
  is_deeply($clist, [qw(2 4 6 8)], "vvintersect");

  print STDERR "test_intersect(): done.\n";
}
#test_intersect @ARGV;

##--------------------------------------------------------------
## set ops: setdiff

sub test_setdiff {
  my $nbits = shift || 8;
  my $avec = makevec($nbits, [qw(1 2 3 4 5 6 7 8 9)]);
  my $bvec = makevec($nbits, [qw(2 4 6 8 10 12 14)]);
  my $cvec = vvsetdiff($avec,$bvec,$nbits);

  my $clist = vec2list($cvec,$nbits);
  is_deeply($clist, [qw(1 3 5 7 9)], "vvsetdiff");

  print STDERR "test_setdiff(): done.\n";
}
#test_setdiff @ARGV;

##--------------------------------------------------------------
## bench: set intersection (simulate diacollo f2 acquisition)

##-- kern@plato
# l: N=631799 ; mu=9.10426575540639 ; sigma=24.0569035379271 ; min/max/median=0 / 547 / 2
# p: N=12 ; mu=479338.833333333 ; sigma=757558.357989208 ; min/max/median=0 / 2849353 / 295066
##
##-- kern@kira
# l: N=291287 ; mu=17.5979978509168 ; sigma=33.5284551256776 ; min/max/median=0 / 548 / 6
# p: N=12 ; mu=427172.333333333 ; sigma=650768.244694855 ; min/max/median=0 / 2449699 / 285423.5
##
##-- zeit@kaskade
# l: N=678642 ; mu=16.4264472284356 ; sigma=25.338426867474 ; min/max/median=0 / 400 / 7
# p: N=12 ; mu=928973.083333333 ; sigma=1683321.33617384 ; min/max/median=0 / 6235283 / 371018
##
##-- zeitungen@kaskade
# l: N=1788366 ; mu=14.3146783152889 ; sigma=21.3936860726719 ; min/max/median=0 / 414 / 7
# p: N=12 ; mu=2133323.66666667 ; sigma=4183780.06375304 ; min/max/median=1 / 15114307 / 509367

sub luniq {
  my $l = shift;
  my $x = -1;
  return [map {$_==$x ? qw() : ($x=$_)} sort {$a<=>$b} @$l];
}

use PDL;
use PDL::VectorValued;
sub bench_intersect {
  my ($n,$na,$nb,$nbits) = @_;
  $na ||= 16;
  #$nb ||= 10**7;
  $nb ||= 10000000;
  $n  ||= ($na > $nb ? $na : $nb);
  $nbits ||= 32;
  my $ap = ($n*random($na))->qsort->uniq->indx;
  my $bp = ($n*random($nb))->append($ap)->qsort->uniq->indx;
  my $av = makevec($nbits, [$ap->list]);
  my $bv = makevec($nbits, [$bp->list]);
  my ($cv,$cp,$cvp);

  $cp = $ap->v_intersect($bp);
  $cv = vvintersect($av,$bv,$nbits);
  ok(join(' ',$cp->list) eq join(' ',unpack('N*',$cv)), "intersect: pdl~vv");

  cmpthese(-3,
	    {'pdl:vv_intersect' => sub { $cp = $ap->v_intersect($bp); },
	     'bsv:vvintersect'  => sub { $cv = vvintersect($av,$bv,$nbits); },
	    });
  exit 0;
}
bench_intersect @ARGV;



##--------------------------------------------------------------
## MAIN

sub main_dummy {
  foreach $i (1..3) {
    print "--dummy($i)--\n";
  }
}
main_dummy();

