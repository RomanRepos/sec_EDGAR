
select distinct financialMetric from financialData where description is null;

select * from financialData limit 3000;

select units, count(*) as cnt from financialData

GROUP by units

order by cnt desc;

select * from financialData anti join submissions on financialData.accessionNumber = submissions.accessionNumber inner join companyDimension on financialData.cik=companyDimension.cik;



