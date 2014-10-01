The scripts in here are meant to be used for the Open MPI SVN -->
GitHub transition.

There's at least 4 parts:

1. SVN -> git translation, and then push to GitHub
   --> See the "runme.sh" script to do the whole thing (set some paths
       and variables up top first).

2. Trac wiki -> Git markdown translation, and then push to GitHub

3. Trac tickets -> Git issues translation

4. Convert OMPI tarball scripts to use git instead of svn

--------------------------

#1 was done within this base directory.

#2 and #3 were done in the wiki and tickets directories,
respectively.  See their README.txt files for more detail.

For the SVN->Git conversion, it was a complicated process.  There are
several scripts involved; see the scripts/svn-to-git/README.txt file
for more info.


