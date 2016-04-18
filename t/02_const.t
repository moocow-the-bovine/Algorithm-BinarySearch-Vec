# -*- Mode: CPerl -*-
# t/02_const.t; test constants

use Test::More tests => 2;
use Algorithm::BinarySearch::Vec qw(:all);
no warnings 'portable';

ok($KEY_NOT_FOUND >= 0xffffffff, "KEY_NOT_FOUND >= 32-bit max");
SKIP: {
  skip("quad support unavailable", 1) if (!$Algorithm::BinarySearch::Vec::HAVE_QUAD);
  ok($KEY_NOT_FOUND >= 0xffffffffffffffff, "KEY_NOT_FOUND >= 64-bit max");
}

# end of t/02_const.t
