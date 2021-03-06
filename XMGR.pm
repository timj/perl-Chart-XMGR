package Chart::XMGR;


=head1 NAME

Chart::XMGR - object for displaying data via XMGR

=head1 SYNOPSIS

  use Chart::XMGR;

  xmgr($a, { SYMBOL => 'plus'};

  use Chart::XMGR ();

  $xmgr = new Chart::XMGR;
  $xmgr->plot($pdl);

  xmgr($pdl, { LINESTYLE => 'dotted' });

=head1 DESCRIPTION

Provides a perl/PDL interface to the XMGR plotting package. 
Can be used to plot PDLs or Perl arrays.

A simple function interface is provided that is based on the
more complete object-oriented interface.

The interface can be implemented using either anonymous pipes
or named pipes (governed by the module variable Chart::XMGR::NPIPE).
If named pipes are used ($NPIPE = 1) XMGR can be controlled via
the pipe and buttons are available for use in XMGR. If an anonymous
pipe is used XMGR will not accept button events until the pipe
has been closed.

Currently the named pipe option can not support data sets containing
3 or more columns (I haven't worked out how to do it anyway!). 
This means that only TYPE XY is supported. For anonymouse pipe
3 or more columns can be supplied along with the graph type.

The default option is to use the named pipe.

=head1 OPTIONS

The following drawing options are available:
The options are case-insensitive and minimum match.

=over 4

=item LINESTYLE

Controls the linestyle. Allowed values are none(0), solid(1),
dotted(2), dashed(3), dotdash(4). Default is solid.

=item LINECOLOUR

Controls the line colour. LINECOLOR is an allowed synonym.
Allowed values are white, black, red, green, blue, yellow,
brown, gray, violet, cyan, magenta, orange, indigo, maroon,
turqse and green4 (plus numeric equivalents: 0 to 15).
Default is black.

=item LINEWIDTH

Width of the line. Default is 1.

=item FILL

Governs whether the area inside the line is filled.
Default is none.


=item SYMBOL

Governs symbol type. 46 different types are supported (see XMGR
options for the mapping to symbol type). Basic symbol types are
available by name: none, dot, circle, square, diamond, triangleup,
triangleleft, triangledown, triangleright, triangledown, triangleright,
plus, X, star. Default is circle.

=item SYMCOLOUR

Colour of symbol. See LINECOLOUR for description of available 
values. Default is red.

=item SYMSIZE

Symbol size. Default is 1.

=item SYMFILL

Governs whether symbols are filled (1), opaque (0) or have no fill
(none(0)). Default is filled. 

=item AUTOSCALE

Set whether to autoscale as soon as set is drawn. Default is
true.

=item SETTYPE

Type of data set. Allowed values as for XMGR:
XY, XYDX, XYDY, XYDXDX, XYDYDY, XYDXDY, XYZ, XYRT.

=back


=cut

use 5.003;

use strict;
use Carp;

use IO::Pipe;
use IO::File;
use File::Spec;
use Proc::Simple;

# Options parsing
use PDL::Options;

# We are exporting a command.

#require Exporter;

use vars qw/$VERSION $Current %DEFAULTS %SYNONYMS %TRANSLATION %COLOURS
  @ISA %EXPORT_TAGS $NPIPE $COUNTER/;

use subs qw/ __curr_xmgr/;

@ISA = qw(Exporter);

%EXPORT_TAGS = (
		'Func' => [qw/
			   xmgr xmgrprint xmgrset xmgrdetach
			  /]
	       );

Exporter::export_tags('Func');

# Use Named pipe if true.
# This is the default

$NPIPE = 1;

# Amount of time we pause between starting xmgr and finding
# out whether it is still running (since we can not tell
# very easily whether a child process has started okay.
# this should spot the case where xmgr is simply not installed.
use constant PAUSE => 1;


# Need to make a named pipe if NPIPE is true
# If the mkfifo command is not available then we turn this feature off
eval "use POSIX qw/mkfifo/";
if ($@) {
  # Create dummy mkfifo command
  eval "sub mkfifo {}";
  $NPIPE = 0;
}


# Allows me to keep track of named pipe names by using
# a different one each time the object is created
$COUNTER = 0;


# $Current is a kludge to allow people to run these subs as normal
# subroutines without using the object. It is set to the current object
# and used by the xmgrlline routine to call the methods.

# Version number

$VERSION = '0.96';

# Do not worry about SIGPIPE
local $SIG{PIPE} = 'IGNORE';


# Store the default configuration options

%DEFAULTS = (
	     'LINESTYLE' => 1,
             'LINECOLOUR' => 1,
	     'LINEWIDTH' => 1,
	     'SYMBOL'    => 'circle',
	     'SYMCOLOUR' => 2,
             'SYMSIZE'   => 1,
             'SYMFILL'   => 1,
             'FILL'      => 0,
	     'AUTOSCALE' => 1,
             'SETTYPE' => 'xy'
	    );

# Store synonyms

%SYNONYMS = (
	     'LINECOLOR' => 'LINECOLOUR',
	     'SYMCOLOR'  => 'SYMCOLOUR'
	    );

# Define colours
%COLOURS = (
	    'white' => 0,
	    'black' => 1,
	    'red' => 2,
	    'green' => 3,
	    'blue' => 4,
	    'yellow' => 5,
	    'brown' => 6,
	    'gray'  => 7,
	    'violet' => 8,
	    'cyan' => 9,
	    'magenta' => 10,
	    'orange' => 11,
	    'indigo' => 12,
	    'maroon' => 13,
	    'turqse' => 14,
	    'green4' => 15
);

# Store the translation

%TRANSLATION = (
		'LINESTYLE' => {
				'none'  => 0,
				'solid' => 1,
				'dotted'=> 2,
				'dashed'=> 3,
				'ldash' =>4,
				'dotdash'=>5
			       },
		'LINECOLOUR' => { %COLOURS },
		'SYMCOLOUR'  => { %COLOURS },
		'SYMBOL'     => {
				 'none' => 0,
				 'dot'  => 1,
				 'circle'  =>  2,
				 'square'  =>  3,
				 'diamond'  =>  4,
				 'triangleup'  =>  5,
				 'triangleleft'  =>  6,
				 'triangledown'  =>  7,
				 'triangleright'  =>  8,
				 'plus'  =>  9,
				 'X'  =>  10,
				 'star'  =>  11
				},
		'SYMFILL'    => {
				 'none' => 0,
				 'filled' => 1,
				 'opaque' => 2
				}

	       );

=head1 NON-OO INTERFACE

A simplified non-object oriented interface is provided.
These routines are exported into the callers namespace by default.

=over 4

=item xmgr( args, { options } )

A simplified interface to plotting on Xmgr. 


=cut

sub xmgr {

  my $xmgr = __curr_xmgr;

  # Now send all arguments to the plot routine
  $xmgr->plot(@_);

}

=item xmgrset(set)

Select the current set (integer 0->).

=cut

sub xmgrset {
  my $xmgr = __curr_xmgr;
  my $set = shift;
  $xmgr->set($set);
}

=item xmgrdetach

Detach XMGR from the pipe. This returns control of XMGR
to the user.

=cut

sub xmgrdetach {
  my $xmgr = __curr_xmgr;
  $xmgr->detach;
}

=item xmgrprint(string)

Print arbritrary commands to XMGR. The @ symbol is prepended
to all commands and a newline is appended.

=cut

sub xmgrprint {
  my $arg = shift;
  my $xmgr = __curr_xmgr;
  $arg = $arg . "\n";
  $xmgr->prt($arg);
}


# __curr_xmgr. Returns the current XMGR object, creating 
# a new one if necessary.

sub __curr_xmgr {

  my $xmgr = $Current;

  # If it is not defined start a new XMGR
  $xmgr = new Chart::XMGR unless defined $xmgr;

  return $xmgr;
}


=back

=head1 METHODS

The following methods are available.

=over 4

=item new()

Constructor. Is used to launch the new XMGR process and
returns the object.

  $xmgr = new Chart::XMGR;

Returns undef if XMGR can not be started.

=cut


sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $xmgr = {};
  
  $xmgr->{Pipe} = undef;    # File handle object of pipe  
  $xmgr->{Attached} = 0;    # Is an XMGR process attached
  $xmgr->{Set} = 0;         # Current set number
  $xmgr->{Graph} = 0;       # Current graph
  $xmgr->{Options}  = new PDL::Options( \%DEFAULTS );
  $xmgr->{Debug} = 0;       # Debugging flag
  $xmgr->{Npipe} = undef;   # Name of named pipe
  $xmgr->{ProcSimple} = undef; # Proc::Simple object when using named pipe

  # Bless into class
  bless ($xmgr, $class);

  # Store the current object - KLUDGE alert
  $Current = $xmgr;
  
  # Launch the XMGR process
  
  if ($NPIPE) {

    # Increment counter
    $COUNTER++;

    # Create the named pipe if necessary
    $xmgr->{Npipe} = File::Spec->catfile( File::Spec->tmpdir,
					  "xmgr_fifo$$" . "_$COUNTER");


    # See if the pipe exists and or is not a pipe
    unless (-p $xmgr->npipe) {
      print "Making named pipe:".$xmgr->npipe ."..." if $xmgr->debug;
      unlink $xmgr->npipe;

      mkfifo($xmgr->npipe, 0600) || 
	croak "Couldnt create named pipe: $!"; # POSIX

      print "Done\n" if $xmgr->debug;
    }

    # Fork xmgr process
    my $proc = new Proc::Simple;
    $proc->start( 'xmgr -noask -npipe '.$xmgr->npipe . ' -timer 900' )
      or return undef;
    $proc->kill_on_destroy(1);
    print "Started xmgr with pid " . $proc->pid. "\n";
    $xmgr->{ProcSimple} = $proc;

    # Wait a second to let the child process die
    # if it is going to die
    sleep(PAUSE);
    return undef unless $proc->poll;

    # Open pipe for writing [must happen after xmgr has started]
    $xmgr->{Pipe} = new IO::File;
    $xmgr->{Pipe}->open("> ". $xmgr->npipe) or
      die "Can't open named pipe: $!";
    print "Opened named pipe\n" if $xmgr->debug;

  } else {

    # Set up a child handler. This is asynchronous but hopefully
    # will be able to catch the case where XMGR is not installed.
    local $SIG{CHLD} = sub { $xmgr->{Pipe} = undef; wait; };

    # An anonymous pipe
    $xmgr->{Pipe} = new IO::Pipe;

    # We need to eval because if the writer fails to exec
    # we end up with a perl process hanging on if we have ourselves
    # been called with eval - this confuses Test::More so that we
    # get two endings from our test scripts. We can not use eval to
    # tell whether the exec failed from the parent
    my $parent = $$;
    eval {
      $xmgr->{Pipe}->writer('xmgr -pipe -noask');
    };
    if ($$ != $parent) {
      # left over child. Should never happen if the exec worked.
      # (ie xmgr is installed)
      # need to exec ourselves
      exec "$^X -e 'exit'";
    }

    # Wait a second to let the child process die
    # but we do not officially know the pid of the child
    # process. We can use a SIGCHLD but that is asynchronous
    # if it is going to die
    sleep(PAUSE);
    return undef unless $xmgr->{Pipe};

  }

  return undef unless $xmgr->{Pipe};
  $xmgr->{Pipe}->autoflush;
  $xmgr->{Attached} = 1;

  # Configure the options
  $xmgr->{Options}->synonyms( \%SYNONYMS );
  $xmgr->{Options}->translation( \%TRANSLATION );


  # Set a default title
  $xmgr->prt('TITLE "Perl->XMGR"');

  return $xmgr;
}


=item pipe

Return file handle (of type IO::Pipe) associated with external XMGR process.

=cut

sub pipe {
  my $self = shift;
  if (@_) { $self->{Pipe} = shift;}
  return $self->{Pipe};
}

=item opt()

Return options object associated with XMGR object.

=cut

sub opt {
  my $self = shift;
  if (@_) { $self->{Options} = shift;}
  return $self->{Options};
}

=item npipe()

Returns name of pipe associated with object.

=cut

sub npipe {
  my $self = shift;
  if (@_) { $self->{Npipe} = shift;}
  return $self->{Npipe};
}


=item attached()

Returns whether an XMGR process is currently attached to the object.
Can also be used to set the state.

=cut

sub attached {
  my $self = shift;
  if (@_) { $self->{Attached} = shift;}
  return $self->{Attached};
}


=item set()

Returns (or sets) the current set.

=cut

sub set {
  my $self = shift;
  if (@_) { $self->{Set} = shift;}
  return $self->{Set};
}

=item graph()

Returns (or sets) the current graph.

=cut

sub graph {
  my $self = shift;
  if (@_) { $self->{Graph} = shift;}
  return $self->{Graph};
}


=item debug()

Turns the debug flag on or off. If on (1) all commands sent
to XMGR are also printed to STDOUT.

Default is false.

=cut

sub debug {
  my $self = shift;
  if (@_) { $self->{Debug} = shift;}
  return $self->{Debug};
}



=item prt(text)

Method to prt Xmgr commands to the attached XMGR process.
Carriage returns are appended. '@' symbols are prepended
where necessary (needed for anonymous pipes, not for named
pipes).

=cut

sub prt {

  my $self = shift;

  my @args = @_;   # In case we are parsing in a read-only variable

  # If names pipe then just append newline
  if ($NPIPE) {
    map { $_ = "$_\n" } @args;
  } else {
    # Normal pipe so need the @ symbol as well
    map { $_ = "\@$_\n" } @args; 
  }

  print map { "XMGR: $_" } @args if $self->debug;

  my $PIPE = $self->pipe;

  foreach (@args) {
    print $PIPE "$_";
  }

}

=item prt_data (data)

Print numbers to the pipe. No @ symbol is prepended.
For named pipes we must use the POINT command.
For anonymous pipes the data is just sent as is (so multiple
column can be supplied). 

=cut

sub prt_data {

  my $self = shift;

  my @args = @_;   # In case we are parsing in a read-only variable
  my $set = $self->set;

  # For named pipes need to process the data some more
  if ($NPIPE) {
    foreach (@args) {
      next if $_ eq '&';
      my @bits = split(/ /, $_);
      
      # Only first two bits are allowed for POINT
      my $data = join(',',@bits[0..1]);
      $_ = "s$set POINT $data\n";
    }
  } else {
    # Just send the data with a carriage return
    map { $_ .= "\n" } @args;
  }

  print map { "XMGR: $_" } @args if $self->debug;

  my $PIPE = $self->pipe;

  foreach (@args) {
     print $PIPE "$_";
  }


}


=item select_graph

Selects the current graph in XMGR.

=cut

sub select_graph {
  my $self = shift;
  my $graph = $self->graph;
  $self->prt("WITH g$graph");
}




=item plot($pdl, $pdl2, ..., $hash)

Method to plot XY data. Multiple arguments are allowed (in addition
to the options hash). This routine plots the supplied data as the
currently selected set on the current graph. 

The interpretation of each input argument depends on the set type
(specified as an option: SETTYPE). For example, 
3 columns can be translated as XYDY, XYDX or XYZ. No check is made
that the number of arguments matches the selected type.

Array references can be substituted for PDLs.

The options hash is assumed to be the last argument.

   $xmgr->plot(\@x, \@y, { LINECOL => 'red' } );
   $xmgr->plot($pdl);


=cut

sub plot { 

  my ($optref);

  my $self = shift;

  croak 'Usage: plot($pdl, [$hash])' 
        if (scalar(@_) < 0);
  
  # Read options hash from command line.
  # Assumed to be last arg (if its a hash)


  if (ref($_[-1]) eq 'HASH') {
    $optref = pop(@_);
  } else {
    $optref = {};
  }

  # Take a local copy of the args
  my @input = @_;

  # Process the user options and combine with defaults
  my $merged = $self->opt->options($optref);

  # Retrieve set number
  my $set = $self->set;

  # Select the current graph
  $self->select_graph;

  # First thing we need to do is kill the current set in XMGR
  $self->killset;

  # Then need to set the target of this data set
  $self->prt("TARGET s$set");

  # Now need to set the settype. This is contained in the options
  # hash.
  $self->prt("TYPE $$merged{SETTYPE}");


  # First thing we need to do is check the dimensions of the
  # first argument (if it is a PDL).
  # If it is 2D then we want to loop
  my $nargs = $#input;

  # Found out how many numbers in the first arg
  my $npts;
  if (ref($input[0]) eq 'ARRAY') {
    $npts = $#{$input[0]};
  } elsif (UNIVERSAL::isa($input[0],'PDL')) {
    $npts = $input[0]->clump(-1)->nelem - 1; # Match perl start at 0
  } else {
    croak 'Cant work out how to display data: Not PDL or Array ref';    
  }

  # Loop over each point in arg and send a data point to XMGR
  for (my $i = 0; $i <= $npts; $i++ ) {

    # Somewhere to store the current value
    my @val = ();

    # Read element from each arg
    for (my $j = 0; $j <= $nargs; $j++) {
      
      push (@val, $i) if $nargs == 0;

      my $val;
      my $cpt = $input[$j];

      # An ARRAY reference
      if (ref($cpt) eq 'ARRAY') {
        if ($i <= $#{$cpt}) {
	  $val = ${$cpt}[$i];
        } else {
	  $val = 0;
	}
      
      # A PDL
      } elsif (UNIVERSAL::isa($cpt,'PDL')) {
        # Check that we are in range
        my $num = $cpt->clump(-1)->nelem;

        if ($i <= $cpt->clump(-1)->nelem - 1) {
	  $val = $cpt->clump(-1)->at($i);
	} else {
	  $val = 0.0;
	}

      # None of the above
      } else {
	$val = 0;
      }

      # Store $val
      push ( @val, $val);

    }

    # Now we have the list. Create a string and send to XMGR
    my $data = join(' ',@val); 
#    my $string = "\@s$set POINT $data"; 
#    $self->prt($string);
    $self->prt_data("$data");

  } 

  # Close the set (if not a named pipe)
  $self->prt_data('&') unless $NPIPE;

  # Send the options hash
  $self->send_options($merged);

  # Update the display
  $self->redraw;

}




=item send_options(hashref)

Process the options hash and send to XMGR.
This sends the options for the current set.

=cut


sub send_options {
  my $self = shift;
  
  my $optref = shift;

  my $set = $self->set;

  # select current graph
  $self->select_graph;

  # Somewhere to put the options
  my @XMGR = ();

  # Loop through the keys
  foreach my $key (%$optref) {

    if ($key eq 'LINESTYLE') {
      push(@XMGR, "s$set LINESTYLE $$optref{$key}");
    } elsif ($key eq 'LINECOLOUR') {
      push(@XMGR, "s$set COLOR $$optref{$key}");
    } elsif ($key eq 'LINEWIDTH') {
      push(@XMGR, "s$set LINEWIDTH $$optref{$key}");
    } elsif ($key eq 'SYMBOL') {
      push(@XMGR, "s$set SYMBOL $$optref{$key}");
    } elsif ($key eq 'FILL') {
      push(@XMGR, "s$set FILL $$optref{$key}");
    } elsif ($key eq 'SYMSIZE') {
      push(@XMGR, "s$set SYMBOL SIZE $$optref{$key}");
    } elsif ($key eq 'SYMCOLOUR') {
      push(@XMGR, "s$set SYMBOL COLOR $$optref{$key}"); 
    } elsif ($key eq 'SYMFILL') {
      push(@XMGR, "s$set SYMBOL FILL $$optref{$key}");
    }

    if ($key eq 'AUTOSCALE') {
      if ($$optref{$key}) {
	$self->autoscale;
      }
    }



  }

  $self->prt(@XMGR);
}



=item redraw()

Forces XMGR to redraw.

=cut

sub redraw {
  my $self = shift;
  $self->prt('redraw');
}


=item killset([setnum])

Kill a set.
If no argument is specified the current set is killed; else
the specified set (integer greater than or equal to 0) is killed.

=cut

sub killset {
  my $self = shift;

  my $set = $self->set;
  if (@_) { $set = shift; }

  $self->prt("KILL s$set");
}


=item autoscale()

Instruct XMGR to autoscale.

=cut

sub autoscale {
  my $self = shift;
  $self->prt('autoscale');
}

=item autoscale_on([set])

Autscale on the specified set (default to current set).

=cut

sub autoscale_on {
  my $self = shift;
  my $set = $self->set;

  if (@_) { $set = shift; }  
  $self->prt("autoscale on s$set");
}

=item world(xmin, xmax, ymin, ymax)

Set the world coordinates.

=cut

sub world {
  my $self = shift;
  my ($xmin, $xmax, $ymin, $ymax) = @_;
 
  $self->prt("WORLD $xmin, $ymin, $xmax, $ymax");
#  $self->prt("WORLD XMAX $xmax");
#  $self->prt("WORLD YMIN $ymin");
#  $self->prt("WORLD XMAX $ymax");

}


=item viewport(xmin, xmax, ymin, ymax)

Set the current graphs viewport (where the current graphi
is displayed).

=cut

sub viewport {
  my $self = shift;
  my ($xmin, $xmax, $ymin, $ymax) = @_;
 
  $self->prt("VIEW $xmin, $ymin, $xmax, $ymax");
#  $self->prt("VIEW XMAX $xmax");
#  $self->prt("VIEW YMIN $ymin");
#  $self->prt("VIEW XMAX $ymax");

}

=item graphtype(type)

Set the graphtype. Allowed values are: 'XY', 'BAR', 'HBAR',
'STACKEDBAR', 'STACKEDHBAR', 'LOGX', 'LOGY', 'LOGXY', 'POLAR',
'SMITH'

=cut

sub graphtype {
  my $self = shift;
  my $type = shift;
  my $graph = $self->graph;
  $self->prt("g$graph TYPE $type");
}


=item configure(hash)

Configure the current set.

  $xmgr->configure(SYMBOL=>1, LINECOLOUR=>'red');

=cut

sub configure {
  my $self = shift;

  my %hash = @_;

  # Now parse the options and return the converted values
  # Make sure we only return the requested parameters.

  $self->opt->full_options(0); # Turn off full options

  my $answer = $self->opt->options(\%hash);
  $self->send_options($answer);

  # Reset
  $self->opt->full_options(1);

  # Redraw
  $self->redraw;
}


=item detach()

Close the pipe without asking XMGR to die.
This can be used if you want to leave XMGR running after the
object is destroyed. Note that no more messages can be sent to
the XMGR process associated with this object.

=cut

sub detach {
  my $self = shift;
  if ($self->attached) {
    close ($self->pipe) or carp "Cant release XMGR process: $!";
  }
  
  # Update the object state so that we know that XMGR is no longer running
  $self->attached(0);  
}



=item DESTROY

Destructor for object. Sends the 'exit' message to the XMGR process.
This will fail silently if the pipe is no longer open. (eg if the
detach() method has been called.

=cut

sub DESTROY {

  my $self = shift;

  # Shut down XMGR (if it was running)
  if (defined $self->pipe) {
    $self->prt("exit\n") if $self->pipe->opened;

    # Close the pipe
    if ($self->attached) {
      $self->pipe->close or carp "Cant stop XMGR process: $!";
    }
  }

  # Remove the FIFO
  unlink $self->npipe if defined $self->npipe;

}

=back

=head1 EXAMPLE

An example program may look like this:

  use Chart::XMGR;
  use PDL;

  $a = pdl( 1,4,2,6,5);
  $xmgr = new Chart::XMGR;
  $xmgr->plot($a, { SYMBOL => 3, 
                    LINECOL => 'red', 
                    LINESTYLE => 2
                    SYMSIZE => 1 }
              );

  $xmgr->configure(SYMCOL => 'green');
  $xmgr->detach;

If PDL is not available, then arrays can be used:

  use Chart::XMGR
  
  @a = ( 1,4,2,6,5 );
  $xmgr = new Chart::XMGR;
  $xmgr->plot(\@a, { SYMBOL => 3, 
                    LINECOL => 'red', 
                    LINESTYLE => 2
                    SYMSIZE => 1 }
              );

  $xmgr->configure(SYMCOL => 'green');
  $xmgr->detach;


=head1 XMGR (Grace)

The XMGR home page is at http://plasma-gate.weizmann.ac.il/Xmgr/ This
modules is designed to be used with XMGR version 4 (tested on v4.1.2).
This module will probably not work with GRACE (XMGR version 5).

=head1 REQUIREMENTS

The PDL::Options module is required. This is available as part of the
PDL distribution (http://pdl.perl.org) or separately in the PDL 
directory on CPAN.

=head1 NOTES

For versions 0.90 and earlier this module was known by the
name Graphics::XMGR (not on CPAN).

=head1 AUTHOR

Copyright (C) Tim Jenness 1998,1999 (t.jenness@jach.hawaii.edu).  All
rights reserved. This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.


=cut

1;
