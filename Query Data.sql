
select distinct financialMetric from financialData where description is null;

select * from financialData limit 3000;

select units, count(*) as cnt from financialData

GROUP by units

order by cnt desc;

select cd.cik, fd.financialPeriod, fd.financialMetric, fd.label, fd.value, fd.description, form, endDate, financialYear, financialPeriod, s.filingDate, s.accessionNumber from financialData fd,companyDimension cd,submissions s
where cd.firstTicker = 'MSFT' and cd.cik=fd.cik and s.accessionNumber=fd.accessionNumber
and  form='10-K' and financialYear=2025

order by financialMetric asc, value desc
