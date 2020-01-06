-- EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS, FORMAT JSON)
\timing
with recursive lineage(id, repository, "commit", parent_commit, direction) as (
    -- seed result set with the target repository and commit marked
    -- with both ancestor and descendant directions
    select l.* from (
        select c.*, 'A' from lsif_commits c where c.repository = '$repo' and c."commit" = '$commit'
        union
        select c.*, 'D' from lsif_commits c where c.repository = '$repo' and c."commit" = '$commit'
    ) l

    union

    -- get the next commit in the ancestor or descendant direction
    select * from (
        with l_inner as (SELECT * FROM lineage)

        select c.*, l.direction from l_inner l
        join lsif_commits c on (
            (l.direction = 'A' and c.repository = l.repository and c.parent_commit = l."commit")
        )

        union

        select c.*, l.direction from l_inner l
        join lsif_commits c on (
            (l.direction = 'D'  and c.repository = l.repository and c."commit" = l.parent_commit)
        )
    ) subquery
)

-- lineage is ordered by distance to the target commit by
-- construction; get the nearest commit that has LSIF data
SELECT l.commit FROM (SELECT *, row_number() OVER () as n FROM lineage LIMIT 10000) l
WHERE EXISTS (SELECT * FROM lsif_dumps dump WHERE l.repository = dump.repository and l."commit" = dump."commit")
ORDER BY n
LIMIT 1