These scripts were used to convert various OMPI SVN repos to git.

The "simple" SVN repos (ompi-docs, ompi-tests, otpo) basically did the
same thing as the big/complicated SVN repo (ompi), but basically
didn't need to do as many steps.

Note that this git conversion procedure only works with git v1.8.2.1.
There is a bug in later versions regarding "git filter-branch" that, as
of this writing (Sep 2014), has not bee fixed.  We previously found
the bug report about this to confirm that it's an actual git bug, but
I didn't save the URL reference, sorry.  Perhaps a future version of
git will fix the bug, but we used 1.8.2.1 for this conversion.

SIDENOTE: Re-reading this README over a year after I wrote it (in Dec
     2015), I realize I left out a key assumption from the text: when
     we switched to Git, the Open MPI SVN repository was up to r32823.
     Meaning: it was a *giant* SVN repo.  That's why the conversion
     process took 8+ hours, why we tried to factor in network delay
     when accessing the remote SVN server, etc.  If your SVN repo has
     far fewer commits, some of time-saving techniques that we tried
     to use probably won't apply to you -- e.g., your conversion could
     take just a few minutes.  If you're coming here from outside the
     Open MPI project, you will likely mainly care about steps 4
     (preprocess) and 6 (re-writing commit messages to include SVN r
     numbers, cross references to new git commit hashes, etc.).

For Open MPI, the main script is "runme.sh".  In the final iteration,
it used a svnsync local copy of the OMPI repo.  It saved a bit of time
in the early commit conversion, but as the r numbers increased, the
conversion time became increasingly dominated by local computation.
So the use of a local repo wasn't as much of a win as I had hoped.

runme.sh does several main steps:

1. if told to, it will git svn init a new repo
   OR
   it will restore a tarball from a prior git svn init

This is really important: the git svn conversion will take MANY HOURS
(8+ hours).

This conversion was a many step process; it took about a month to
develop these scripts and get them right.  Hence, we did the SVN->Git
conversion many, many times.

But as noted above, an individual svn->git conversion takes many
hours.  So we adopted the strategy of doing the basic svn->git
conversion, and then saving a tarball of the result.  Then if we ran
the overall conversion a few days later (and there have been more svn
commits since then), we could just untar the tarball from a few days
prior, do a "git svn rebase" to get new commits, and then proceed from
there.  I.e., we didn't have to wait 8+ hours to convert the whole SVN
history again.

Hence: this first step lets you either git svn init with an empty
repo, or untar to get a git svn repo.

Note that in the git svn init step, since OMPI's SVN chose to do a
weird thing for its tagging, I manually added the right refs for where
OMPI's SVN tags live.

2. I have a separate repo with the SVN ID -> email address mappings
called "open-mpi/authors" (at Github).  In hindsight, it could have
put that file in this repo, but oh well.

3. Then it does a git svn fetch to get all the latest SVN commits.

Note that it loops over the git svn fetch, because sometimes a
network error will interrupt the git svn network activity.  Most of
times the errors were just transient; you can restart the operation
and it's fine.

Then we do a git svn rebase, just for good measure.

===> Save a tarball.

4. Run the runme-preprocess-git-repo.sh script.  This is magic from
Dave Goodell.  I never bothered to understand what it does; he tells
me it's necessary and I trust him.

===> Save another tarball.

5. Over OMPI's history, we've had some branches that are just stale.
They've actually been removed from SVN, but git svn will be
conservative and keep them.

So there's some manual commands to remove those old/stale branches.

6. Then we run some real magic: git filter-branch.  This invokes the
runme-git-filter-branch-hook.pl script for each commit.  This script
re-writes the commit message and adds 3 general kinds of annotations:

6a. "This was SVN commit rXXXX" indicating the original SVN r number.
6b. Finds refernces to other r numbers in the commit message and lists
    their corresponding new git hashes
6c. Finds references to Trac tickets in the commit message and lists
    URLs to the old tickets (Trac is being left operating in a
    read-only mode).

===> Save another tarball.

7. Run the runme-fix-tags.pl script to fixup all the git tags.  We've
done some strange things with tags in SVN over the years, and git svn
does its best, but it finally just took a human to hard-code the Right
tags values.

===> Save another tarball.

Done!

I then manually ran push-to-github.pl, which pushed master to
github:open-mpi/ompi and all the release branches to
github:open-mpi/ompi-release (we have different push permissions on
these 2 repos; developers can push to ompi and only release managers
can push to ompi-release.  Hopefully, github will support per-branch
ACLs someday and we can collapse back down to one repo).

To convert the "simpler" repos, their respective runme scripts
basically just do steps 1-4.  They were *significantly* smaller SVN
repos, so the git svn conversion only took a few minutes.
