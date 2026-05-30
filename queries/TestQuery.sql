select 
sm.*

from standardMetrics sm
inner join 
(select distinct cik, accessionNumber, prefix, form, endDate 
from keyStatementsValuesAndHierarchy WHERE allKeyStatementsPresent = TRUE )  as safeStatements
on safeStatements.cik = sm.cik  
and safeStatements.accessionNumber = sm.accessionNumber
and sm.prefix = safeStatements.prefix
and sm.form = safeStatements.form
and sm.endDate = safeStatements.endDate
/*inner join companyDimension cd on cd.cik = sm.cik

--Revenue is null and "Cost of Revenue" is null 

--AND 

sm.form = '10-Q'
and cd.firstTicker = 'EOSE'
*/

where 1=1
--sm.accessionNumber = '0000936468-21-000013' 
and sm.form = '10-K'
limit 10000;

SELECT

    ksvh.prefix,
    ksvh.cik,
    ksvh.accessionNumber,
    ksvh.form,
    ksvh.endDate,
    ksvh.units,
    ksvh.keyStatementRole,
    ksvh.descendant,
    uhp.absoluteDepth,
    ksvh.value * ksvh.arcWeight as value,

FROM
    keyStatementsValuesAndHierarchy ksvh


    INNER JOIN (
        SELECT
            cth1.cik,
            cth1.accessionNumber,
            cth1.descendant,
            cth1.relativeDepth AS absoluteDepth,
            cth1.keyStatementRole
        FROM
            calculationTaxonomyHierarchy AS cth1
            INNER JOIN calculationTaxonomyHierarchy AS cth2 ON cth1.cik = cth2.cik
            AND cth1.accessionNumber = cth2.accessionNumber
            AND cth1.keyStatementRole = cth2.keyStatementRole
            AND cth1.ancestor = cth2.ancestor
            AND cth2.highestParent = TRUE
    ) uhp ON ksvh.cik = uhp.cik
    AND ksvh.accessionNumber = uhp.accessionNumber
    AND ksvh.keyStatementRole = uhp.keyStatementRole
    AND ksvh.descendant = uhp.descendant
    ANTI JOIN (SELECT DISTINCT cik, accessionNumber from standardizedConcepts) scs
    on scs.cik = ksvh.cik and scs.accessionNumber = ksvh.accessionNumber
    
    inner join companyDimension cd on cd.cik = ksvh.cik
/*
ANTI JOIN 
    standardMetrics sm on
    ksvh.cik = sm.cik and ksvh.accessionNumber = sm.accessionNumber
    and ksvh.endDate = sm.endDate and ksvh.units = sm.units
    and ksvh.form = sm.form*/

WHERE
    (ksvh.relativeDepth = 1 or (ksvh.relativeDepth=0 and ksvh.highestParent=TRUE))
--AND ksvh.cik = 1840292
AND ksvh.accessionNumber = '0000950170-22-003502'
--and cd.firstTicker = 'F'


ORDER BY 
    ksvh.prefix,
    ksvh.cik,
    ksvh.accessionNumber,
    ksvh.form,
    ksvh.endDate,
    ksvh.units,
    ksvh.keyStatementRole,
    ksvh.descendant,
    uhp.absoluteDepth;


select * from financialData
where 
--prefix = 'us-gaap'
 accessionNumber = '0001193125-13-412507' 
and endDate = '2013-09-30'
and name like '%Depr%';

select * from calculationTaxonomyHierarchy where 
accessionNumber = '0000936468-21-000013';

select * from standardMetrics
where "Depreciation and Amortization" IS NULL
;

SELECT DISTINCT keyStatementRole FROM standardizedConcepts
;


select count(*) from (
SELECT 
    DISTINCT
    sc.conceptName,
    sc.standardLabel,
    sc.keyStatementRole,
    sc.standardLabelID,
    sc.conceptsPerStandardLabel,
    sc.confidenceScore
FROM

    standardizedConcepts sc
WHERE sc.confidenceScore > 2
QUALIFY NOT list_contains(list(sc.sign) OVER 
(PARTITION BY sc.conceptName, sc.accessionNumber, sc.keyStatementRole),
    '-'));

/*
delete from standardizedConcepts where standardLabel = 'Pre-tax Income'
and standardLabelID Not LIkE '%Tax%' AND conceptsPerStandardLabel = 1;
checkpoint;*/
