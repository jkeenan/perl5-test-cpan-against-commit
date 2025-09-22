# -*- perl -*-
# t/003-prepare-testing-directories.t
# Check module loading, creation of testing directories
# Does not presume 'git' or installation of perl executable
use strict;
use warnings;

use Test::More;
my $installed_perl;
BEGIN {
    $installed_perl = $ENV{PERL_AUTHOR_TESTING_INSTALLED_PERL};
    no warnings 'uninitialized';
    unless (-x $installed_perl) {
        plan skip_all=> "Could not locate plausible installed perl to use in testing";
    }
}

use Carp;
use Capture::Tiny ( qw | capture_stdout | );
#use Data::Dump ( qw| dd pp | );

BEGIN { use_ok( 'Test::Against::Commit' ); }

# We can conduct testing with a real installed perl executable provided that
# we can locate one at a path like this:
#   /application_dir/project_dir/install_dir/bin/perl
# and reverse engineer the arguments for new().

# Call:
# PERL_AUTHOR_TESTING_INSTALLED_PERL=<path> \
#   prove -vb t/003-prepare-testing-directories.t

my $stdout = capture_stdout {
    system(qq{ $installed_perl -v | head -2 | tail -1 })
        and croak "Unable to call 'perl -v'";
};
chomp $stdout;
like($stdout,
    qr/This\sis\sperl\s5,\sversion\s\d\d,\ssubversion\s\d/, 
    "Got 'perl -v' output"
);

my ($application_dir, $project, $install);
($application_dir, $project, $install) =
    $installed_perl =~ m{^(.*?) \/ ([^/]+) \/ ([^/]+) \/ testing \/ bin \/ perl$}x;

my $self = Test::Against::Commit->new( {
    application_dir         => $application_dir,
    project                 => $project,
    install                 => $install,
} );
ok($self, "new() returned true value");
isa_ok($self, 'Test::Against::Commit');

my ($top_dir, $project_dir, $install_dir, $testing_dir);

$top_dir = $self->get_application_dir;
is($top_dir, $application_dir, "Located top-level directory $top_dir");

$project_dir = $self->get_project_dir;
ok(-d $project_dir, "Got project directory: $project_dir");

$install_dir = $self->get_install_dir;
ok(-d $install_dir, "Got install directory: $install_dir");

$testing_dir = $self->get_testing_dir;
ok(-d $testing_dir, "Got testing directory: $testing_dir");

#say STDERR "CCC:";
#pp($self);

ok($self->prepare_testing_directory(),
    "prepare_testing_directory() returned true value");

#say STDERR "DDD:";
#pp($self);

my $bin_dir = $self->get_bin_dir();
ok(-d $bin_dir, "Located bin_dir at $bin_dir");

my $lib_dir = $self->get_lib_dir();
ok(-d $lib_dir, "Located lib_dir at $lib_dir");

my $this_perl = $self->get_this_perl();
ok(-x $this_perl, "Located executable perl at $this_perl");

#{
#    local $@;
#    eval { $self->get_this_cpanm(); };
#    like($@, qr/location of cpanm has not yet been defined/,
#        "Got exception for premature get_this_cpanm()");
#}
#
#{
#    local $@;
#    eval { $self->get_cpanm_dir(); };
#    like($@, qr/cpanm directory has not yet been defined/,
#        "Got exception for premature get_cpanm_dir()");
#}

done_testing();
