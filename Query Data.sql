
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

select  linkXlinkRole, count(*) as countRoles from calculationTaxonomyRaw
group by linkXlinkRole
ORDER by countRoles desc;

select  toConcept, count(*) as countToConcepts from calculationTaxonomy
where toConcept = '' or toConcept is null
group by toConcept
ORDER by countToConcepts desc;

select * from (
select  linkRole, keyStatmentRole, count(*) as countlinkRoles from (select distinct cik, accessionNUmber, ct.linkRole, keyStatmentRole from calculationTaxonomy ct left outer join CalcTaxRolesClassified ctc on ct.linkRole = ctc.linkRole)
group by linkRole, keyStatmentRole
ORDER by countlinkRoles desc
limit 10000) where keyStatmentRole is null
;

select count(*) from (select distinct linkRole from calculationTaxonomy);

SELECT ct.cik, ct.accessionNumber, ct.linkRole, ct.fromConcept, ct.toConcept, ct.arcOrder,
    ct.arcWeight from calculationTaxonomy ct anti join calculationTaxonomyHierarchy cth on cth.cik = ct.cik and cth.accessionNumber = ct.accessionNumber
    where ct.isPrimaryRole=TRUE
    and ct.fromConcept IS NOT NULL and ct.toConcept IS NOT NULL and ct.fromConcept<>ct.toConcept;


ALTER TABLE calculationTaxonomy ADD COLUMN isPrimaryRole BOOLEAN DEFAULT FALSE;
WITH ranked AS (
    SELECT
        cik,
        accessionNumber,
        ct.linkRole,
        COUNT(*) AS conceptCount,
        ROW_NUMBER() OVER (
            PARTITION BY cik, accessionNumber, ctc.keyStatementRole
            ORDER BY COUNT(*) DESC
        ) AS rn
    FROM calculationTaxonomy ct
    INNER JOIN calcTaxRolesClassified ctc ON ctc.linkRole = ct.linkRole
    WHERE ctc.keyStatementRole IS NOT NULL
    GROUP BY cik, accessionNumber, ct.linkRole, ctc.keyStatementRole
),
primaryRoles AS (
    SELECT cik, accessionNumber, linkRole
    FROM ranked
    WHERE rn = 1
)
UPDATE calculationTaxonomy
SET isPrimaryRole = TRUE
WHERE (cik, accessionNumber, linkRole) IN (
    SELECT cik, accessionNumber, linkRole FROM primaryRoles
);
checkpoint;

/*
CREATE OR REPLACE TABLE calculationTaxonomy AS
SELECT
    cik,
    accessionNumber,
    COALESCE(NULLIF(regexp_extract(replace(regexp_extract(linkXlinkRole, '[^/]+$'), 'Role_', ''), '([A-Z]{1}[A-Za-z]+)'), ''), replace(regexp_extract(linkXlinkRole, '[^/]+$'), 'Role_', ''))  AS linkRole,
    replace(regexp_extract(arcXlinkArcrole, '[^/]+$'), 'Role_', '') AS arcRole,
    regexp_extract(replace(Replace(arcXlinkFrom, 'loc_', ''), 'Locator_', ''), '^([^.]+?)_', 1) AS fromPrefix,
    COALESCE(NULLIF(regexp_extract(replace(replace(arcXlinkFrom,'loc_', ''), 'Locator_', ''), '([A-Z]{1}[a-z]{2,}[A-Za-z]+)', 1), ''), replace(replace(arcXlinkFrom,'loc_', ''), 'Locator_', '')) AS fromConcept,
    regexp_extract(replace(replace(arcXlinkTo,'loc_', ''), 'Locator_', ''),   '^([^.]+?)_', 1) AS toPrefix,
    COALESCE(NULLIF(regexp_extract(replace(replace(arcXlinkTo,'loc_', ''), 'Locator_', ''),   '([A-Z]{1}[a-z]{2,}[A-Za-z]+)', 1), ''), replace(replace(arcXlinkTo,'loc_', ''), 'Locator_', '')) AS toConcept,
    arcUse,
    arcOrder,
    arcWeight
FROM calculationTaxonomyRaw;
checkpoint;

ALTER TABLE calculationTaxonomy ADD COLUMN isPrimaryRole BOOLEAN DEFAULT FALSE;
WITH ranked AS (
    SELECT
        cik,
        accessionNumber,
        ct.linkRole,
        COUNT(*) AS conceptCount,
        ROW_NUMBER() OVER (
            PARTITION BY cik, accessionNumber, ctc.keyStatementRole
            ORDER BY COUNT(*) DESC
        ) AS rn
    FROM calculationTaxonomy ct
    INNER JOIN calcTaxRolesClassified ctc ON ctc.linkRole = ct.linkRole
    WHERE ctc.keyStatementRole IS NOT NULL
    GROUP BY cik, accessionNumber, ct.linkRole, ctc.keyStatementRole
),
primaryRoles AS (
    SELECT cik, accessionNumber, linkRole
    FROM ranked
    WHERE rn = 1
)
UPDATE calculationTaxonomy
SET isPrimaryRole = TRUE
WHERE (cik, accessionNumber, linkRole) IN (
    SELECT cik, accessionNumber, linkRole FROM primaryRoles
);
checkpoint;
*/

SELECT ct.cik, ct.accessionNumber, ct.linkRole, ct.fromConcept, ct.toConcept, ct.arcOrder,
    ct.arcWeight from calculationTaxonomy ct anti join calculationTaxonomyHierarchy cth on cth.cik = ct.cik and cth.accessionNumber = ct.accessionNumber
    where ct.isPrimaryRole=TRUE
    and ct.fromConcept IS NOT NULL and ct.toConcept IS NOT NULL and ct.fromConcept<>ct.toConcept;
