-- EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS, FORMAT JSON)
\timing
with recursive lineage(repository, "commit", parent_commit, has_lsif_data) as (
    -- seed result set with the target repository and commit marked
    -- with both ancestor and descendant directions
    select l.* from (
        select c.* from lsif_commits_with_lsif_data c where c.repository = '$repo' and c."commit" = '$commit'
        union
        select c.*from lsif_commits_with_lsif_data c where c.repository = '$repo' and c."commit" = '$commit'
    ) l

    union

    -- get the next commit in the ancestor or descendant direction
    select * from (
        with l_inner as (SELECT * FROM lineage)

        select c.*from l_inner l
        join lsif_commits_with_lsif_data c on (
            (c.repository = l.repository and c.parent_commit = l."commit")
        )

        union

        select c.* from l_inner l
        join lsif_commits_with_lsif_data c on (
            (c.repository = l.repository and c."commit" = l.parent_commit)
        )
    ) subquery
)

-- lineage is ordered by distance to the target commit by
-- construction; get the nearest commit that has LSIF data
select l.commit from (SELECT * FROM lineage LIMIT 10000) l where l.has_lsif_data limit 1;