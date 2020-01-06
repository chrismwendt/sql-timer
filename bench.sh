#!/usr/bin/env bash

set -e

# repo=github.com/goodrain/rainbond-ui
# commit=81b7339a86281a54ff553d391205f52b86f0db28
repo=github.com/moby/moby
commit=8d588d9c5b5cd019e09bcfc4f790eae79405c7b1

gtruncate --size 0 data.txt

if true; then
    i=0
    git --git-dir=/Users/chrismwendt/.sourcegraph/repos/github.com/moby/moby/.git log --pretty="%H" --first-parent master | while IFS= read -r line; do
        i=$((i+1))
        commit=$line
        echo "commit $line"

#         psql <<EOF | grep "Time:" | gsed "s/Time: \([[:digit:]]*\).*/\1/" | jq -Rc "[$i, (. | tonumber), null]" >> data.txt
#             \timing
#             with recursive lineage(repository, "commit", parent_commit, has_lsif_data, distance, direction) as (
#                 -- seed result set with the target repository and commit marked
#                 -- with both ancestor and descendant directions
#                 select l.* from (
#                     select c.*, 0, 'A' from lsif_commits_with_lsif_data c union
#                     select c.*, 0, 'D' from lsif_commits_with_lsif_data c
#                 ) l
#                 where l.repository = '$repo' and l."commit" = '$commit'

#                 union

#                 -- get the next commit in the ancestor or descendant direction
#                 select c.*, l.distance + 1, l.direction from lineage l
#                 join lsif_commits_with_lsif_data c on (
#                     (l.direction = 'A' and c.repository = l.repository and c."commit" = l.parent_commit) or
#                     (l.direction = 'D' and c.repository = l.repository and c.parent_commit = l."commit")
#                 )
#                 -- limit traversal distance
#                 where l.distance < 100000
#             )

#             -- lineage is ordered by distance to the target commit by
#             -- construction; get the nearest commit that has LSIF data
#             select l."commit" from lineage l where l.has_lsif_data limit 1;
# EOF

        psql <<EOF | grep "Time:" | gsed "s/Time: \([[:digit:]]*\).*/\1/" | jq -Rc "[$i, (. | tonumber), null]" >> data.txt
            \timing
            -- traverse commit graph to find all ancestors of the target repo/commit
            with recursive ancestors(repository, "commit", parent_commit, has_lsif_data) as (
                select c.* from lsif_commits_with_lsif_data c where c.repository = '$repo' and c."commit" = '$commit'
                union
                select c.* from ancestors a join lsif_commits_with_lsif_data c on c.repository = a.repository and c."commit" = a.parent_commit
            ),
            -- traverse commit graph to find all ancestors of the target repo/commit
            descendants(repository, "commit", parent_commit, has_lsif_data) as (
                select c.* from lsif_commits_with_lsif_data c where c.repository = '$repo' and c."commit" = '$commit'
                union
                select c.* from descendants d join lsif_commits_with_lsif_data c on c.repository = d.repository and c.parent_commit = d."commit"
            )
            -- Select ancestors and descendants up to the traversal limit. We'll get results back from
            -- each CTE above in the order it's calculated (the traversal depth). We can add the row
            -- index to the results so when we union we can sort them relatively rather than looking
            -- through all ancestors, then through all descendants.
            select t."commit" from (
                select * from (select a.*, row_number() over () as n from ancestors a limit 1000) as f
                union
                select * from (select d.*, row_number() over () as n from descendants d limit 1000) as q
            ) t
            where t.has_lsif_data -- return only relatives with data
            order by t.n          -- order by the distance fr
            limit 1;              -- return the winner
EOF

        psql <<EOF | grep "Time:" | gsed "s/Time: \([[:digit:]]*\).*/\1/" | jq -Rc "[$i, null, (. | tonumber)]" >> data.txt
            \timing
            with recursive lineage(repository, "commit", parent_commit, has_lsif_data, direction) as (
                -- seed result set with the target repository and commit marked
                -- with both ancestor and descendant directions
                select l.* from (
                    select c.*, 'A' from lsif_commits_with_lsif_data c union
                    select c.*, 'D' from lsif_commits_with_lsif_data c
                ) l
                where l.repository = '$repo' and l."commit" = '$commit'

                union

                -- get the next commit in the ancestor or descendant direction
                select c.*, l.direction from lineage l
                join lsif_commits_with_lsif_data c on (
                    (l.direction = 'A' and c.repository = l.repository and c."commit" = l.parent_commit) or
                    (l.direction = 'D' and c.repository = l.repository and c.parent_commit = l."commit")
                )
            )

            -- lineage is ordered by distance to the target commit by
            -- construction; get the nearest commit that has LSIF data
            select l.commit from (SELECT * FROM lineage LIMIT 1000000) l where l.has_lsif_data limit 1;
EOF
    done
else
    while true; do
        x="$(echo|awk -v seed=$RANDOM 'BEGIN{srand(seed);}{print rand()" "$0}')"

        limit="$(echo "e(4 * $x)" | bc -l)"
        echo "limit $limit"

        psql <<EOF | grep "Time:" | gsed "s/Time: \([[:digit:]]*\).*/\1/" | jq -Rc "[$limit, (. | tonumber), null]" >> data.txt
            \timing
            with recursive lineage(repository, "commit", parent_commit, has_lsif_data, distance, direction) as (
                -- seed result set with the target repository and commit marked
                -- with both ancestor and descendant directions
                select l.* from (
                    select c.*, 0, 'A' from lsif_commits_with_lsif_data c union
                    select c.*, 0, 'D' from lsif_commits_with_lsif_data c
                ) l
                where l.repository = '$repo' and l."commit" = '$commit'

                union

                -- get the next commit in the ancestor or descendant direction
                select c.*, l.distance + 1, l.direction from lineage l
                join lsif_commits_with_lsif_data c on (
                    (l.direction = 'A' and c.repository = l.repository and c."commit" = l.parent_commit) or
                    (l.direction = 'D' and c.repository = l.repository and c.parent_commit = l."commit")
                )
                -- limit traversal distance
                where l.distance < $limit
            )

            -- lineage is ordered by distance to the target commit by
            -- construction; get the nearest commit that has LSIF data
            select l."commit" from lineage l where l.has_lsif_data limit 1;
EOF

        limit="$(echo "e(6 * $x)" | bc -l)"
        echo "limit $limit"

        psql <<EOF | grep "Time:" | gsed "s/Time: \([[:digit:]]*\).*/\1/" | jq -Rc "[$limit, null, (. | tonumber)]" >> data.txt
            \timing
            with recursive lineage(repository, "commit", parent_commit, has_lsif_data, direction) as (
                -- seed result set with the target repository and commit marked
                -- with both ancestor and descendant directions
                select l.* from (
                    select c.*, 'A' from lsif_commits_with_lsif_data c union
                    select c.*, 'D' from lsif_commits_with_lsif_data c
                ) l
                where l.repository = '$repo' and l."commit" = '$commit'

                union

                -- get the next commit in the ancestor or descendant direction
                select c.*, l.direction from lineage l
                join lsif_commits_with_lsif_data c on (
                    (l.direction = 'A' and c.repository = l.repository and c."commit" = l.parent_commit) or
                    (l.direction = 'D' and c.repository = l.repository and c.parent_commit = l."commit")
                )
            )

            -- lineage is ordered by distance to the target commit by
            -- construction; get the nearest commit that has LSIF data
            select l.commit from (SELECT * FROM lineage LIMIT $limit) l where l.has_lsif_data limit 1;
EOF
    done
fi
