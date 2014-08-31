#!/bin/zsh

set -x

# Customize to suit
base=$HOME/git/ompi-svn-to-git-conversion-aug-2014
scripts_dir=$base/scripts
rname=ompi-svn-to-git
rdir=$base/$rname
svn_url=https://svn.open-mpi.org/svn/ompi

do_svn_init=0

cd $base

# Sanity checks
if test "`pwd`" != "$base"; then
    echo "I'm not sure what directory I'm in..."
    echo Aboring before I do any harm
    exit 1
fi
if test $do_svn_init -eq 0 && \
    test ! -r ompi-svn-to-git-1-after-fetch.tar.bz2; then
    echo "***  WARNING: Selected NOT to re-init SVN, but there's no tarball!"
    echo "*** Cannot continue"
    exit 1
fi

##########################################################################

# This only works with 1.8.2.1 for some reason :-(
module unload cisco/git
module load cisco/git/1.8.2.1

rm -rf $rname

# Pull from SVN
start=`date`
echo "===== STARTING: $start"

if test "$do_svn_init" -eq 1; then
    git svn init -s $svn_url $rname
    cd $rname

    # Get the right refs for OMPI's wonky SVN tag layout
    git config --replace-all svn-remote.svn.tags \
        'tags/v1.0-series/*:refs/remotes/tags/*'
    git config --add svn-remote.svn.tags \
        'tags/v1.1-series/*:refs/remotes/tags/*'
    git config --add svn-remote.svn.tags \
        'tags/v1.2-series/*:refs/remotes/tags/*'
    git config --add svn-remote.svn.tags \
        'tags/v1.3-series/*:refs/remotes/tags/*'
    git config --add svn-remote.svn.tags \
        'tags/v1.4-series/*:refs/remotes/tags/*'
    git config --add svn-remote.svn.tags \
        'tags/v1.5-series/*:refs/remotes/tags/*'
    git config --add svn-remote.svn.tags \
        'tags/v1.6-series/*:refs/remotes/tags/*'
    git config --add svn-remote.svn.tags \
        'tags/v1.7-series/*:refs/remotes/tags/*'
    git config --add svn-remote.svn.tags \
        'tags/v1.8-series/*:refs/remotes/tags/*'
else
    # Extract the git svn clone
    tar xf $rname-1-after-fetch.tar.bz2
    cd $rname
    git checkout master
fi

# Get the latest authors file
cd ..
rm -rf authors
git clone https://github.com/open-mpi/authors.git
cd $rname
git config svn.authorsfile $base/authors/authors.txt

# Loop over git svn fetch (because sometimes the network between here
# and upstream goes out, falsely causing "git svn fetch" to fail).
num_fails=0
done=0
while test $done -eq 0; do
    git svn fetch --all
    st=$?
    if test $st -eq 0; then
        echo '======== git svn fetch completed successfully!'
        done=1
    else
        echo '======== git svn fetch failed.  looping...'
        num_fails=`expr $num_fails + 1`
        if test $num_fails -gt 20; then
            stop=`date`
            echo "====== hmmm... lotsa failures... exiting..."
            echo "===== GIT SVN FETCH FAILED"
            echo "===== START: $start"
            echo "===== STOP:  $stop"
            pushover SVN git clone failed
            exit 1
        fi
        sleep 2
    fi
done
git checkout master
git svn rebase
# Without this sleep, the tar below that saves this tree sometimes
# complains that .git/tags changes while tar is reading it (!).
sleep 5
stop=`date`
echo "===== GIT SVN FETCH DONE"
echo "===== START: $start"
echo "===== STOP:  $stop"

# Save step 1
cd ..
echo '=========== SAVING AFTER GIT SVN FETCH'
tar jcf $rname-1-after-fetch.tar.bz2 $rname
cd $rname

# Run the preprocess step
echo ----------- Running preprocess
$scripts_dir/svn-to-git/runme-preprocess-git-repo.sh

# Save step 2
cd ..
echo '============ SAVING AFTER PREPROCESS'
tar jcf $rname-2-after-preprocess.tar.bz2 $rname
cd $rname

# Delete some stale branches that were never actually released (git
# svn saw their creation and therefore created corresponding git
# branches).
echo ----------- Deleting stale branches
git branch -D tim
git branch -D orte
git branch -D v1.2ofed
git branch -D v1.2ofed@13796
git branch -D v1.7-wrappers
git gc

# Rewrite SVN commit messages to translate SVN r numbers and Trac
# ticket numbers.
echo ----------- Running git filter-branch
rm -f /tmp/gfb-$USER.log

# This version of git works with our git filter-branch command
module unload cisco/git
module load cisco/git/1.8.2.1

git filter-branch --commit-filter "$scripts_dir/svn-to-git/runme-git-filter-branch-hook.pl"' "$@"' --tag-name-filter cat -- --all --date-order
git for-each-ref --format="%(refname)" refs/original/ | xargs -n 1 git update-ref -d

# Save step 3
cd ..
echo '============ SAVING FILTERED TREE'
tar jcf $rname-3-after-filter.tar.bz2 $rname
cd $rname

# Finally fix all the tags (unfortunately, our SVN tags are a bit of a
# mess because SVN lets you be messy without realizing it, if you're
# not careful... and we were apparently not careful :-( See comments
# in script for more detail).  This requires a little more tomfoolery
# than is easy to do in shell scripting; use perl.
echo ----------- Fixing tags
$scripts_dir/svn-to-git/runme-fix-tags.pl

# Save step 4
cd ..
echo '============ SAVING AFTER TAG FIXING'
tar jcf $rname-4-after-tag-fixing.tar.bz2 $rname
cd $rname

# All done!
$DOTFILES/pushover git svn conversion script FINISHED
