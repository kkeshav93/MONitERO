\timing on
-- Create views to store ringsize and effective ringsize

CREATE MATERIALIZED VIEW txi AS
SELECT inid,txid,keyimg, ringsize, effective_ringsize
FROM txin natural join
(	SELECT inid
	,	count(*) as ringsize
	,	count(case
				when matched <> 'mixin' then 1 -- This should be somewhat faster
				-- when matched = 'unknown' then 1
				-- when matched = 'real' then 1
				-- when matched = 'spent' then 1
			end) as effective_ringsize
	FROM ring
	GROUP BY inid
	ORDER BY inid asc
) as a;

CREATE MATERIALIZED VIEW ringtime AS
WITH it as (select
		time as spendtime
	,	block as spendheight
	,	inid
	from txin natural join tx)
, ot as (select
		time as outtime
	,	block as outheight
	,	outid
	from txout natural join tx)
SELECT inid,outid, matched,spendtime-outtime as age, spendheight-outheight as block_diff, spendtime, spendheight --, outtime 
FROM ring
	join it using(inid)
	join ot using(outid);

