#!/usr/bin/env perl

# Download all the Trac wiki in text format (so that it can be
# converted to a different format).
#
# URLs to convert:
#
# http://svn.open-mpi.org/trac/ompi/wiki
# https://git.open-mpi.org/trac/hwloc/wiki
# https://svn.open-mpi.org/trac/mtt/wiki
#

use strict;

use File::Basename;
use Getopt::Long;

my $base_url;
my $start_page = "WikiStart";
my $help;

&Getopt::Long::Configure("bundling");
my $ok = Getopt::Long::GetOptions("base-url|b=s" => \$base_url,
                                  "start-page|s=s" => \$start_page,
                                  "help|h" => \$help);
if ($help || !$ok) {
    print("$0 --start URL\n");
    exit($ok);
}

die "Must define a --start URL (i.e., the root of a wiki)"
    if (!defined($base_url));

#############################################################

my $downloaded_already;

print "*** Starting with: $start_page\n";
download($start_page);

sub download {
    my $page = shift;

    if (exists($downloaded_already->{$page})) {
        print "*** Already downloaded $page\n";
        return;
    }

    # Remove any stale copy
    unlink($page);

    # If it's in a subdirectory, make sure it exists
    my $dirname = dirname($page);
    system("mkdir -p $dirname")
        if (! -d $dirname);

    my $rc = system("wget $base_url/$page?format=txt -O $page.trac");
    die "wget failed: $_"
        if (0 != $rc);
    $downloaded_already->{$page} = 1;

    my $contents;
    open(PAGE, "$page.trac") ||
        die "Can't open downloaded page $page, $_";
    $contents .= $_
        while(<PAGE>);
    close(PAGE);

    # Find all wiki: links, chase them down
    foreach my $link ($contents =~ m/\[wiki:(.+?)\]/mg) {
        print "*** Got initial link: $link\n";
        # If it's a quoted link, extract.  Otherwise, take the first
        # token.
        if ($link =~ m/^"(.+?)\"/) {
            $link = $1;
        } else {
            my @links = split(/\s+/, $link);
            $link = $links[0];
        }

        # Remove trailing "#sublinks", if necessary
        $link =~ s/#.+$//;
        # Remove trailing "?...", if necessary
        $link =~ s/\?.+$//;
        # Escape spaces
        $link =~ s/ /%20/g;

        print "*** Chasing link: $link\n";
        download($link);
    }
}
