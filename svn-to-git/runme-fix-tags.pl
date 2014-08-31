#!/usr/bin/env perl

#######################################################################
# THIS SCRIPT IS NORMALLY RUN AS PART OF THE runme.sh SCRIPT!
#
# But it can be run manually, too.
#######################################################################

# Manually patch up git tags.  Specifically, OMPI's SVN tags are a bit
# of a mess, for a few reasons:
#
# 1. OMPI's dist script records the "svnversion" r number of a release
# branch in its VERSION file as the r number of the release.  However,
# that r number is the most recent r number of the entire repository
# -- it may not correspond to an r number on the release branch.
#
# SIDENOTE: In hindsight, we should have found the last r number on
# the release branch and recorded that.  Oops.  Not worth fixing now,
# since we're converting to git...
#
# 2. For some reason, we decided to use a non-standard SVN "tags"
# directory layout.  This made things a little more complicated.
#
# 3. Some of OMPI's tags got moved around a bit (e.g., create
# /tags/foo, and then move it to /tags/bar.  This somewhat confuses
# the git svn import.
#
# It is not worth trying to write logic to chase down all of this
# stuff.  I tried a few different methods, but in the end, I just
# ended up manually looking up each r number for each release and then
# hard-coding it into a table below.  It's not sexy, but it's probably
# the least-time-to-completion solution.

#######################################################################
#######################################################################
#######################################################################

use strict;

# Customize to suit
my $base = "$ENV{HOME}/git/ompi-svn-to-git-conversion-aug-2014";
my $scripts_dir = "$base/scripts";
my $rname = "ompi-svn-to-git";
my $rdir = "$base/$rname";
my $svn_url = "https://svn.open-mpi.org/svn/ompi";

# The git filter-branch we use below doesn't work properly with git
# 1.8.5.x -- but I know it works with git 1.8.2.1.  So use that one.
# JMS HACK: Put in specific location of Modulecmd.pm
require("/home/jsquyres/svn/mtt/lib/Env/Modulecmd.pm");
Env::Modulecmd::unload("cisco/git");
Env::Modulecmd::load("cisco/git/1.8.2.1");

# For debugging...
#  Restore after stage 3
#print("============== RESTORE STAGE 3 TARBALL\n");
#chdir($base);
#system("rm -rf $rname");
#system("tar xf $rname-3-after-filter.tar.bz2 $rname");
chdir($rname);

# First, delete the existing tags.
foreach my $tag (`git tag`) {
    chomp($tag);
    print("------------ deleting git tag $tag\n");
    system("git tag -d $tag");
}

# Some tags were made via convoluted histories.  a) We don't care
# about the tag histories, and b) it's too complex to try to write
# logic to chase them all down.  So just look them up manually and
# then hard-code the results.

# ....aaaand it turns out that the SVN tags are a bit of a mess,
# anyway.  They don't always correspond to an r number that is in the
# branch.  So I looked them up manually and made the following table.
my $tag_origins;
$tag_origins->{"v1.0.0"} = "r8189";
$tag_origins->{"v1.0.1"} = "r8530";
$tag_origins->{"v1.0.2"} = "r9571";

$tag_origins->{"v1.1.0"} = "r10477";
$tag_origins->{"v1.1.1"} = "r11453";
$tag_origins->{"v1.1.2"} = "r12073";
$tag_origins->{"v1.1.3"} = "r12860";
$tag_origins->{"v1.1.4"} = "r13362";
$tag_origins->{"v1.1.5"} = "r13997";

$tag_origins->{"v1.2.0"} = "r14027";
$tag_origins->{"v1.2.1"} = "r14481";
$tag_origins->{"v1.2.2"} = "r14613";
$tag_origins->{"v1.2.3"} = "r15098";
$tag_origins->{"v1.2.4"} = "r16187";
$tag_origins->{"v1.2.5"} = "r16941";
$tag_origins->{"v1.2.6"} = "r17884";
$tag_origins->{"v1.2.7"} = "r19401";
$tag_origins->{"v1.2.8"} = "r19717";
$tag_origins->{"v1.2.9"} = "r20259"; # ??

$tag_origins->{"v1.3.0"} = "r20295";
$tag_origins->{"v1.3.1"} = "r20826";
$tag_origins->{"v1.3.2"} = "r21054";
$tag_origins->{"v1.3.3"} = "r21666";
$tag_origins->{"v1.3.4"} = "r22212";

$tag_origins->{"v1.4.0"} = "r22282";
$tag_origins->{"v1.4.1"} = "r22421";
$tag_origins->{"v1.4.2"} = "r23093";
$tag_origins->{"v1.4.3"} = "r23834";
$tag_origins->{"v1.4.4"} = "r25188";
$tag_origins->{"v1.4.5"} = "r25905";

$tag_origins->{"v1.5.0"} = "r23862";
$tag_origins->{"v1.5.1"} = "r24177";
$tag_origins->{"v1.5.2"} = "r24500";
$tag_origins->{"v1.5.3"} = "r24532";
$tag_origins->{"v1.5.4"} = "r25060";
$tag_origins->{"v1.5.5"} = "r26167";

$tag_origins->{"v1.6.0"} = "r26427";
$tag_origins->{"v1.6.1"} = "r27072";
$tag_origins->{"v1.6.2"} = "r27344";
$tag_origins->{"v1.6.3"} = "r27472";
$tag_origins->{"v1.6.4"} = "r28075";
$tag_origins->{"v1.6.5"} = "r28663";

$tag_origins->{"v1.7.0"} = "r28266";
$tag_origins->{"v1.7.1"} = "r28336";
$tag_origins->{"v1.7.2"} = "r28671";
$tag_origins->{"v1.7.3"} = "r29499";
$tag_origins->{"v1.7.4"} = "r30561";
$tag_origins->{"v1.7.5"} = "r31178";

$tag_origins->{"v1.8.0"} = "r31295";
$tag_origins->{"v1.8.1"} = "r31483";
$tag_origins->{"v1.8.2"} = "r32596";

# Look up r numbers for tags with simple histories (dynamically
# looking it up in SVN avoids human error).
if (0) {
    # This code was written before I ended up hard-coding the SVN r
    # numbers for each release, so it isn't needed any more.  But it
    # seems like useful code, so might as well keep it...
    foreach my $series (`svn ls $svn_url/tags`) {
        chomp($series);
        $series =~ s/\/$//;
        print "Found SVN tag series: $series\n";

        foreach my $tag (`svn ls $svn_url/tags/$series`) {
            chomp($tag);
            $tag =~ s/\/$//;
            print "Found SVN tag: $tag\n";

            if (exists($tag_origins->{$tag})) {
                print("Hard-coded origin for tag $tag: r$tag_origins->{$tag}\n");
            } else {
                $tag_origins->{$tag} =
                    find_tag_origin_r("$svn_url/tags/$series/$tag");
                print("Found origin for tag $tag: r$tag_origins->{$tag}\n");
            }
        }
    }
}

# For each of those r numbers that we found, tag the corresponding git
# hash
foreach my $tag (sort(keys(%{$tag_origins}))) {
    my $r = $tag_origins->{$tag};
    $r =~ s/^r//;
    my $hash = `git log --all --grep 'This commit was SVN r$r' --format=format:%H -s`;
    chomp($hash);

    # Special case: we have both a tag and a branch named "v1.8.1"
    # (for bizarre history reasons).  So rename the tag to be
    # "v1.8.1-tag".
    $tag = "v1.8.1-tag"
        if ($tag eq "v1.8.1");

    print "Tag $tag corresponds to r$r, git $hash\n";
    system("git tag $tag $hash");
}
exit(0);


##############################################################

# This code was written before I ended up hard-coding the SVN r
# numbers for each release, so it isn't needed any more.  But it
# seems like useful code, so might as well keep it...
sub find_tag_origin_r {
    my $url = shift;

    $url =~ m/(v\d.\d)-series\/(.+)/;
    my $series = $1;
    my $tag = $2;

    my $base = $url;
    $base =~ s/^http.+?\/tags/\/tags/;
    print "Searching for origin: $url\n";

    open(SVN, "svn log -v --stop-on-copy $url|") ||
        die "Can't open svn log";

    my @found;
    my $num_commits = 0;
    my $origin;
    while (<SVN>) {
#        print "LINE: $_";
        chomp;

        # Look for a line beginning with "   A /tags/...."
        if ($_ =~ /^   A $base \(from \/branches\/$series:(\d+)/m) {
            $origin = $1;
            close(SVN);
#            print "Found origin: $origin\n";
            return $origin;
        }
    }
    close(SVN);

    die "Could not find origin for $tag\n";
}

exit(0);
