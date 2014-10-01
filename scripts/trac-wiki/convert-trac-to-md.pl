#!/usr/bin/env perl

# Traverse a tree of .trac wiki markup files and convert them to .md
# (GitHub Markdown -- see
# https://help.github.com/articles/github-flavored-markdown) files.

use strict;

use Getopt::Long;
use File::Basename;
use File::Find;
use Cwd;

my $help;
my $trac_root;
my $trac_url;
my $github_project = "jsquyres/test-github-repo";

&Getopt::Long::Configure("bundling");
my $ok = Getopt::Long::GetOptions("github-project=s" => \$github_project,
                                  "trac-dir=s" => \$trac_root,
                                  "trac-url=s" => \$trac_url,
                                  "help|h" => \$help);
if ($help || !$ok) {
    print("$0 --github-project <name> --start-dir <dir>\n");
    exit($ok);
}

die "Must specify a directory with Trac wiki files (via --trac-dir)"
    if (!defined($trac_root));
die "Trac dir does not seem to exist"
    if (! -d $trac_root);
die "Must specify a Trac URL base (via --trac-url)"
    if (!defined($trac_url));
die "Must specify a Github project (via --github-project)"
    if (!defined($github_project));

my $github_url = "https://github.com/$github_project";

##################################################################

my @images;

# Process wiki files

chdir($trac_root);
die "Please use an absolute dir name for --trac-dir ($trac_root != ". getcwd() . ")"
    if ($trac_root ne getcwd());

my $tmp_root = "/tmp/$ENV{'USER'}-convert-github-wiki";

doit("rm -rf $tmp_root");
doit("mkdir $tmp_root");
chdir($tmp_root);

doit("git clone git\@github.com:$github_project.wiki.git");

my $wiki_root = "$tmp_root/" . basename($github_project) . ".wiki";
die "git clone failed: $_"
    if (! -d $wiki_root);
chdir($wiki_root);

doit("git rm *");
doit("git commit -m \"remove all files\"");

chdir($trac_root);
find(\&find_helper, ".");

# Process image files

chdir($wiki_root);
foreach my $pair (@images) {
    doit("wget $pair->{origin} -O $pair->{converted}");
}

# Save everything to the wiki git

chdir($wiki_root);
doit("git add .");
doit("git commit -m \"Converted wiki files\" --no-verify");
doit("git push");

exit(0);

##################################################################

sub doit {
    my @cmd = @_;

    my $rc = system(@cmd);
    die "Command failed \"@_\": $_"
        if (0 != $rc);
}

##################################################################

sub find_helper {
    # $File::Find::dir is the current directory name,
    # $_ is the current filename within that directory
    # $File::Find::name is the complete pathname to the file.

    my $rel_file_name = $_;
    my $abs_file_name = $File::Find::name;

    # We only want *.trac files
    return
        if ($rel_file_name !~ /\.trac$/ || ! -r $rel_file_name);

    convert_trac2gmd($abs_file_name);
}

##################################################################

sub convert_trac2gmd {
    my $abs_file = shift;

    my $file = basename($abs_file);

    print "*** Converting $file\n";
    my $contents;
    open(FILE, $file) ||
        die "Can't open $file: $_";
    $contents .= $_
        while(<FILE>);
    close(FILE);

    # Convert trac syntax to markdown syntax.  Thankfully, we don't
    # use super-whacky markdown on our wiki, so we can get away with
    # doing some sorta-simple regexps.

    # First, remove dos notation
    $contents =~ s/\r\n/\n/gm;
    $contents =~ s/\n\r/\n/gm;

    # PageOutline -- there's no equivalent, sorry
    $contents =~ s/\[\[PageOutline\]\]//gm;

    # Escaped markup: ! (especially escaped CamelCase
    # !CamelCase
    $contents =~ s/([\n\s])!(\w)/\1\2/gms;
    # !_
    $contents =~ s/([\n\s])!_/\1_/gms;
    # !' (will convert this at the end, because we don't want to
    # mistake it for emphasis in the regexps below)
    $contents =~ s/([\n\s])!'/\1&&&WIKI QUOTE&&&/gms;
    # !' (will convert this at the end, because we don't want to
    # mistake it for a ticket in the regexps below)
    $contents =~ s/([\n\s])!#/\1&&&WIKI TICKET&&&/gms;

    # H1
    $contents =~ s/^\s*= (.+) =\s*$/\n\1\n=====\n/gm;
    # H2
    $contents =~ s/^\s*== (.+) ==\s*$/\n\1\n-----\n/gm;
    # H3
    $contents =~ s/^\s*=== (.+) ===\s*$/\n### \1\n/gm;
    # H4
    $contents =~ s/^\s*==== (.+) ====\s*$/\n#### \1\n/gm;

    # Indenting
    # JMS: This will screw up nested lists
    # JMS: Don't want to do this inside {{{ }}} blocks
    # JMS: By itself, indenting indicates block quotes
    #$contents =~ s/^\s+//gm;

    # Inline code
    $contents =~ s/{{{(.+?)}}}/`\1`/gm;

    # Verbatim
    # Preprocessors found in OMPI wiki pages: perl, c, html, comment, sh
    $contents =~ s/^\s*{{{\s*\n#!perl/```perl/igm;
    $contents =~ s/^\s*{{{\s*\n#!c/```C/igm;
    $contents =~ s/^\s*{{{\s*\n#!html/```HTML/igm;
    $contents =~ s/^\s*{{{\s*\n#!sh/```sh/igm;
    # The #!comment will be transformed above to ```Comment :-)
    $contents =~ s/```Comment.+}}}//gms;
    # No preprocessors
    $contents =~ s/^\s*{{{\s*$/```/gm;
    $contents =~ s/^\s*}}}\s*$/```/gm;

    # Emphasis and bold
    $contents =~ s/'''''(\w.*?)'''''/***\1***/gm;
    $contents =~ s/\*\*''(\w.*?)\*\*''/***\1***/gm;
    $contents =~ s/''\*\*(\w.*?)\*\*''/***\1***/gm;
    $contents =~ s/\*\*''(\w.*?)''\*\*/***\1***/gm;
    $contents =~ s/''\*\*(\w.*?)''\*\*/***\1***/gm;

    # Bold
    $contents =~ s/'''(\w.*?)'''/**\1**/gm;

    # Emphasis
    $contents =~ s/''(\w.*?)''/*\1*/gm;

    # Underline (MD has no equivalent, and HTML5 deprecates <u>, so
    # use emphasis)
    $contents =~ s/(\s)_(\w.*?)_(\s)/\1*\2*\3/gm;

    # Superscript (MD has no equivalent, so use HTML)
    $contents =~ s/\^(\w.*?)\^/<sup>\1<\/sup>/gm;

    # External links
    # Quoted link with no link text
    $contents =~ s/\[{1,3}\s*"(http[a-zA-Z0-9_#~: \-\.\/]+?)"\]{1,3}/<\1>/gm;
    # Quoted link with link text
    $contents =~ s/\[{1,3}\s*"(http[a-zA-Z0-9_#~: \-\.\/]+?)"\s+(.+?)\]{1,3}/[\2](\1)/gms;
    # Unquoted link with no link text
    $contents =~ s/\[{1,3}\s*(http[a-zA-Z0-9_#~:\-\.\/]+?)\]{1,3}/<\1>/gm;
    # Unquoted link with link text
    $contents =~ s/\[{1,3}\s*(http[a-zA-Z0-9_#~:\-\.\/]+?)\s+(.+?)\]{1,3}/[\2](\1)/gms;

    # Wiki links
    # Quoted link with no link text
    $contents =~ s/\[{1,3}\s*wiki:"([a-zA-Z0-9_#: \-\.\/]+?)"\]{1,3}/[[&&&WIKI LINK \1&&&]]/gm;
    # Quoted link with link text
    $contents =~ s/\[{1,3}\s*wiki:"([a-zA-Z0-9_#: \-\.\/]+?)"\s+(.+?)\]{1,3}/[[\2|&&&WIKI LINK \1&&&]]/gms;
    # Unquoted link with no link text
    $contents =~ s/\[{1,3}\s*wiki:([a-zA-Z0-9_#:\-\.\/]+?)\]{1,3}/[[&&&WIKI LINK \1&&&]]/gm;
    # Unquoted link with link text
    $contents =~ s/\[{1,3}\s*wiki:([a-zA-Z0-9_#:\-\.\/]+?)\s+(.+?)\]{1,3}/[[\2|&&&WIKI LINK \1&&&]]/gms;
    # Convert / to - in wiki links
    while (1) {
        # Can't just foreach over the m/.../ because changing the
        # string while foreaching over it gets the loop iterator
        # confused.
        if ($contents =~ m/&&&WIKI LINK (.*?)&&&/gms) {
            my $original_link = $1;
            my $converted_link = $1;
            $converted_link =~ s/\//-/g;
            $converted_link =~ s/ /-/g;
            $converted_link =~ s/%20/-/g;
            $contents =~ s/&&&WIKI LINK $original_link&&&/$converted_link/;
        } else {
            last;
        }
    }

    # Reference links

    # source: links
    # Source link with no link text
    $contents =~ s/\[{1,3}source:([a-zA-Z0-9_#:\-\.\/]+)\s*\]{1,3}/[source: \1]($github_url\/blob\/master\/\1)/igm;
    # Source linke with link test
    $contents =~ s/\[{1,3}source:([a-zA-Z0-9_#:\-\.\/]+)\s*(.+?)\]{1,3}/[\2]($github_url\/blob\/master\/\1)/igm;

    # ticket links
    $contents =~ s/\#(\d+)/[trac ticket \1]($trac_url\/ticket\/\1)/gm;

    # commit links
    # JMS

    # Line breaks [[br]]
    # Line break at end of line
    $contents =~ s/\[\[br\]\]\s*$/  /igm;
    $contents =~ s/\\\\\s*$/  /igm;
    # Line break in middle of line
    $contents =~ s/\[\[br\]\]\s*(\S)/  \n\1/igm;
    $contents =~ s/\\\\\s*(\S)/  \n\1/igm;

    # Images
    $contents = process_images($abs_file, $contents);

    # Tables
    # Specifically don't convert tables -- let a human do that by hand...

    # Specifically not converting:
    # - ordered list (because it's effectively the same)
    # - unordered list (because it's the same)
    # - strikethrough (because it's the same)
    # - horizontal line (because it's effectively the same)

    # Convert back some special escape sequences from above
    $contents =~ s/&&&WIKI QUOTE&&&/'/gm;
    $contents =~ s/&&&WIKI TICKET&&&/#/gm;

    # Write the output
    my $outfile = $abs_file;
    $outfile =~ s/\.\///;

    $outfile = "Home.md"
        if ($file eq "WikiStart.trac");
    $outfile = convert_filename($outfile);
    $outfile =~ s/\.trac$/.md/;
    print "OUTFILE: $abs_file -> $outfile\n";
    open(OUT, ">$wiki_root/$outfile") ||
        die "Can't write to $file: $_";
    print OUT $contents;
    close(OUT);
}

sub convert_filename {
    my $name = shift;

    $name =~ s/[\/ :]/-/g;
    $name =~ s/%20/-/g;

    return $name;
}

#
# Note that we have to specifically add each image to the wiki git, so
# we must extract image filenames and save them separately.  This is
# complicated enough to warrant its own subroutine.
#
sub process_images {
    my $abs_filename = shift;
    my $contents = shift;

    my $wiki_page = $abs_filename;
    $wiki_page =~ s/^$wiki_root//;
    $wiki_page =~ s/^\.\///;
    $wiki_page =~ s/\.trac//;

    while (1) {
        # Can't just foreach over the m/.../ because changing the
        # string while foreaching over it gets the loop iterator
        # confused.

        my $pair;
        # Image with additional specifications
        if ($contents =~ m/\[{1,3}image\(([a-zA-Z0-9_#: \-\.\/]+),.+?\)\]{1,3}/im) {
            my $original_filename = $1;
            my $converted_filename = convert_filename($1);

            $pair = {
                original => $original_filename,
                converted => $converted_filename
            };
            $contents =~ s/\[{1,3}image\([a-zA-Z0-9_#: \-\.\/]+,.+?\)\]{1,3}/![]($converted_filename)/im;
        }
        # Image with no additional specifications
        elsif ($contents =~ m/\[{1,3}image\(([a-zA-Z0-9_#: \-\.\/]+)\)\]{1,3}/im) {
            my $original_filename = $1;
            my $converted_filename = convert_filename($1);

            $pair = {
                original => $original_filename,
                converted => $converted_filename
            };
            $contents =~ s/\[{1,3}image\([a-zA-Z0-9_#: \-\.\/]+?\)\]{1,3}/![]($converted_filename)/im;
        } else {
            last;
        }

        # Support source: filenames and URL filenames
        if (defined($pair)) {
            if ($pair->{original} =~ /^source:/) {
                my $file = $pair->{original};
                $file =~ s/source://;
                $pair->{origin} = "$trac_url/export/HEAD/$file";
            } else {
                $pair->{origin} =
                    "$trac_url/raw-attachment/wiki/$wiki_page/$pair->{original}";
            }

            print "*** Found image: $pair->{original} -> $pair->{converted}\n";
            push(@images, $pair);
        }
    }

    return $contents;
}
