For posterity:

Used the tratihubis package to convert Trac tickets to Github Issues.
Used v0.5 of the package -- the upstream git version of Tratihubis had
more features, but I couldn't get it to work properly (seems like it's
still under dev).  So I used 0.5, with some tweaks (see below).

First, you export all the tickets you want from Trac using custom SQL
reports (download to CSV files).  Then I post-processed some of the
text from the CSV files, and then used tratihubis to use the GitHub
APIs to open issues, add comments, add milestones and labels, and
assign the issue to a github ID.

My process was, of course, somewhat customized to Open MPI.  So I
record these notes here for posterity / in case we ever need them
again.

I installed tratihubis locally on my Mac.  Unfortunately, I did not
keep good notes on that, so that knowledge is somewhat lost (I think I
needed to install PyGithub v1.25.0 locally as well).  But I have
git-saved the final tratihubis source code that I used (v0.5 + some
tweaks; see below).  So in theory, the process is still repeatable.

------

Use these reports on trac:

export tickets:
-----
-- All Trac tickets to convert.
select
    id,
    type,
    owner,
    reporter,
    milestone,
    status,
    resolution,
    summary,
    description,
    time / 1000000 as PosixTime,
    changetime / 1000000 as ModifiedTime,
    priority
from
    ticket
WHERE
    status <> 'closed' and type <> 'changeset move request'
order
    by id
-----

export ticket comments:
-----
-- All Trac ticket comments to convert.
select
    ticket,
    time / 1000000 as PosixTime,
    author,
    newvalue
from
    ticket_change
where
    field = 'comment'
    and newvalue <> ''
order
    by ticket, time
----

export ticket attachments
----
-- All trac attachments to link to 
SELECT 
  id, 
  filename, 
  time / 1000000 as PosixTime,
  author 
from attachment
order by id asc
-----

export ticket owners and reporters
-----
-- All Trac tickets to convert.
select
    id,
    owner,
    reporter
from
    ticket
WHERE
    status <> 'closed' and type <> 'changeset move request'
order
    by id
-----

After downloading, I post-processed tickets.csv and comments.csv

- trivial {{{}}} replacement to ```
- replaced #foo with https: link to trac ticket (I did not invest the
time to add logic to track mapping of track ticket numbers to github
issue numbers)

I had to extend tratihubis:
  - allow org= keyword in .cfg file (i.e., so it would operate on a
    GitHub organization repo, not just a personal repo)
  - allow using "priority" as a label selector in tratihubis.cfg

My process was:

- ran all the reports above and downloaded CSVs for all.  Saved as:
  tickets.csv, comments.csv, attachments.csv, and
  owners-reporters.csv.
  - edit attachments.csv and remove all wiki page attachments (the SQL
    selected *all* attachments, not just *ticket* attachments)
- ran convert.pl to process tickets.csv and comments.csv
- Do this with a test repo on github:
  - Make the desired github issue labels: RFC, documentation, minor,
    criticial, blocker
  - Remove "question" and "need help" default issue labels
  - run without --really; ensure it works
  - unwatch the test repo
  - run with --really; ensure that it works
- interate on the above many times until I got everything right
- when happy, run it against real ompi repo without --really
  - ensure that it all works
- then run again on the real ompi repo with --really
...#@$%@#$% it died in the middle of issue #98!

Because ...someone... had not accepted the invitation to the github
repo, so when tratihubus tried to assign a ticket to this person, it
barfed.  I got him to accept it, found that 2 others hadn't accepted
(manjugv and vasilyMellanox), and so I removed them from the "users"
block in tratihubis.cfg.  I then made a copy of tickets.csv named
tickets-starting-with-2224.csv (i.e., the ticket it tried to convert
and failed), deleted all tickets before 2224 from that file, and
edited tratihubis.cfg to use that file so that it would continue where
it left off.

The same thing happened with ...someone else... who wasn't even
invited to the ompi repo (oops; I thought tratihubis checked that
during startup, but apparently not...).  Had to restart again with
ticket 4104.
