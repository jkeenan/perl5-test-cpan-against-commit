# -*- perl -*-
# t/001-new.t - check module loading and create testing directory
use strict;
use warnings;

use Test::More;
use File::Temp ( qw| tempdir |);
#use Data::Dump ( qw| dd pp | );

BEGIN { use_ok( 'Test::Against::Commit' ); }

my $tdir = tempdir(CLEANUP => 1);
my $self;

{
    local $@;
    eval { $self = Test::Against::Commit->new([]); };
    like($@, qr/Argument to constructor must be hashref/,
        "new: Got expected error message for non-hashref argument");
}

{
    local $@;
    eval { $self = Test::Against::Commit->new(); };
    like($@, qr/Argument to constructor must be hashref/,
        "new: Got expected error message for no argument");
}

{
    local $@;
    eval { $self = Test::Against::Commit->new({ commit => 'blead' }); };
    like($@, qr/Hash ref must contain 'application_dir' element/,
        "new: Got expected error message; 'application_dir' element absent");
}

{
    local $@;
    eval { $self = Test::Against::Commit->new({ application_dir => $tdir }); };
    like($@, qr/Hash ref must contain 'commit' element/,
        "new: Got expected error message; 'commit' element absent");
}

{
    local $@;
    my $phony_dir = '/foo';
    eval { $self = Test::Against::Commit->new({
           application_dir => $phony_dir,
           commit => 'blead',
       });
    };
    like($@, qr/Could not locate application directory $phony_dir/,
        "new: Got expected error message; 'application_dir' not found");
}

#$self = Test::Against::Commit->new( {
#    application_dir         => $tdir,
#    commit                  => 'blead',
#} );
#isa_ok ($self, 'Test::Against::Commit');

{
    my $application_dir = File::Spec->catdir($ENV{HOMEDIR}, 'var', 'tac');
    ok(-d $application_dir, "Located application directory $application_dir");
    my $commit = 'blead';

    $self = Test::Against::Commit->new( {
        application_dir => $application_dir,
        commit          => $commit,
    } );
    ok($self, "new() returned true value");
    isa_ok ($self, 'Test::Against::Commit');
}

#my $top_dir = $self->get_application_dir;
#is($top_dir, $tdir, "Located top-level directory $top_dir");
#
#for my $dir ( qw| testing results | ) {
#    my $fdir = File::Spec->catdir($top_dir, $dir);
#    ok(-d $fdir, "Located $fdir");
#}
#my $testing_dir = $self->get_testing_dir;
#my $results_dir = $self->get_results_dir;
#ok(-d $testing_dir, "Got testing directory: $testing_dir");
#ok(-d $results_dir, "Got results directory: $results_dir");
#
#can_ok('Test::Against::Commit', 'configure_build_install_perl');
#can_ok('Test::Against::Commit', 'fetch_cpanm');

done_testing();
