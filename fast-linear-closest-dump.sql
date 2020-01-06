-- EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS, FORMAT JSON)
\timing
select commit from closest_dump('$repo', '$commit');