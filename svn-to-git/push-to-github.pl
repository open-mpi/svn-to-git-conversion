#!/usr/bin/env perl

use strict;

my $ompi_repo = "git\@github.com:jsquyres/j.git";
my $ompi_release_repo = "git\@github.com:jsquyres/j-release.git";

my $base = "$ENV{HOME}/git/ompi-svn-to-git-conversion-aug-2014";
my $scripts_dir = "$base/scripts";
my $rname = "ompi-svn-to-git";
my $rdir = "$base/$rname";

chdir($rdir);

######################################################################

sub doit {
    my $cmd = shift;
    my $ok_to_fail = shift;

    print "*** Running: $cmd\n";
    my $rc = system($cmd);
    die "Unable to run command '$cmd': $_"
        if (0 != $rc && defined($ok_to_fail) && 0 == $ok_to_fail);
}

######################################################################

my @branches;
open(GIT, "git branch -a|");
while (<GIT>) {
    chomp;
    next
        if (/upstream-release/);

    $_ =~ s/^\* //;
    $_ =~ s/^  //;
    push(@branches, $_);
}
close(GIT);

doit("git remote remove upstream-master", 1);
doit("git remote remove upstream-release", 1);
doit("git remote add upstream-master $ompi_repo");
doit("git remote add upstream-release $ompi_release_repo");

# Push master
print "*** Pushing master\n";
doit("git push upstream-master master");

# Push release branches
foreach my $branch (@branches) {
    if ($branch !~ /master/) {
        print "*** Pushing branch: $branch\n";
        doit("git push --tags upstream-release $branch");
    }
}

exit(0);
