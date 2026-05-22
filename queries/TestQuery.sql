select sm.* from standardMetrics sm
inner join 
(select distinct cik, accessionNumber, prefix, form, endDate from keyStatementsValuesAndHierarchy where rollUpIsAccurate = TRUE and allKeyStatementsPresent = TRUE)  as safeStatements
on safeStatements.cik = sm.cik  
and safeStatements.accessionNumber = sm.accessionNumber
and sm.prefix = safeStatements.prefix
and sm.form = safeStatements.form
and sm.endDate = safeStatements.endDate
where sm.accessionNumber = '0001445866-18-001247'
limit 10000;

DELETE from standardMetrics
where accessionNumber = '0001445866-18-001247';