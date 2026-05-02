import re
import duckdb as ddb
from dotenv import load_dotenv
from pathlib import Path
import os

def normalize(s):
    return re.sub(r'[^a-z]', '', s.lower())

DISCARD_PATTERNS = [
    'details',
    'disclosure',
    'schedule',
    'parenthetical',
    'supplemental',
    'calc',
    'rollforward',
    'guarantor',
    'nonguarantor',
    'consolidating',   # catches CondensedConsolidating*
    'parentcompany',
    'selectedbalancesheet',
    'selectedquarterly',
    'quarterly',
    'segment',
    'geographic',
    'reconciliation',
    'chapter',
    'note',            # catches Note, DisclosureNote
    'table',
    'policy',
    'policies',
    'description',
    'organization',
]

# Equity statement patterns — exclude from our 3 targets
EQUITY_PATTERNS = [
    'stockholdersequity',
    'shareholdersequity',
    'partnerscapital',
    'partnercapital',
    'changesinequity',
    'changesinnetassets',
    'changesinmembercapital',
    'membercapital',
    'statem',  # too broad — skip
]

CASH_FLOW_PATTERNS = [
    'cashflow', 'cashflows',
    'statementofcashflow', 'statementsofcashflow',
    'cashflowsindirect', 'cashflowsdirect',
    'cashflowstatement',
]

BALANCE_SHEET_PATTERNS = [
    'balancesheet', 'balancesheets',
    'financialposition',
    'financialcondition',
    'assetsandliabilities',
    'statementofcondition',
    'statementsofcondition',
    'statementoffinancialcondition',
    'statementsoffinancialcondition',
    'statementoffinancialposition',
    'statementsoffinancialposition',
    'statementsofassetsandliabilities',
    'statementofassetsandliabilities',
    'schedulesofinvestments',   # investment fund balance sheet equiv
]

INCOME_STATEMENT_PATTERNS = [
    'statementsofoperations', 'statementofoperations',
    'incomestatement', 'incomestatements',
    'statementofincome', 'statementsofincome',
    'statementsofearnings', 'statementofearnings',
    'consolidatedincome',
    'comprehensiveincome',
    'comprehensiveloss',
    'comprehensiveearnings',
    'statementsofoperationsandcomprehensive',
    'statementofloss', 'statementsofloss',
    'statementsoflosandcomprehensive',
    'statementsofprofitorloss',     # IFRS
    'profitorlossandothercomprehensive',
    'statementsofexpenses',         # investment funds
    'statementsofincomeandexpenses',
    'statementsofnetincome',
    'resultsofoperations',
    'statementsofoperationsandother',
]

def is_equity_statement(n):
    equity_signals = [
        'stockholdersequity', 'shareholdersequity',
        'partnerscapital', 'changesinequity',
        'changesinnetassets', 'membercapital',
        'changesinsharehold', 'changesinstock',
        'statementsofequity', 'statementofequity',
        'statementofchanges',
    ]
    return any(p in n for p in equity_signals)

def classify_role(role_tail: str):
    n = normalize(role_tail)
    
    # Step 1: discard noise
    if any(p in n for p in DISCARD_PATTERNS):
        return None
    
    # Step 2: discard equity statements
    if is_equity_statement(n):
        return 'EquityStatement'
    
    # Step 3: cash flow (before income — more specific)
    if any(p in n for p in CASH_FLOW_PATTERNS):
        return 'CashFlow'
    
    # Step 4: balance sheet
    if any(p in n for p in BALANCE_SHEET_PATTERNS):
        return 'BalanceSheet'
    
    # Step 5: income statement
    if any(p in n for p in INCOME_STATEMENT_PATTERNS):
        return 'IncomeStatement'
    
    return None

if __name__ == "__main__":
    load_dotenv()
    PROJECT_ROOT_PARENT = Path(
        Path(__file__).resolve().parent.parent or 
        Path(os.getenv("PROJECT_ROOT")).resolve().parent
    )
    DATA_DIR   = PROJECT_ROOT_PARENT / "Data"
    db_path    = DATA_DIR / "secFilingsDb.duckdb"

    conn = ddb.connect(db_path)

    roles_df = conn.execute('''select distinct linkRole from calculationTaxonomy''').fetch_df()
    
    roles_df['keyStatementRole'] = roles_df['linkRole'].apply(classify_role)

    conn.register('presentation_df', roles_df)
    conn.execute("CREATE OR REPLACE TABLE calcTaxRolesClassified AS SELECT * FROM roles_df; CHECKPOINT;")

    conn.close()