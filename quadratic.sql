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
    where l.distance < 100
)
-- lineage is ordered by distance to the target commit by
-- construction; get the nearest commit that has LSIF data
select l."commit" from lineage l where l.has_lsif_data limit 1;