#!/bin/zsh

set -x

# Customize to suit
base=$HOME/git/ompi-svn-to-git-conversion-aug-2014
scripts_dir=$base/scripts
repo=ompi-docs
rname=$repo-svn-to-git
rdir=$base/$rname
svn_url=https://svn.open-mpi.org/svn/$repo

do_svn_init=1

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
            $DOTFILES/pushover git svn clone FAILED
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

# All done!
$DOTFILES/pushover git svn conversion script FINISHED
