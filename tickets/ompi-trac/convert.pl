#!/usr/bin/env perl

use strict;
use warnings;

my $base = "https://svn.open-mpi.org/trac/ompi/ticket/";

sub doit {
    my $file = shift;

    open (IN, $file) || die "Can't open $file";
    open(OUT, ">$file.out") || die "Can't open $file.out";
    my $in_verbatim = 0;
    while (<IN>) {
        my $str = $_;
        if ($str =~ /^{{{\s*$/) {
            $in_verbatim = 1;
            $str =~ s/^{{{\s*/```\n/;
        } elsif ($str =~ /^}}}\s*$/) {
            $in_verbatim = 0;
            $str =~ s/^}}}\s*/```\n/;
        } elsif (!$in_verbatim) {
            $str =~ s/\!\#(\d+)/item $1/g;
            $str =~ s/\#(\d+)/$base$1/g;
        }
        $str =~ s/{{{/```/g;
        $str =~ s/}}}/```/g;

        print OUT $str;
    }
    close(IN);
    close(OUT);

    system("mv $file.out $file");
}

doit("tickets.csv");
doit("comments.csv");
