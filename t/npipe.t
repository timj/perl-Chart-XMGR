#!/usr/local/bin/perl -w

# This test is the same as simple.t except that a named pipe is used.
use Test::More tests => 3;
use strict;

BEGIN { use_ok( 'Chart::XMGR' ) };

$Chart::XMGR::NPIPE = 1;

my $xmgr = new Chart::XMGR;

use Data::Dumper;
print $xmgr;
#exit;

SKIP: {
  # If we did not get a connection it is likely that
  # we do not have xmgr
  skip "Unable to instantiate object - assuming xmgr is not installed",2
    unless $xmgr;
  print "EEk\n";
  my @a = (1,4,2,6,5);
  $xmgr->plot(\@a, { SYMBOL => 3, LINECOL => 'red', LINESTYLE => 2, FILL=>0,
		     SYMSIZE=>1 });

  $xmgr->configure(SYMCOL=>'green');

  $xmgr->prt('s0 POINT 2,3');


  @a = (0.1,0.3,0.1,0.5);
  my @b = (4,6,3,5);
  my @c = (2,2,4,1);

  $xmgr->set(1);

  #$xmgr->prt('@s1 type xydx');

  $xmgr->plot(\@b, \@c);

  $xmgr->set(0);

  ok(1);

  $xmgr->prt("sleep 2");
  $xmgr->plot(\@c, \@b, {settype => 'xy', linewid => 3.4});

  $xmgr->detach;
  ok(1);
}
