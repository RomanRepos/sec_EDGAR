
select distinct financialMetric from financialData where description is null;

select count(*) from financialData;
select * from financialData
anti join submissions on submissions."accessionNumber" = "financialData"."accessionNumber";



select cd.cik, fd.financialPeriod, fd.financialMetric, fd.label, fd.value, fd.description, form, endDate, financialYear, financialPeriod, s.filingDate, s.accessionNumber, fd.frame, fd."startDate" from financialData fd,companyDimension cd,submissions s
where cd.firstTicker = 'MSFT' and cd.cik=fd.cik and s.accessionNumber=fd.accessionNumber
and  form='10-K' and financialYear=2025 and (fd.frame is null or fd.frame='CY2025' )and fd."endDate"='2025-06-30'

order by financialMetric asc, value desc



