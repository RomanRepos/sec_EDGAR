
select distinct financialMetric from financialData where description is null;

select count(*) from financialData;
select * from financialData
anti join submissions on submissions."accessionNumber" = "financialData"."accessionNumber";



select cd.cik, cd."entityName", fd.financialPeriod, fd.financialMetric, fd.label, fd.value, fd.description, form, endDate, financialYear, financialPeriod, s.filingDate, s.accessionNumber, fd.frame, fd."startDate" from financialData fd,companyDimension cd,submissions s
where cd.firstTicker = 'MSFT' and cd.cik=fd.cik and s.accessionNumber=fd.accessionNumber and "financialYear"=2025
and  form='10-K'

order by financialMetric asc, value desc



