package Test::Against::Commit::Salvage;
use strict;
use 5.14.0;
our $VERSION = '0.15';
our @ISA = ('Test::Against::Commit');
use Carp;
#use Cwd;
use File::Basename ( qw| dirname | );
#use File::Path ( qw| make_path | );
use File::Spec;
#use File::Temp ( qw| tempdir tempfile | );
use Data::Dump ( qw| dd pp | );
use Test::Against::Commit;

=head1 NAME

Test::Against::Commit::Salvage - Parse a F<cpanm> F<build.log> when C<run_cpanm()> exited prematurely.

=head1 SYNOPSIS

TK

=head1 DESCRIPTION

TK

=head1 METHODS

=head2 C<new()>

=over 4

=item * Purpose

Test::Against::Commit::Salvage constructor.  Substitutes for
C<Test::Against::Commit::new()>.

=item * Arguments

Reference to a hash with 3 required elements and 1 optional element.

=over 4

=item * C<path_to_cpanm_build_log>

String holding absolute path to an already existing F<cpanm> build log file or
to a symlink to such a file.  Required.

=item * C<title>

String will be used to compose the name of project-specific output files.
Required.  Should be the same string that was originally passed to
<Test::Against::Commit::run_cpanm()>.

=item * C<results_dir>

String holding absolute path to an already existing directory holding results
for one, Test-Against-Commit-utilizing project.  If, for example, the top
level application directory for a given project is C<$HOMEDIR/tacprojects/>
and the commit name for this project is C<23ae7f95ea>, then the key-value pair
for C<results_dir> would be:

    results_dir => "$HOMEDIR/tacprojects/results/23ae7f95ea",

Underneath C<results_dir> there should already have been created the following
subdirectories:

    $HOMEDIR/tacprojects/results/23ae7f95ea/buildlogs/
    $HOMEDIR/tacprojects/results/23ae7f95ea/analysis/
    $HOMEDIR/tacprojects/results/23ae7f95ea/storage/

Assuming that an earlier run of C<Test::Against::Commit::run_cpanm()> has
installed CPAN modules in C<$HOMEDIR/tacprojects/testing/23ae7f95ea/> and has
created a symlink to a build log in
C<$HOMEDIR/tacprojects/testing/23ae7f95ea/.cpanm>

=item * C<verbose>

Extra information provided on STDOUT.  Optional; defaults to being off;
provide a Perl-true value to turn it on.  Scope is limited to this method.

=back

=item * Return Value

Test::Against::Commit::Salvage object.

=item * Comment

Once the object has been created, the user should be able to call the following Test::Against::Commit methods on it:

    gzip_cpanm_build_log
    analyze_cpanm_build_logs
    analyze_json_logs
    get_cpanm_dir

=back

=cut

sub new {
    my ($class, $args) = @_;
    croak "Must supply hash ref as argument"
        unless ( ( defined $args ) and ( ref($args) eq 'HASH' ) );
    my $verbose = delete $args->{verbose} || '';
    my $data = {};
    for my $el ( qw|
        path_to_cpanm_build_log
        title
        results_dir
    | ) {
        croak "Need '$el' element in arguments hash ref"
            unless exists $args->{$el};
    }
    my $blp = $args->{path_to_cpanm_build_log};
    croak "Could not locate cpanm build.log at '$blp'" unless (-l $blp or -f $blp);

    unless (defined $args->{title} and length $args->{title}) {
        croak "Must supply value for 'title' element";
    }
    $data->{title} = $args->{title};

    unless (defined $args->{results_dir} and -d $args->{results_dir}) {
        croak "Could not locate results_dir $args->{results_dir}";
    }

#    croak "'$args->{perl_version}' does not conform to pattern"
#        unless $args->{perl_version} =~ m/$data->{perl_version_pattern}/;
#    $data->{perl_version} = $args->{perl_version};

    # If $blp is a symlink, then we need to be able to -f its target.
    # Once we've found its target, or if it's not a symlink, we need to parse
    # its path in order to establish cpanm_dir:
    #     .../.cpanm/work/1234567890.12345/build.log
    # If we can't do any of this, we croak.

    my ($cpanm_dir, $real_log);
    if (! -l $blp) {
#        # If we've supplied the full path to the build.log file itself
#        say "Value for 'path_to_cpanm_build_log' is not a symlink" if $verbose;
#        my ($volume,$directories,$file) = File::Spec->splitpath($blp);
#        my @directories = File::Spec->splitdir($directories);
#        pop @directories if $directories[-1] eq '';
#        my $partial = join('/' => @directories[-3 .. -1]);
#        unless(
#            ($directories[-1] =~ m/^\d+\.\d+$/) and
#            ($directories[-2] eq 'work') and
#            ($directories[-3] eq '.cpanm')
#        ) {
#            my $msg = "build.log file not found in directories ending $partial";
#            croak $msg;
#        }
#        else {
#            say "Found directories ending $partial" if $verbose;
#            $cpanm_dir = File::Spec->catdir(@directories[0 .. ($#directories - 2)]);
#            say "cpanm_dir: $cpanm_dir" if $verbose;
#            my $possible_symlink = File::Spec->catfile($cpanm_dir, 'build.log');
#            say "possible_symlink: $possible_symlink" if $verbose;
#            if (-l $possible_symlink) {
#                unlink $possible_symlink or croak "Unable to remove symlink $possible_symlink";
#            }
#            # Keep TAD::gzip_cpanm_build_log() happy
#            symlink($blp, $possible_symlink) or croak "Unable to create symlink $possible_symlink";
#        }
    }
    else {
        # If we've only supplied the full path to the symlink to the build.log
        say "Value for 'path_to_cpanm_build_log' is a symlink" if $verbose;
        $real_log = readlink($blp);
        croak "Could not locate target of build.log symlink" unless (-f $real_log);
        $cpanm_dir = dirname($blp);
        say "cpanm_dir: $cpanm_dir" if $verbose;
    }

    # Given a verified cpanm_dir and build.log, we should be able to parse the
    # directory to calculate the 'commit' and then the other results
    # directories we'll need.
    # /home/jkeenan/var/tac/testing/23ae7f95ea/.cpanm/build.log

    #my ($volume,$directories,$file) = File::Spec->splitpath($real_log);
    my ($volume,$directories,$file) = File::Spec->splitpath($blp);
    #pp $directories;
    my @dirs = File::Spec->splitdir($directories);
    my $popped = pop @dirs if $dirs[-1] eq '';
    my $shifted = shift @dirs if $dirs[0] eq '';
    #pp \@dirs;
    my $commit = $dirs[-2];
    #pp $commit;

    my $vresults_dir = File::Spec->catdir($args->{results_dir}, $commit);
    my $buildlogs_dir = File::Spec->catdir($vresults_dir, 'buildlogs');
    my $analysis_dir = File::Spec->catdir($vresults_dir, 'analysis');
    my $storage_dir = File::Spec->catdir($vresults_dir, 'storage');
    for my $dir ( $vresults_dir, $buildlogs_dir, $analysis_dir, $storage_dir ) {
        croak "Could not locate $dir" unless -d $dir;
    }

    my %load = (
        cpanm_dir           => $cpanm_dir,
        vresults_dir        => $vresults_dir,
        buildlogs_dir       => $buildlogs_dir,
        analysis_dir        => $analysis_dir,
        storage_dir         => $storage_dir,
    );
    $data->{$_} = $load{$_} for keys %load;

    return bless $data, $class;
}

1;

#sub new {
#    my ($class, $args) = @_;
#    croak "Must supply hash ref as argument"
#        unless ( ( defined $args ) and ( ref($args) eq 'HASH' ) );
#    my $verbose = delete $args->{verbose} || '';
#    my $data = { perl_version_pattern => $PERL_VERSION_PATTERN };
#    for my $el ( qw|
#        path_to_cpanm_build_log
#        perl_version
#        title
#        results_dir
#    | ) {
#        croak "Need '$el' element in arguments hash ref"
#            unless exists $args->{$el};
#    }
#    my $blp = $args->{path_to_cpanm_build_log};
#    croak "Could not locate cpanm build.log at '$blp'" unless (-l $blp or -f $blp);
#        # Check for validity of this value down below
#        #$data->{path_to_cpanm_build_log} = $blp;
#
#    unless (defined $args->{title} and length $args->{title}) {
#        croak "Must supply value for 'title' element";
#    }
#    $data->{title} = $args->{title};
#
#    croak "'$args->{perl_version}' does not conform to pattern"
#        unless $args->{perl_version} =~ m/$data->{perl_version_pattern}/;
#    $data->{perl_version} = $args->{perl_version};
#
#    # If $blp is a symlink, then we need to be able to -f its target.
#    # Once we've found its target, or if it's not a symlink, we need to parse
#    # its path in order to establish cpanm_dir:
#    #     .../.cpanm/work/1234567890.12345/build.log
#    # If we can't do any of this, we croak.
#
#    my ($cpanm_dir);
#    if (! -l $blp) {
#        # If we've supplied the full path to the build.log file itself
#        say "Value for 'path_to_cpanm_build_log' is not a symlink" if $verbose;
#        my ($volume,$directories,$file) = File::Spec->splitpath($blp);
#        my @directories = File::Spec->splitdir($directories);
#        pop @directories if $directories[-1] eq '';
#        my $partial = join('/' => @directories[-3 .. -1]);
#        unless(
#            ($directories[-1] =~ m/^\d+\.\d+$/) and
#            ($directories[-2] eq 'work') and
#            ($directories[-3] eq '.cpanm')
#        ) {
#            my $msg = "build.log file not found in directories ending $partial";
#            croak $msg;
#        }
#        else {
#            say "Found directories ending $partial" if $verbose;
#            $cpanm_dir = File::Spec->catdir(@directories[0 .. ($#directories - 2)]);
#            say "cpanm_dir: $cpanm_dir" if $verbose;
#            my $possible_symlink = File::Spec->catfile($cpanm_dir, 'build.log');
#            say "possible_symlink: $possible_symlink" if $verbose;
#            if (-l $possible_symlink) {
#                unlink $possible_symlink or croak "Unable to remove symlink $possible_symlink";
#            }
#            # Keep TAD::gzip_cpanm_build_log() happy
#            symlink($blp, $possible_symlink) or croak "Unable to create symlink $possible_symlink";
#        }
#    }
#    else {
#        # If we've only supplied the full path to the symlink to the build.log
#        say "Value for 'path_to_cpanm_build_log' is a symlink" if $verbose;
#        my $real_log = readlink($blp);
#        croak "Could not locate target of build.log symlink" unless (-f $real_log);
#        $cpanm_dir = dirname($blp);
#        say "cpanm_dir: $cpanm_dir" if $verbose;
#    }
#
#    my $vresults_dir = File::Spec->catdir($args->{results_dir}, $data->{perl_version});
#    my $buildlogs_dir = File::Spec->catdir($vresults_dir, 'buildlogs');
#    my $analysis_dir = File::Spec->catdir($vresults_dir, 'analysis');
#    my $storage_dir = File::Spec->catdir($vresults_dir, 'storage');
#    for my $dir ( $vresults_dir, $buildlogs_dir, $analysis_dir, $storage_dir ) {
#        croak "Could not locate $dir" unless -d $dir;
#    }
#
#    my %load = (
#        cpanm_dir           => $cpanm_dir,
#        vresults_dir        => $vresults_dir,
#        buildlogs_dir       => $buildlogs_dir,
#        analysis_dir        => $analysis_dir,
#        storage_dir         => $storage_dir,
#    );
#    $data->{$_} = $load{$_} for keys %load;
#
#    return bless $data, $class;
#}

