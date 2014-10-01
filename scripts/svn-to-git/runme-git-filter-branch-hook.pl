#!/usr/bin/env perl
# This script expects to be invoked as a git-filter-branch "--commit-filter".
# That is, it is invoked instead of git-commit-tree.  So it will be invoked
# with the tree hash as $ARGV[0] and then arg pairs of parents (@ARGV[1..2],
# @ARGV[3..4], etc.).  The commit message will be passed on STDIN and the
# various $GIT_ environment variables will be set (e.g., $GIT_AUTHOR_NAME).
#
# This script is obligated to make the commits (probably with
# "git-commit-tree" itself) and print the resulting commit hashes to STDOUT.

# typical git filter-branch invocation:
# % rm -f /tmp/gfb.log ; git filter-branch --commit-filter '/path/to/convert-hwloc.pl "$@"' --tag-name-filter cat -- --all --date-order

use warnings;
use strict;

use Data::Dumper;
use IPC::Open2;
use IO::Handle;

open(my $LOG_FH, '>>', '/tmp/gfb-'.$ENV{"USER"}.'.log');
print $LOG_FH "XXX ".('-' x 80)."\n";

# "constants"
my $ABBREV_MSG_CHARS = 50;
my $ABBREV_RANGE_COMMITS = 8;
my $ELLIPSES = "...";
my $trac_ticket_url = "https://svn.open-mpi.org/trac/ompi/ticket";

# take a few useful environment variables and copy them to real perl vars for
# convenience
my $workdir = $ENV{'workdir'};
die "workdir is not set, stopped" unless $workdir;

# SHA-1 hash of tree for this commit
my $tree;
# elements are parent SHA-1 hashes
my @parents = ();
my @mapped_parents = ();


## parse our args
$tree = shift @ARGV;
while (scalar @ARGV) {
    if ($ARGV[0] ne "-p") {
        die "expected '-p', stopped";
    }
    shift @ARGV;

    my $parent = shift @ARGV;
    if (!$parent or $parent !~ m/[0-9a-f]+/) {
        die "expected SHA-1 hash, stopped";
    }
    push @parents, $parent;
    push @mapped_parents, map_commit($parent);
}

## twiddle the commit message
my ($msg, $new_msg);
{
    local $/; # slurp mode, activate!
    $msg = <STDIN>;
}

# Transform the commit message in several ways:
# - add a note to the commit indicating what SVN R number it used to be
# - search for any rXYZ values in the original message and add
#   cross-ref notes to the bottom of the commit message ("rXYZ is
#   01234..cdef")
# - search for any #XYZ values in the original message and add
#   cross-ref notes to the bottom of the commit message ("trac ticket
#   is https://...");
# - replace "#XYZ" values in the original message with "trac:XYZ"
# - strip out the git-svn bread crumbs ("git-svn-id: https://...")

# strip out the git-svn breadcrumb first so that we don't accidentally
# find it during our grepping
$msg =~ s/\n^\s*git-svn-id:.*?@(\d+).*?$//mg;
unless ($1) { die "unable to parse git-svn bread crumb, stopped"; }
my $REV = $1;

# Catch bozo case of an empty commit message
if (defined($msg) && length($msg) > 0) {
    $new_msg = $msg;
} else {
    $new_msg = "<empty commit message>";
}

my ($xref_hash, $ranges, $invalid_revs, $trac_tickets) = build_xref($msg);
print $LOG_FH "XXX xref_hash=".Dumper($xref_hash)."\n";
print $LOG_FH "XXX ranges=".Dumper($ranges)."\n";
print $LOG_FH "XXX tickets=".Dumper($trac_tickets);

# Change all the "fixes #" (and friends) to "fixes trac:" so that
# Github doesn't cross-link those to Github issues.
$new_msg =~ s/(\bfixes )#(\d+\b)/$1trac:$2/igm;
$new_msg =~ s/(\brefs )#(\d+\b)/$1trac:$2/igm;
$new_msg =~ s/(\bcloses )#(\d+\b)/$1trac:$2/igm;
$new_msg =~ s/^(cmr=.+:ticket=)#(\d+)/$1trac:$2/igm;

# Add footnotes to the commit
$new_msg .= "\n";
$new_msg .= "This commit was SVN r$REV.\n";
if (%$xref_hash) {
    $new_msg .= "\n";
    $new_msg .= "The following SVN revision numbers were found above:\n";
    foreach my $sr (sort {$a <=> $b} keys %$xref_hash) {
        my $gr = $xref_hash->{$sr};
        $new_msg .= "  r$sr --> open-mpi/ompi\@$gr\n"
    }

    if (%$ranges) {
        $new_msg .= "\n";
        $new_msg .= qq{Revision number ranges (suitable for "git log"):\n};
        foreach my $sr (sort {$a cmp $b} keys %$ranges) {
            my $gr = $ranges->{$sr};
            $new_msg .= "  r$sr --> open-mpi/ompi\@$gr\n"
        }
    }
}
if (scalar @$invalid_revs) {
    $new_msg .= <<EOT;

The following SVN revisions from the original message are invalid or
inconsistent and therefore were not cross-referenced:
EOT
    foreach my $inv (sort @$invalid_revs) {
        $new_msg .= "  r$inv\n";
    }
}
if (scalar(@$trac_tickets)) {
    $new_msg .= <<EOT;

The following Trac tickets were found above:
EOT
    foreach my $t (@$trac_tickets) {
        $new_msg .= "  Ticket $t --> $trac_ticket_url/$t\n";
    }
}
print $LOG_FH "XXX new_msg=|$new_msg|\n";

## actually make the commit
#system "echo", "git", "commit-tree", ...
my($chld_out, $chld_in);
open2($chld_out, $chld_in, "git", "commit-tree", $tree, (map { ("-p", $_) } @mapped_parents));
print $chld_in $new_msg;
close $chld_in;
my $git_rev = $chld_out->getline();
chomp $git_rev;
close $chld_out;

# stash this mapping in .git-rewrite/map/rXYZ
open(my $fh, '>', "$workdir/../map/svn-r$REV");
print $fh "$git_rev\n";
close($fh);

# supply the newly created commit ID with the filter-branch driver
print STDOUT "$git_rev\n";
print $LOG_FH "XXX git_rev=$git_rev\n";

close($LOG_FH);

# Takes a single argument, which is a commit SHA-1 and maps it from an old
# value to a new value.  Useful for mapping old parent ids to new parent ids.
# Failure to map will result in the given argument being passed back.
sub map_commit {
    # the shell script from which this was cribbed
    #----8<----
    #map()
    #{
    #        # if it was not rewritten, take the original
    #        if test -r "$workdir/../map/$1"
    #        then
    #                cat "$workdir/../map/$1"
    #        else
    #                echo "$1"
    #        fi
    #}
    #----8<----

    unless (@_) { die "no args passed to map, stopped"; }

    my $in = shift;
    my $ret = $in;
    if (-r "$workdir/../map/$in") {
        $ret = scalar `cat $workdir/../map/$in`;
        chomp $ret;
    }
    return $ret;
}

sub build_xref {
    my $msg = shift;

    # return a map of svn revisions to git SHA-1 hashes
    my $xref = {};
    # also return a map of ranges (as strings) to (hopefully) equivalent git
    # ranges (as strings)
    my $ranges = {};
    # also return any revisions found in the input message which were
    # invalid or otherwise inconsistent
    my $invalid_revs = [];
    # also return a list of trac tickets referenced in the commit
    # message
    my $trac_tickets = [];

    my @svn_revs = ();
    my @git_revs = ();

    # Look for "rXYZ", "rXYZ,ABCD", "rXYZ,rABCD", etc...
    # Also look for ranges like "rX-rY", "rX-Y", and "rX-Y,Z,A-B".
    # Also look for ranges like "rX:Y", "rX:rY", and "rX:Y,rA:B".
    #
    # first find patterns that look right
    #my @tmp = ($msg =~ m/\b(r(?:\d+)(?:,r?\d+)*)\b/gm);
    my @tmp = ($msg =~ m/\b(r(?:\d+)(?:[-,:]r?\d+)*)\b/gm);

    foreach my $t (@tmp) {
        # now split them on commas (natural language precedence)
        $t =~ s/r//g;
        my @tmp2 = split m/,/, $t;

        foreach my $t2 (@tmp2) {
            # also process ranges, just note endpoints for now as regular commits
            push @svn_revs, split m/[-:]/, $t2;
            # and the range itself for special handling later
            if ($t2 =~ m/[-:]/) {
                $ranges->{$t2} = '';
            }
        }
    }

    # also look for [XYZ] as a trac-style name for rXYZ
    # NOTE: disabled for now because hwloc does not have any commit refs of
    # this format but it does have other random text which looks similar
    #@tmp = ($msg =~ m/(\[\d+\])/gm);
    #push @svn_revs, (map { s/\[|\]//g; $_ } @tmp);

    print $LOG_FH "XXX svn_revs=".Dumper(\@svn_revs)."\n";
    print $LOG_FH "XXX ranges=".Dumper($ranges)."\n";

    # NOTE could also look for "changeset:XYZ", but this does not appear to be
    # used in our repositories.  See
    # http://trac.edgewall.org/wiki/WikiFormatting#TracLinks for more info.

    # lookup each svn rev in our mapping cache on the file system
    @svn_revs = sort {$a <=> $b} @svn_revs;
    foreach my $sr (@svn_revs) {
        my $gr = svn_rev_to_hash($sr);
        if ($gr) {
            $xref->{$sr} = $gr;
        }
        else {
            push @$invalid_revs, $sr;
        }
    }

    # generate pretty git ranges for any svn ranges we found
    foreach my $range (sort keys %$ranges) {
        my ($start,$sep,$end,$remain) = split m/([-:])/, $range;
        if ($remain) { die "unexpected range parse result, stopped"; }

        # assume a missing entry in the $xref means we skipped the rev
        # as invalid (as opposed to some programming mistake in this
        # script)
        next unless exists $xref->{$start} and exists $xref->{$end};

        # shorten the commits for convenience and to avoid overly long
        # commit message lines
        my $gstart = substr $xref->{$start}, 0, $ABBREV_RANGE_COMMITS;
        my $gend = substr $xref->{$end}, 0, $ABBREV_RANGE_COMMITS;

        if ($sep eq ":" and $msg =~ m/merge/si) {
            # colon range and probably a merge, assume this is a half-open
            # range (i.e., X:Y --> (X,Y], not [X,Y])
            $ranges->{$range} = "${gstart}..${gend}";
        }
        else {
            $ranges->{$range} = "${gstart}^..${gend}";
        }
    }

    # Look for "fixes #x", "closes #x", "refs #x", and
    # "cmr=...:ticket=[#]x", where X is a trac ticket number.  I'm
    # sure there's a more clever way to do this, regexp-wise, but this
    # is simple and it works.
    my $found;
    foreach my $t ($msg =~ m/\bfixes #(\d+)\b/igm) {
        $found->{$t} = 1;
    }
    foreach my $t ($msg =~ m/\brefs #(\d+)\b/igm) {
        $found->{$t} = 1;
    }
    foreach my $t ($msg =~ m/\bcloses #(\d+)\b/igm) {
        $found->{$t} = 1;
    }
    foreach my $t ($msg =~ m/^cmr=.+:ticket=#?+(\d+)/igm) {
        $found->{$t} = 1;
    }
    foreach my $t (sort {$a <=> $b} keys(%{$found})) {
        push @{$trac_tickets}, $t;
    }

    return ( $xref, $ranges, $invalid_revs, $trac_tickets );
}

# expects one argument, an svn revision number (just the number part, no "r"),
# and returns the corresponding commit hash.  Returns '' if not found.
sub svn_rev_to_hash {
    my $sr = shift;
    my $ret = '';

    if (-e "$workdir/../map/svn-r$sr") {
        $ret = `cat "$workdir/../map/svn-r$sr"`;
        chomp $ret;
    }
    return $ret;
}
