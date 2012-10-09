package Algorithm::BinarySearch::Vec;

use Exporter;
use Carp;
use AutoLoader;
use strict;
use bytes;

our @ISA = qw(Exporter);
our $VERSION = '0.01';

our ($HAVE_XS);
eval {
  require XSLoader;
  $HAVE_XS = XSLoader::load('Algorithm::BinarySearch::Vec', $VERSION);
} or do {
  $HAVE_XS = 0;
};

# Preloaded methods go here.
#require Algorithm::BinarySearch::Vec::XS::Whatever;

# Autoload methods go after =cut, and are processed by the autosplit program.

##======================================================================
## Exports
##======================================================================

our $KEY_NOT_FOUND = unpack('N',pack('N',-1));

our (%EXPORT_TAGS, @EXPORT_OK, @EXPORT);
BEGIN {
  %EXPORT_TAGS =
    (
     api   => [qw( vbsearch  vbsearch_lb  vbsearch_ub),
	       qw(vabsearch vabsearch_lb vabsearch_ub),
	      ],
     const => [qw($KEY_NOT_FOUND)],
     debug => [qw(vget vset)],
    );
  $EXPORT_TAGS{all}     = [map {@$_} @EXPORT_TAGS{qw(api const debug)}];
  $EXPORT_TAGS{default} = [map {@$_} @EXPORT_TAGS{qw(api const)}];
  @EXPORT_OK            = @{$EXPORT_TAGS{all}};
  @EXPORT               = @{$EXPORT_TAGS{default}};
}

##======================================================================
## API: Search: element-wise

##--------------------------------------------------------------
## $index = vbsearch($v,$key,$nbits)
## $index = vbsearch($v,$key,$nbits,$ilo,$ihi)
sub _vbsearch {
  my ($vr,$key,$nbits,$ilo,$ihi) = (\$_[0],@_[1..$#_]);
  $ilo = 0 if (!defined($ilo));
  $ihi = 8*length($$vr)/$nbits if (!defined($ihi));
  my ($imid);
  while ($ilo < $ihi) {
    $imid = ($ihi+$ilo) >> 1;
    if (vec($$vr,$imid,$nbits) < $key) {
      $ilo = $imid + 1;
    } else {
      $ihi = $imid;
    }
  }
  return ($ilo==$ihi) && vec($$vr,$ilo,$nbits)==$key ? $ilo : $KEY_NOT_FOUND;
}

##--------------------------------------------------------------
## $index = vbsearch_lb($v,$key,$nbits)
## $index = vbsearch_lb($v,$key,$nbits,$ilo,$ihi)
sub _vbsearch_lb {
  my ($vr,$key,$nbits,$ilo,$ihi) = (\$_[0],@_[1..$#_]);
  $ilo = 0 if (!defined($ilo));
  $ihi = 8*length($$vr)/$nbits if (!defined($ihi));
  my ($imid);
  while ($ihi-$ilo > 1) {
    $imid = ($ihi+$ilo) >> 1;
    if (vec($$vr,$imid,$nbits) < $key) {
      $ilo = $imid;
    } else {
      $ihi = $imid;
    }
  }
  return $ilo if (vec($$vr,$ilo,$nbits)==$key);
  return $ihi if (vec($$vr,$ihi,$nbits)==$key);
  return $ilo==0 ? $KEY_NOT_FOUND : $ilo;
}

##--------------------------------------------------------------
## $index = vbsearch_ub($v,$key,$nbits)
## $index = vbsearch_ub($v,$key,$nbits,$ilo,$ihi)
sub _vbsearch_ub {
  my ($vr,$key,$nbits,$ilo,$ihi) = (\$_[0],@_[1..$#_]);
  $ilo = 0 if (!defined($ilo));
  $ihi = 8*length($$vr)/$nbits if (!defined($ihi));
  my ($imid);
  while ($ihi-$ilo > 1) {
    $imid = ($ihi+$ilo) >> 1;
    if (vec($$vr,$imid,$nbits) > $key) {
      $ihi = $imid;
    } else {
      $ilo = $imid;
    }
  }
  return $ihi if (vec($$vr,$ihi,$nbits)==$key);
  return $ilo if (vec($$vr,$ilo,$nbits)>=$key);
  return $ihi;
}

##======================================================================
## API: Search: array-wise

##--------------------------------------------------------------
## \@indices = vabsearch($v,\@keys,$nbits)
## \@indices = vabsearch($v,\@keys,$nbits,$ilo,$ihi)
sub _vabsearch {
  return [map {vbsearch($_[0],$_,@_[2..$#_])} @{$_[1]}];
}


##--------------------------------------------------------------
## \@indices = vabsearch_lb($v,\@keys,$nbits)
## \@indices = vabsearch_lb($v,\@keys,$nbits,$ilo,$ihi)
sub _vabsearch_lb {
  return [map {vbsearch_lb($_[0],$_,@_[2..$#_])} @{$_[1]}];
}

##--------------------------------------------------------------
## \@indices = vabsearch_ub($v,\@keys,$nbits)
## \@indices = vabsearch_ub($v,\@keys,$nbits,$ilo,$ihi)
sub _vabsearch_ub {
  return [map {vbsearch_ub($_[0],$_,@_[2..$#_])} @{$_[1]}];
}


##======================================================================
## delegate: attempt to delegate to XS module
foreach my $func (@{$EXPORT_TAGS{api}}) {
  no warnings 'redefine';
  if ($HAVE_XS) {
    eval "\*$func = \\&Algorithm::BinarySearch::Vec::XS::$func;";
  } else {
    eval "\*$func = \\&_$func;";
  }
}


1; ##-- be happy

__END__
