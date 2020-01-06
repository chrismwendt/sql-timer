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
    select * from (select a.*, row_number() over () as n from ancestors a limit 10000) as f
    union
    select * from (select d.*, row_number() over () as n from descendants d limit 10000) as q
) t
where t.has_lsif_data -- return only relatives with data
order by t.n          -- order by the distance fr
limit 1;              -- return the winner