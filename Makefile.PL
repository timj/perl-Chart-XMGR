use ExtUtils::MakeMaker;

# Create makefile
# Note that PDL::Options is available from CPAN independently
# of PDL
WriteMakefile(
	      'NAME'      => 'Chart::XMGR',
	      'VERSION_FROM' => 'XMGR.pm', # finds $VERSION
	      'PREREQ_PM' => { 'PDL::Options' => 0,
			       'Test::More' => 0,
			       'File::Spec' => 0,
			     },
	      'linkext'   => {LINKTYPE=>'' }, # no link needed
	      'dist'      => {'COMPRESS'=>'gzip -9f', 'SUFFIX' => 'gz',
			      'ZIP'=>'/usr/bin/zip','ZIPFLAGS'=>'-rl'},
              ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
               (ABSTRACT_FROM => 'XMGR.pm',
                AUTHOR     => 'Tim Jenness <tjenness@cpan.org>') : ()),
);

