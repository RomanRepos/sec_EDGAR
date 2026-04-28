
select distinct name from financialData where description is null;

select count(*) from financialData;
select * from financialData
anti join submissions on submissions."accessionNumber" = "financialData"."accessionNumber";



select cd.cik, fd.prefix, cd."entityName", fd.units,fd.financialPeriod, fd.name, fd.label, fd.value, fd.description, form, endDate, financialYear, financialPeriod, s.filingDate, s.accessionNumber, fd.frame, fd."startDate" from financialData fd,companyDimension cd,submissions s
where cd.cik=fd.cik and s.accessionNumber=fd.accessionNumber AND name ='PayablesToBrokerDealersAndClearingOrganizations';


select count(*) as uniqueDescr from (select distinct label from financialData );

select Distinct name, label, description from financialData
order by name;

select * from companyDimension where firstTicker='MSFT';


select companyDimension.cik, fd_gaap.prefix, fd_ifrs.prefix from companyDimension
left outer join (select distinct cik, prefix  from financialData where prefix='us-gaap') as fd_gaap on companyDimension.cik = fd_gaap.cik
left outer join (select distinct cik, prefix from financialData  where prefix='ifrs-full' ) as fd_ifrs on companyDimension.cik = fd_ifrs.cik;


select count(*) from (select distinct name from financialData where prefix='us-gaap') as gaapCount;

select count(*) from (select distinct ancestorName from calculationTaxonomy where ancestorPrefix='us-gaap') as gaapCount;



SELECT
    cik,
    accessionNumber,
    startDate,
    endDate,
    name,
    units,
    prefix,
    COUNT(*) AS occurrence_count
FROM financialData
GROUP BY accessionNumber, name, startDate, endDate, units,cik, prefix
HAVING COUNT(*) > 1
ORDER BY accessionNumber, occurrence_count DESC;


SELECT
name,
count(*) as count
FROM (select distinct name from financialData) as financialData left outer join (select distinct definition, ancestorName from calculationTaxonomyHierarchy) as ct on financialData.name = ct.ancestorName
GROUP BY name
HAVING count>1
ORDER BY count desc;


select distinct label from presentationTaxonomy;


ALTER TABLE my_table ADD COLUMN partition_number INT;

WITH ranked AS (
    SELECT
        ctid,  -- or your primary key
        DENSE_RANK() OVER (ORDER BY col1, col2) AS rn
    FROM my_table
)
UPDATE my_table t
SET partition_number = r.rn
FROM ranked r
WHERE t.ctid = r.ctid;



ALTER TABLE financialData ADD COLUMN partitionNumber INTEGER;

UPDATE financialData
SET partitionNumber = g.rn
FROM (
    SELECT cik,
    financialData.accessionNumber,
    startDate,
    endDate,
    prefix, form, frame, DENSE_RANK() OVER (ORDER BY cik,
    financialData.accessionNumber,
    startDate,
    endDate,
    prefix, form, frame) AS rn
    FROM financialData left OUTER join (select accessionNumber, form from submissions) as s on financialData.accessionNumber = s.accessionNumber
    GROUP BY cik,
    financialData.accessionNumber,
    startDate,
    endDate,
    prefix,
    form, frame
) g
WHERE financialData.cik IS NOT DISTINCT FROM g.cik
  AND financialData.accessionNumber IS NOT DISTINCT FROM g.accessionNumber AND 
  financialData.startDate IS NOT DISTINCT FROM g.startDate 
  AND financialData.endDate IS NOT DISTINCT FROM g.endDate 
  AND financialData.prefix IS NOT DISTINCT FROM g.prefix
  AND financialData.frame IS NOT DISTINCT FROM g.frame
  
  AND EXISTS (
    SELECT 1
    FROM financialData 
    JOIN submissions sd ON sd.accessionNumber = financialData.accessionNumber
    AND sd.form IS NOT DISTINCT FROM g.form);

  checkpoint;


ALTER TABLE financialData Drop COLUMN partitionNumber;
checkpoint;


select prefix, financialData.cik, name, value, units ,partitionNumber, startDate, endDate, form, frame, submissions.accessionNumber from financialData 
left outer join submissions on financialData.accessionNumber = submissions.accessionNumber 
where prefix = 'ifrs-full'order by partitionNumber, name;


select count(*) from (select distinct cik, accessionNumber from financialData) as subCount;


select * from calculationTaxonomyRaw;

truncate table calculationTaxonomyRaw;