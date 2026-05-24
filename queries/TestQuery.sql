select sm.* from standardMetrics sm
inner join 
(select distinct cik, accessionNumber, prefix, form, endDate from keyStatementsValuesAndHierarchy WHERE allKeyStatementsPresent = TRUE)  as safeStatements
on safeStatements.cik = sm.cik  
and safeStatements.accessionNumber = sm.accessionNumber
and sm.prefix = safeStatements.prefix
and sm.form = safeStatements.form
and sm.endDate = safeStatements.endDate
where 
--Revenue is null and "Cost of Revenue" is null 
--sm.accessionNumber = '0001104659-13-014429'
--AND 
sm.form = '10-K'

limit 10000;

DELETE from standardMetrics
where accessionNumber = '0001104659-13-014429'
and Revenue<>3841000000;

select distinct standardLabel from standardizedConcepts;