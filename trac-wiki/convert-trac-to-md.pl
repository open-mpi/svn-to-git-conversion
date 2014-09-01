#!/usr/bin/env perl

# Traverse a tree of .trac wiki markup files and convert them to .md
# (GitHub Markdown -- see
# https://help.github.com/articles/github-flavored-markdown) files.

use strict;

use File::Basename;
use File::Find;
use Cwd;

my $github_wiki = "jsquyres/test-github-repo";
my $tmp_root = "/tmp/jsquyres-convert-github-wiki";

##############################################################

my $start_dir = getcwd();

system("rm -rf $tmp_root");
system("mkdir $tmp_root");
chdir($tmp_root);
system("git clone git\@github.com:$github_wiki.wiki.git");
chdir("$github_wiki.wiki");
my $wiki_root = "$tmp_root/" . basename($github_wiki) . ".wiki";
system("git rm *");
system("git commit -m \"remove all files\"");

chdir($start_dir);
find(\&find_helper, ".");

chdir($wiki_root);
system("ls -l");
system("git add .");
system("git commit -m \"Converted wiki files\" --no-verify");
system("git push");

exit(0);

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

    convert_trac2md($abs_file_name);
}

##################################################################

sub convert_trac2md {
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
    # !'
    $contents =~ s/([\n\s])!'/\1&&&WIKI QUOTE&&&/gms;

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

    # External links
    # Quoted link with no link text
    $contents =~ s/\[{1,2}\s*"(http[a-zA-Z0-9_#:\-\.\/]+?)"\]{1,2}/<\1>/gm;
    # Quoted link with link text
    $contents =~ s/\[{1,2}\s*"(http[a-zA-Z0-9_#:\-\.\/]+?)"\s+(.+?)\]{1,2}/[\2](\1)/gms;
    # Unquoted link with no link text
    $contents =~ s/\[{1,2}\s*(http[a-zA-Z0-9_#:\-\.\/]+?)\]{1,2}/<\1>/gm;
    # Unquoted link with link text
    $contents =~ s/\[{1,2}\s*(http[a-zA-Z0-9_#:\-\.\/]+?)\s+(.+?)\]{1,2}/[\2](\1)/gms;

    # Wiki links
    # Quoted link with no link text
    $contents =~ s/\[{1,2}\s*"wiki:([a-zA-Z0-9_#:\-\.\/]+?)"\]{1,2}/[[&&&WIKI LINK \1&&&]]/gm;
    # Quoted link with link text
    $contents =~ s/\[{1,2}\s*"wiki:([a-zA-Z0-9_#:\-\.\/]+?)"\s+(.+?)\]{1,2}/[[\2|&&&WIKI LINK \1&&&]]/gms;
    # Unquoted link with no link text
    $contents =~ s/\[{1,2}\s*wiki:([a-zA-Z0-9_#:\-\.\/]+?)\]{1,2}/[[&&&WIKI LINK \1&&&]]/gm;
    # Unquoted link with link text
    $contents =~ s/\[{1,2}\s*wiki:([a-zA-Z0-9_#:\-\.\/]+?)\s+(.+?)\]{1,2}/[[\2|&&&WIKI LINK \1&&&]]/gms;
    # Convert / to - in wiki links
    while (1) {
        # Can't just foreach over the m/.../
        if ($contents =~ m/&&&WIKI LINK (.*?)&&&/gms) {
            my $original_link = $1;
            my $converted_link = $1;
            $converted_link =~ s/\//-/g;
            $contents =~ s/&&&WIKI LINK $original_link&&&/$converted_link/;
        } else {
            last;
        }
    }

    # Reference links

    # source: links

    # ticket links

    # commit links

    # Line breaks [[br]]
    # Line break at end of line
    $contents =~ s/\[\[br\]\]\s*$/  /igm;
    $contents =~ s/\\\\\s*$/  /igm;
    # Line break in middle of line
    $contents =~ s/\[\[br\]\]\s*(\S)/  \n\1/igm;
    $contents =~ s/\\\\\s*(\S)/  \n\1/igm;

    # Images

    # Tables

    # Specifically not converting:
    # - ordered list (because it's effectively the same)
    # - unordered list (because it's the same)
    # - strikethrough (because it's the same)
    # - horizontal line (because it's effectively the same)
    # - underline (_foo_, no MD equivalent)
    # - superscript (^foo^, no MD equivalent)

    # Convert back some special escape sequences from above
    $contents =~ s/&&&WIKI QUOTE&&&/'/gm;

    # Write the output
    my $outfile = $abs_file;
    $outfile =~ s/\.\///;

    $outfile = "Home.md"
        if ($file eq "WikiStart.trac");
    $outfile =~ s/\.trac$/.md/;
    $outfile =~ s/\//-/g;
    print "OUTFILE: $abs_file -> $outfile\n";
    open(OUT, ">$wiki_root/$outfile") ||
        die "Can't write to $file: $_";
    print OUT $contents;
    close(OUT);
}
