#!/usr/bin/env perl

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

#  Restore after stage 3
print("============== RESTORE STAGE 3 TARBALL\n");
chdir($base);
#system("rm -rf $rname");
#system("tar xf $rname-3-after-filter.tar.bz2 $rname");
chdir($rname);

# Manually patch up tags.  OMPI stores them in a slightly non-standard
# way in SVN, so do this semi-manually.

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
my $tag_origins;
$tag_origins->{"v1.0.0"} = "8189";
$tag_origins->{"v1.0.1"} = "8453";
$tag_origins->{"v1.0.2"} = "9573";

$tag_origins->{"v1.1.0"} = "10477";
# These 3 were tagged poorly (e.g., to r numbers in /tmp), so manually
# pick a good number
$tag_origins->{"v1.1.1"} = "11477";
$tag_origins->{"v1.1.2"} = "12073";
$tag_origins->{"v1.1.3"} = "12861";

$tag_origins->{"v1.3.0"} = "20295";

$tag_origins->{"v1.7.1"} = "28336";

$tag_origins->{"v1.8.0"} = "31295";
$tag_origins->{"v1.8.1"} = "31483";

# Look up r numbers for tags with simple histories (dynamically
# looking it up in SVN avoids human error).
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

# For each of those r numbers that we found, tag the corresponding git
# hash
foreach my $tag (sort(keys(%{$tag_origins}))) {
    my $r = $tag_origins->{$tag};
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
