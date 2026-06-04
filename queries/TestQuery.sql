select 
sm.*

from standardMetrics sm

/*inner join companyDimension cd on cd.cik = sm.cik

--Revenue is null and "Cost of Revenue" is null 

--AND 

sm.form = '10-Q'
and cd.firstTicker = 'EOSE'
*/

where 1=1
--and sm.accessionNumber = '0001493152-21-007591' 
and sm.form in ('10-K')
--and sm.accessionNumber = '0000950170-24-024987'
--and sm."Total Current Assets" is null
;

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
 accessionNumber = '0000950170-24-024987' 
--and endDate = '2021-12-31'
--and name like '%Dev%'
--and prefix = 'us-gaap'
--and value = -24774000

;

select * from calculationTaxonomyHierarchy where 
accessionNumber = '0000936468-21-000013';

select * from standardMetrics
where "Depreciation and Amortization" IS NULL
;

SELECT DISTINCT keyStatementRole FROM standardizedConcepts
;

select prefix, name, endDate, count(*) from financialData where 
1=1 
and (name like '%Stock%')
and "accessionNumber" = '0001193125-12-194474'
group by prefix, name, endDate
order by count(*) desc;


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

SELECT DISTINCT standardLabel, standardLabelID FROM standardizedConcepts
where standardLabel in ('Interest Income', 'Interest Expense')
 ORDER BY standardLabel DESC;


SELECT DISTINCT standardLabel FROM standardizedConcepts 
                     WHERE standardLabel NOT IN ('Gross Profit', 'Operating Expenses')
                     ORDER BY standardLabel DESC