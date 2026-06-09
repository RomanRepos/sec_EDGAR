select 
cd.firstTicker,
sm.*

from standardMetrics sm
inner JOIN companyDimension cd on cd.cik = sm.cik

/*inner join companyDimension cd on cd.cik = sm.cik

--Revenue is null and "Cost of Revenue" is null 

--AND 

sm.form = '10-Q'

*/

where 1=1
--and sm.accessionNumber = '0001493152-21-007591' 
and sm.form in ('10-K')
--and sm."Cost of Revenue" is null
and cd.firstTicker is not null
and cd.firstTicker = 'TXN'
Limit 10000
;


select * from financialData
where 
--prefix = 'us-gaap'
 accessionNumber = '0001628280-20-003753' 
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
                     ORDER BY standardLabel DESC;

select distinct split_part(ticker, '.', 1) from dailyStockPrices
where exchange in ('NYSE', 'NASDAQ');

select * from "companyDimension" where "firstTicker" like 'RITM';

select distinct ticker from dailyStockPrices
where ticker like 'CMRE%';

