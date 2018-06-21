-- IR works somewhat differently on multiple chains.
-- For each set of inputs, get set of keyimgs
-- If #(set of inputs) = #(keyimgs), there is an intersection.

-- Extremely unlikely, though implemented for shit & giggles

-- Note that for forks not only outid but also fork_outids have to be considered as possible real input.
-- To prevent matches if xmv_/xmo_ outids are by chance the same (will never happen but whatever), take negative value of those.

\timing on
-- Intersections on one chain
drop table if exists intersections;
create table intersections as
select outs
	, array_agg(inid order by inid) as ins
	, #outs as num_out
from (select inid
		, array_agg(outid order by outid) as outs
		from ring
		where matched = 'spent'
		group by 1) as a
group by 1;


drop table if exists cross_chain_intersections; -- takes forever, most likely results in empty table
create table cross_chain_intersections as
select array_agg(chain order by chain) as chains, outs, array_agg(keyimg order by keyimg) as keyimgs
from (
	(select 1 as chain, keyimg, array_agg(outid order by outid) as outs from ring natural join txi
	where undecided(matched) group by 1,2)
	union
	(select 2 as chain, keyimg, array_agg(coalesce(outid,-xmv_outid)order by outid) as outs from xmv_ring natural join xmv_txi
	where undecided(matched) group by 1,2)
	union
	(select 3 as chain, keyimg, array_agg(coalesce(outid,-xmo_outid)order by outid) as outs from xmo_ring natural join xmo_txi
	where undecided(matched) group by 1,2)
) as a
group by outs having count(distinct keyimg) = #outs and count(distinct chain) > 1;



--! Used for figure
drop table if exists count_intersections;
create table count_intersections as 
select date_trunc('month', time )::date as month
	, count(*) as total
	, count(case when num_out = ringsize then 1 end)  as trivial
	, count(case when num_out < ringsize then 1 end) as nontrivial
	-- , round(count(case when valid then 1 end)::numeric / count(*), 4) as accuracy
from tx natural join txin natural join 
(select inid, num_out, count(outid)  as ringsize from ring natural join (select unnest(ins) as inid, num_out from intersections) as a group by 1,2) as intersection_inputs
group by 1
order by 1 asc;

-- Compare numbers to Wiyita et al 2018
select ins as intersection_set, min(block) as minblock, max(block), maxblock
from (select ins, num_out, unnest(ins) as inid from intersections) as a
natural join txi
natural join tx
where
    block < 1470000
    and ringsize = num_out
group by 1 
order by 2 asc;

-- Compare numbers to Wiyita et al 2018
select count(ins) as intersections, count(distinct ins) as distinct_intersections, count(distinct txid) as diff_TXs
from (select ins, num_out, unnest(ins) as inid from intersections) as a
natural join txi
natural join tx
where
    block < 1470000
    and ringsize = num_out;