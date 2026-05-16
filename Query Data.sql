


--Determine submissions that have matching total for top level parents and first level nodes for each key statement role to identify filings with complete calculation hierarchies for primary financial statements.
with topLevelParentsSum as (
SELECT fd.prefix, fd.units, cth.cik, cth.accessionNumber, 
cth.linkRole, 
cth.keyStatementRole, s.form, fd.endDate, sum(fd.value) highestLevelParentsTotal 
from calculationTaxonomyHierarchy cth 
inner join financialData fd on
    fd.cik = cth.cik 
    AND fd.accessionNumber = cth.accessionNumber
    AND fd.name = cth.descendant
    AND cth.relativeDepth = 0
    AND cth.highestParent = TRUE
    AND isPrimaryPrefix = TRUE
    AND fd.isPrimarySubmissionDateRange = TRUE
    and fd.isPrimaryUnits = TRUE
inner join (select distinct cik, accessionNumber, linkRole from calculationTaxonomy where isPrimaryRole = TRUE) ct
        ON ct.cik = cth.cik
        AND ct.accessionNumber = cth.accessionNumber
        AND ct.linkRole = cth.linkRole

INNER JOIN submissions s 
        ON fd.cik = s.cik 
        AND fd.accessionNumber = s.accessionNumber
        AND s.reportDate = fd.endDate
GROUP BY
    fd.prefix, fd.units, cth.cik, cth.accessionNumber, cth.linkRole, cth.keyStatementRole, s.form, fd.endDate
), 

firstLevelNodestSum as (
SELECT fd.prefix, fd.units, cth.cik, cth.accessionNumber, cth.linkRole,  
cth.keyStatementRole, s.form, fd.endDate, sum(fd.value*cth.arcWeight) firstLevelNodesTotal 
from calculationTaxonomyHierarchy cth
inner join financialData fd on
    fd.cik = cth.cik 
    AND fd.accessionNumber = cth.accessionNumber
    AND fd.name = cth.descendant
    AND cth.relativeDepth = 1
    AND fd.isPrimaryPrefix = TRUE
    AND fd.isPrimarySubmissionDateRange = TRUE
    and fd.isPrimaryUnits = TRUE
inner join (select distinct cik, accessionNumber, linkRole from calculationTaxonomy where isPrimaryUnits = TRUE) ct
        ON ct.cik = cth.cik
        AND ct.accessionNumber = cth.accessionNumber
        AND ct.linkRole = cth.linkRole
INNER JOIN submissions s 
        ON fd.cik = s.cik 
        AND fd.accessionNumber = s.accessionNumber
        AND s.reportDate = fd.endDate
INNER JOIN calculationTaxonomyHierarchy ctht
        ON ctht.cik = cth.cik
        AND ctht."accessionNumber" = cth."accessionNumber"
        AND cth.ancestor = ctht.ancestor
        AND ctht."relativeDepth" = 0
        AND ctht.highestParent = TRUE
GROUP BY
    fd.prefix, fd.units, cth.cik, cth.accessionNumber, cth.linkRole, cth.keyStatementRole, s.form, fd.endDate
),    

subs as (
select tlp.prefix, tlp.units, tlp.cik, tlp.accessionNumber, tlp.form, tlp.endDate from topLevelParentsSum tlp
INNER JOIN firstLevelNodestSum fln 
on tlp.cik = fln.cik
and tlp.accessionNumber = fln.accessionNumber
and tlp.linkRole = fln.linkRole
and tlp.keyStatementRole = fln.keyStatementRole
and tlp.form = fln.form
and tlp.endDate = fln.endDate
and tlp.highestLevelParentsTotal = fln.firstLevelNodesTotal
and tlp.units = fln.units

inner join (select distinct cik, accessionNumber, prefix from financialData where isPrimaryUnits = TRUE) pu
on pu.cik = tlp.cik
AND pu.accessionNumber = tlp.accessionNumber
AND pu.prefix = tlp.prefix

WHERE tlp.keyStatementRole in ('BalanceSheet', 'IncomeStatement', 'StatementOfCashFlows')
GROUP BY tlp.prefix, tlp.units, tlp.cik, tlp.accessionNumber, tlp.form, tlp.endDate
HAVING count(*) = 3
ORDER BY tlp.prefix, tlp.cik, tlp.accessionNumber, tlp.form, tlp.endDate)



select count(*) from (
SELECT
distinct
    --cth."keyStatementRole" AS financialStatement,
    --cth."ancestor",
    --cth.descendant,
    --cth."arcWeight",
    --cth.relativeDepth,
    cth.cik,
    cth.accessionNumber
FROM
    financialData fd
INNER JOIN submissions s ON fd.cik = s.cik
    AND fd.accessionNumber = s.accessionNumber
    AND s.reportDate = fd.endDate
INNER JOIN calculationTaxonomyHierarchy cth ON cth.cik = fd.cik
    AND cth.accessionNumber = fd.accessionNumber
    AND fd.name = cth.descendant
LEFT OUTER JOIN calculationTaxonomyHierarchy ctht ON ctht.cik = fd.cik
    AND ctht."accessionNumber" = fd."accessionNumber"
    AND cth.ancestor = ctht.ancestor
    AND ctht."relativeDepth" = 0
    AND ctht.highestParent = TRUE
INNER JOIN subs ON
    fd.prefix = subs.prefix
    AND cth.cik = subs.cik
    AND cth.accessionNumber = subs.accessionNumber
    AND s.form = subs.form
    AND fd.endDate = subs.endDate
    AND (
        cth."relativeDepth" = 1
        OR (
            cth."relativeDepth" = 0
            AND cth.highestParent = TRUE
        )
    )
    and cth."keyStatementRole" IN (
        'BalanceSheet',
        'IncomeStatement',
        'StatementOfCashFlows'
    )
    AND fd.isPrimarySubmissionDateRange = TRUE
    and fd.isPrimaryUnits = TRUE
    AND fd.isPrimaryPrefix = TRUE
    and fd.units = subs.units
    
ORDER BY
    cth.keyStatementRole,
    cth.ancestor,
    cth.arcWeight DESC
)
;
--------------------------------------------------------------------------------

select count(*) from (
Select distinct * from calculationTaxonomyHierarchy);


with subs as (
select distinct cik, accessionNumber, prefix from financialData where prefix in ('us-gaap'))
select cik, accessionNumber from subs
GROUP BY cik, accessionNumber
having count(*)>1
order by cik, accessionNumber;


/*
--Remove duplicate rows from hierarchy table that may have been caused by multiple statement roles per link role. We want to keep the one with the greatest relative depth to ensure we are capturing the most specific role for each link role.
CREATE TABLE calculationTaxonomyHierarchy_NEW as
SELECT * FROM calculationTaxonomyHierarchy 
QUALIFY ROW_NUMBER() OVER 
(PARTITION BY 
cik,
accessionNumber,
linkRole,
ancestor,
descendant,
arcOrder,
arcWeight,
highestParent,
lowestChild,
keyStatementRole
ORDER BY relativeDepth DESC) = 1
;
DROP TABLE calculationTaxonomyHierarchy;
ALTER TABLE calculationTaxonomyHierarchy_NEW RENAME to calculationTaxonomyHierarchy;
CHECKPOINT;
------------------------------------------------------------------------
*/




/*
--Make sure hierarchy table only has primary statement roles and no duplicates.

CREATE TABLE calculationTaxonomyHierarchy_NEW AS
SELECT
    DISTINCT
    cth.*,
    ct.keyStatementRole
FROM
    calculationTaxonomyHierarchy cth
    LEFT OUTER JOIN (
        SELECT
            DISTINCT cik,
            accessionNumber,
            cti.linkRole,
            keyStatementRole
        FROM
            calculationTaxonomy cti
            INNER JOIN calcTaxRolesClassified ctc ON cti.linkRole = ctc.linkRole
            AND cti.isPrimaryRole = TRUE
    ) ct ON cth.cik = ct.cik
    AND cth.accessionNumber = ct.accessionNumber
    AND cth.linkRole = ct.linkRole;

DROP TABLE calculationTaxonomyHierarchy;

ALTER TABLE
    calculationTaxonomyHierarchy_NEW RENAME TO calculationTaxonomyHierarchy;
CHECKPOINT;
*/
------------------------------------------------------
