# -*- perl -*-
# t/001-new.t - check module loading and create testing directory
use strict;
use warnings;

use Test::More;
use Carp;
use Cwd;
use File::Path ( qw| make_path remove_tree | );
use File::Spec;
use File::Temp ( qw| tempdir |);
use Data::Dump ( qw| dd pp | );

BEGIN { use_ok( 'Test::Against::Commit' ); }

#my $tdir = tempdir(CLEANUP => 1);
#my $toptdir = tempdir();
my $cwd = cwd();
my $time = time();
my $tdir = File::Spec->catdir($cwd, $time);
if (-d $tdir) {
    my $removed_count = remove_tree($tdir,
        { verbose => 1, error  => \my $err_list, safe => 1, });
}
make_path($tdir, { mode => 0755 })
    or croak "Unable to create $tdir for testing";

my $self;

# Error conditions for new() which can be tested by non-author users
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
    eval { $self = Test::Against::Commit->new({ project => 'goto-fatal', commit => 'blead' }); };
    like($@, qr/Hash ref must contain 'application_dir' element/,
        "new: Got expected error message; 'application_dir' element absent");
}

{
    local $@;
    eval { $self = Test::Against::Commit->new({ application_dir => $tdir, project => 'goto-fatal' }); };
    like($@, qr/Hash ref must contain 'commit' element/,
        "new: Got expected error message; 'commit' element absent");
}

{
    local $@;
    eval { $self = Test::Against::Commit->new({ application_dir => $tdir, commit => 'blead' }); };
    like($@, qr/Must supply name for project/,
        "new: Got expected error message; 'project' element absent");
}

{
    local $@;
    my $phony_dir = '/foo';
    eval { $self = Test::Against::Commit->new({
           application_dir => $phony_dir,
           commit => 'blead',
           project => 'goto-fatal',
       });
    };
    like($@, qr/Could not locate application directory $phony_dir/,
        "new: Got expected error message; 'application_dir' not found");
}

{
    my $application_dir = $tdir;
    my $project = 'goto-fatal';
    my $commit = 'blead';
    my %verified = ();
    # paths_needed:
    my $project_dir = File::Spec->catdir($application_dir, $project);
    my $commit_dir = File::Spec->catdir($project_dir, $commit);
    my $testing_dir = File::Spec->catdir($commit_dir, 'testing');
    my $results_dir = File::Spec->catdir($commit_dir, 'results');

    my @dirs_needed = ( $project_dir, $commit_dir, $testing_dir, $results_dir );
    for my $dir ( @dirs_needed ) {
        unless (-d $dir) {
            make_path($dir, { mode => 0755 })
                or croak "Unable to create $dir for testing";
        }
    }

    $self = Test::Against::Commit->new( {
        application_dir         => $tdir,
        project                 => $project,
        commit                  => $commit,
    } );
    ok($self, "new() returned true value");
    isa_ok ($self, 'Test::Against::Commit');

    my $top_dir = $self->get_application_dir;
    is($top_dir, $tdir, "Located top-level directory $top_dir");

#    for my $dir ( qw| testing results | ) {
#        my $fdir = File::Spec->catdir($top_dir, $dir);
#        ok(-d $fdir, "Located $fdir");
#    }

    $project_dir = $self->get_project_dir;
    $commit_dir = $self->get_commit_dir;
    $testing_dir = $self->get_testing_dir;
    $results_dir = $self->get_results_dir;
    ok(-d $project_dir, "Got project directory: $project_dir");
    ok(-d $commit_dir, "Got commit directory: $commit_dir");
    ok(-d $testing_dir, "Got testing directory: $testing_dir");
    ok(-d $results_dir, "Got results directory: $results_dir");

    is($self->get_commit(), $commit, "Got expected commit");

#    {
#        local $@;
#        eval { $self->get_commit_dir(); };
#        like($@, qr/commit directory has not yet been defined/,
#            "Got exception for premature get_commit_dir()");
#    }
#
#    {
#        local $@;
#        eval { $self->get_bin_dir(); };
#        like($@, qr/bin directory has not yet been defined/,
#            "Got exception for premature get_bin_dir()");
#    }
#
#    {
#        local $@;
#        eval { $self->get_lib_dir(); };
#        like($@, qr/lib directory has not yet been defined/,
#            "Got exception for premature get_lib_dir()");
#    }
#
#    {
#        local $@;
#        eval { $self->get_this_perl(); };
#        like($@, qr/bin directory has not yet been defined/,
#            "No bin dir, hence no possibility of installed perl");
#    }
#
#    {
#        local $@;
#        eval { $self->get_this_cpanm(); };
#        like($@, qr/location of cpanm has not yet been defined/,
#            "Got exception for premature get_this_cpanm()");
#    }
#
#    {
#        local $@;
#        eval { $self->get_cpanm_dir(); };
#        like($@, qr/cpanm directory has not yet been defined/,
#            "Got exception for premature get_cpanm_dir()");
#    }
}

done_testing();
chdir $cwd;

END {
    my $removed_count = remove_tree($tdir,
        { verbose => '', error  => \my $err_list, safe => 1, }
    );
}
