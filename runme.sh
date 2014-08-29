#!/bin/zsh

set -x

# Customize to suit
base=$HOME/git/ompi-svn-to-git-conversion-aug-2014
scripts_dir=$base/scripts
rname=ompi-svn-to-git
rdir=$base/$rname
svn_url=https://svn.open-mpi.org/svn/ompi

do_svn_init=1

cd $base

# Sanity check
if test $do_svn_init -eq 0 && \
    test ! -r ompi-svn-to-git-1-after-clone.tar.bz2; then
    echo "***  WARNING: Selected NOT to re-init SVN, but there's no tarball!"
    echo "*** Cannot continue"
    exit 1
fi

##########################################################################

# Make sure we have the latest / greatest
module unload cisco/git
module load cisco/git/2.1.0

rm -rf $rname

if test "$do_svn_init" -eq 1; then
    # Do the git svn clone
    start=`date`
    echo "===== STARTING: $start"

    git svn init -s $svn_url $rname
    cd $rname

    git config svn.authorsfile $scripts_dir/authors.txt

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
    tar xf $rname-1-after-clone.tar.bz2
    cd $rname
    git checkout master
fi

# Loop over git svn fetch (because sometimes the network between here
# and upstream goes out, falsely causing "git svn fetch" to fail).
num_fails=0
done=0
while test $done -eq 0; do
    git svn fetch --all
    st=$?
    if test $st -eq 0; then
        echo '======== git svn completed successfully!!'
        done=1
    else
        echo '======== git svn failed.  looping...'
        num_fails=`expr $num_fails + 1`
        if test $num_fails -gt 20; then
            stop=`date`
            echo "====== hmmm... lotsa failures... exiting..."
            echo "===== GIT SVN CONVERT FAILED"
            echo "===== START: $start"
            echo "===== STOP:  $stop"
            pushover SVN git clone failed
            exit 1
        fi
        sleep 2
    fi
done
stop=`date`
echo "===== GIT SVN CONVERT DONE"
echo "===== START: $start"
echo "===== STOP:  $stop"

# Save step 1
cd ..
echo '=========== SAVING GIT SVN CLONE'
tar jcf $rname-1-after-clone.tar.bz2 $rname
cd $rname

# Delete the "tim" and "orte" branches; we don't need those in the
# final OMPI git repos.
echo ----------- Deleting stale branches
git branch -D tim
git branch -D orte

# Run the preprocess step
echo ----------- Running preprocess
$scripts_dir/preprocess-repo.sh

# Save step 2
cd ..
echo '============ SAVING AFTER PREPROCESS'
tar jcf $rname-2-after-preprocess.tar.bz2 $rname

echo ----------- Running git filter-branch
cd $rname
rm -f /tmp/gfb-$USER.log

# This version of git works with our git filter-branch command
module unload cisco/git
module load cisco/git/1.8.2.1

git filter-branch --commit-filter "$scripts_dir/convert-ompi.pl"' "$@"' --tag-name-filter cat -- --all --date-order
git for-each-ref --format="%(refname)" refs/original/ | xargs -n 1 git update-ref -d

# Save step 3
cd ..
echo '============ SAVING FILTERED TREE'
tar jcf $rname-3-after-filter.tar.bz2 $rname

# Manually patch up tags.  OMPI stores them in a slightly non-standard
# way in SVN, so do this semi-manually.

# First, delete the existing tags.
foreach tag `git tag`
    git tag -d $tag
done

$DOTFILES/pushover git svn conversion script FINISHED
