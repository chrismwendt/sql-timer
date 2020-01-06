CREATE OR REPLACE FUNCTION closest_dump(repository text, "commit" text) RETURNS SETOF lsif_dumps AS $$
    DECLARE
        temprow record;
        onedump lsif_dumps%ROWTYPE;
    BEGIN
        FOR temprow IN
            WITH RECURSIVE lineage(id, repository, "commit", parent_commit, direction) AS (
                -- seed result set with the target repository and commit marked by traversal direction
                SELECT l.* FROM (
                    SELECT c.*, 'A' FROM lsif_commits c WHERE c.repository = $1 AND c."commit" = $2
                    UNION
                    SELECT c.*, 'D' FROM lsif_commits c WHERE c.repository = $1 AND c."commit" = $2
                ) l
                UNION
                -- get the next commit in the ancestor or descendant direction
                SELECT * FROM (
                    WITH l_inner AS (SELECT * FROM lineage)
                    SELECT c.*, l.direction FROM l_inner l
                        JOIN lsif_commits c
                        ON l.direction = 'A' and c.repository = l.repository AND c.parent_commit = l."commit"
                    UNION
                    SELECT c.*, l.direction FROM l_inner l
                        JOIN lsif_commits c
                        ON l.direction = 'D' AND c.repository = l.repository AND c."commit" = l.parent_commit
                ) subquery
            )

            SELECT * FROM lineage l
        LOOP
            SELECT d.id, d.repository, d.commit, d.root INTO onedump FROM lsif_dumps d WHERE d.repository = temprow.repository AND d.commit = temprow.commit;
            IF onedump.id IS NOT NULL THEN
                RETURN NEXT onedump;
                RETURN;
            END IF;
        END LOOP;
    END;
$$ LANGUAGE plpgsql;

-- CREATE OR REPLACE FUNCTION closest_dump(repository text, "commit" text) RETURNS SETOF lsif_dumps AS $$
--     DECLARE
--         temprow record;
--     BEGIN
--         FOR temprow IN
--             WITH RECURSIVE lineage(id, repository, "commit", parent_commit, direction) AS (
--                 -- seed result set with the target repository and commit marked by traversal direction
--                 SELECT l.* FROM (
--                     SELECT c.*, 'A' FROM lsif_commits c WHERE c.repository = $1 AND c."commit" = $2
--                     UNION
--                     SELECT c.*, 'D' FROM lsif_commits c WHERE c.repository = $1 AND c."commit" = $2
--                 ) l
--                 UNION
--                 -- get the next commit in the ancestor or descendant direction
--                 SELECT * FROM (
--                     WITH l_inner AS (SELECT * FROM lineage)
--                     SELECT c.*, l.direction FROM l_inner l
--                         JOIN lsif_commits c
--                         ON l.direction = 'A' and c.repository = l.repository AND c.parent_commit = l."commit"
--                     UNION
--                     SELECT c.*, l.direction FROM l_inner l
--                         JOIN lsif_commits c
--                         ON l.direction = 'D' AND c.repository = l.repository AND c."commit" = l.parent_commit
--                 ) subquery
--             )

--             SELECT * FROM lineage l
--         LOOP
--             IF EXISTS (SELECT * FROM lsif_dumps d WHERE d.repository = temprow.repository AND d.commit = temprow.commit) THEN
--                 RETURN QUERY SELECT * FROM lsif_dumps d WHERE d.repository = temprow.repository AND d.commit = temprow.commit;
--             END IF;
--         END LOOP;
--     END;
-- $$ LANGUAGE plpgsql;