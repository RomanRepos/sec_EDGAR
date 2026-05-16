select distinct 
    fd.cik,
    fd.accessionNumber,
    fd.prefix,
    fd.endDate,
    s.form,
    fd.units
from
    financialData fd
    INNER JOIN submissions s ON fd.cik = s.cik
    AND fd.accessionNumber = s.accessionNumber
    AND s.reportDate = fd.endDate
    INNER JOIN highConceptCoverageSubmissionsSample hccs ON hccs.cik = fd.cik
    AND hccs.accessionNumber = fd.accessionNumber
    AND hccs.prefix = fd.prefix
    AND fd.units = hccs.units
    AND s.form = hccs.form
    AND fd.endDate = hccs.endDate
ANTI JOIN (SELECT DISTINCT cik, accessionNumber, prefix from standardizedConcepts) sc 
ON sc.cik = fd.cik AND sc.accessionNumber = fd.accessionNumber AND sc.prefix = fd.prefix
WHERE
    fd.isPrimarySubmissionDateRange = TRUE
    AND fd.isPrimaryUnits = TRUE
    AND fd.isPrimaryPrefix = TRUE
ORDER BY  
    fd.cik,
    fd.accessionNumber,
    fd.prefix;