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

# Sanity check
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
$scripts_dir/preprocess-repo.sh

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

# Delete any tags that git svn created with "@" -- these are saved
# versions of tags when tags were replaced in SVN (we don't care about
# history of tags; we just want the final value).  There were a few
# incorrectly-created tags, too -- tags that were "vX.Y", instead of
# "vX.Y.Z" (git svn saw them created, but ignored when they were
# deleted).  Delete those incorrect tags, too.
for tag in `git tag`; do
    echo tags are: $tag
    if test "`echo $tag | grep @`" != ""; then
        git tag -d $tag
    elif test "`echo $tag | grep '^v[0-9].[0-9]$'`" != ""; then
        git tag -d $tag
    fi
done

# We have one case where we have a branch and a tag of the same name.
# To avoid developer annoyance with git warnings about this, rename
# the tag to be "<foo>-tag".
hash=`git rev-parse refs/tags/v1.8.1`
git tag -d v1.8.1
git tag v1.8.1-tag $hash

# Rewrite SVN commit messages to translate SVN r numbers and Trac
# ticket numbers.
echo ----------- Running git filter-branch
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
cd $rname

$DOTFILES/pushover git svn conversion script FINISHED
