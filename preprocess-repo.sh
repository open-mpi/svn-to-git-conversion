#!/bin/zsh

set -x

# clean up config entries from git-svn
git config --local --remove-section svn
git config --local --remove-section svn-remote.svn

# DJG: not sure why this was here, possibly different env when doing original
# script development back in June?  What would have caused per-branch local
# config to appear...?
#for ref in $( git for-each-ref --format="%(refname)" refs/heads/ ) ; do
#    b=${ref#refs/heads/}
#    git config --local --remove-section branch.$b
#done

# replace all remote tracking branches with regular "local" branches (the trunk
# needs special handling to become "master" instead)
if [[ "$(git rev-parse refs/remotes/origin/trunk)" != "$(git rev-parse master)" ]] ; then
    echo "ERROR: trunk != master for some reason (forgot to 'git svn rebase'?)"
    exit 1
fi
git update-ref -d refs/remotes/origin/trunk
for ref in $( git for-each-ref --format="%(refname)" refs/remotes/ ) ; do
    local_ref=${ref#refs/remotes/}
    case $local_ref in
        tags/*)
            local_tag=${local_ref#tags/}

            # transform the tag branches into real git tags, taking the
            # committer/author (should be same here) info from the commit at
            # the tip of the branch (presumably the tagger)
            #
            # DJG: if the (brief) annotated tag messages are unacceptable for
            # some reason, take the tag message from the tip commit and pass it
            # to "git tag" with the "-F" option (via a file).
            GIT_COMMITTER_DATE="$(git log -1 --pretty="%ci" $ref)" \
            GIT_COMMITTER_NAME="$(git log -1 --pretty="%cN" $ref)" \
            GIT_COMMITTER_EMAIL="$(git log -1 --pretty="%cE" $ref)" \
            GIT_AUTHOR_DATE="$(git log -1 --pretty="%ai" $ref)" \
            GIT_AUTHOR_NAME="$(git log -1 --pretty="%aN" $ref)" \
            GIT_AUTHOR_EMAIL="$(git log -1 --pretty="%aE" $ref)" \
            git tag -a -m "tag $local_tag" $local_tag $ref
            ;;
        origin/*)
            # just make a local branch by the same (base) name pointing to the
            # same commit, but remove "origin/" from the prefix
            local_branch=${local_ref#origin/}
            git branch $local_branch $ref
            ;;
        *)
            # just make a local branch by the same (base) name pointing to the
            # same commit
            git branch $local_ref $ref
            ;;
    esac

    # now delete the "remotes/" ref
    git update-ref -d $ref
done

