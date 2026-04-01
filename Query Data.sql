
select distinct financialMetric from financialData where description is null;

select * from financialData limit 3000;

select units, count(*) as cnt from financialData

GROUP by units

order by cnt desc;

select distinct accn from financialData inner join submissions on financialData.accn = submissions.accessionNumber

