#!/bin/zsh

set -x

# Customize to suit
base=$HOME/git/ompi-svn-to-git-conversion-aug-2014
scripts_dir=$base/scripts
rname=ompi-svn-to-git
rdir=$base/$rname
svn_url=https://svn.open-mpi.org/svn/ompi

# Make sure we have the latest / greatest
module unload cisco/git
module load cisco/git/2.1.0

cd $base
rm -rf $rname

do_svn_clone=1
num_fails=0

if test "$do_svn_clone" -eq 1; then
    # Do the git svn clone
    start=`date`
    echo "===== STARTING: $start"

    git svn init -s $svn_url $rname
    cd $rname

    git config svn.authorsfile $scripts_dir/authors.txt

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
    echo '=========== SAVING GIT SVN CLONE'
    tar jcf $rname-1-after-clone.tar.bz2 $rname
else
    # Extract the git svn clone
    tar xf $rname-1-after-clone.tar.bz2
fi
cd $rname

# Get the latest.
# Just to master and v1.8 branch; as of this writing (Aug 2014), those
# are the only 2 SVN branches will be be changing.
echo ----------- Running git svn rebase
git checkout master
git svn rebase
git checkout -b convert-v1.8 remotes/v1.8
git svn rebase
git checkout master

cd ..
echo '============ SAVING AFTER GIT SVN REBASE'
tar jcf $rname-1.5-after-svn-rebase.tar.bz2 $rname
cd $rname

# Delete the "tim" and "orte" branches; we don't need those in

# Run the preprocess step
echo ----------- Running preprocess
$scripts_dir/preprocess-repo.sh

# Kill the branch we made above to rebase
git branch -D convert-v1.8

# Save step 2
cd ..
echo '============ SAVING AFTER PREPROCESS'
tar jcf $rname-2-after-preprocess.tar.bz2 $rname

echo ----------- Running git filter-branch
cd $rname
rm -f /tmp/gfb-$USER.log
# JMS Dave would like to see the error message from git 1.8.5.x here
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
