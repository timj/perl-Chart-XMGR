#!/usr/local/bin/perl -w

# Test using simple pipes
use Test::More tests => 3;
BEGIN { use_ok( 'Chart::XMGR' ) }
use strict;

# These tests do not test return values but simply that the commands
# have executed without failing. If xmgr is not even installed
# the tests will be skipped.

my @a = (1,4,2,6,5);

$Chart::XMGR::NPIPE = 0;

# Need to put this in an eval since it fails if xmgr is not
# installed
my $xmgr = new Chart::XMGR;

SKIP: {
  # If we did not get a connection it is likely that
  # we do not have xmgr
  skip "Unable to instantiate object - assuming xmgr is not installed",2
    unless $xmgr;

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


