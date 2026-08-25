-- SECTION 1: DATABASE + STAGING TABLE SETUP
CREATE DATABASE CreditRiskProject;
GO

USE CreditRiskProject;
GO

-- staging table holds raw csv as pure text, nothing gets rejected on import
CREATE TABLE staging_loandata (
    loan_id                        NVARCHAR(50),
    loan_amount                    NVARCHAR(50),
    funded_amount                  NVARCHAR(50),
    loan_term_months               NVARCHAR(50),
    interest_rate                  NVARCHAR(50),
    monthly_installment            NVARCHAR(50),
    loan_grade                     NVARCHAR(10),
    loan_subgrade                  NVARCHAR(10),
    employment_length_years        NVARCHAR(50),
    home_ownership_status          NVARCHAR(50),
    annual_income                  NVARCHAR(50),
    income_verification_status     NVARCHAR(50),
    loan_issue_date                NVARCHAR(50),
    loan_status                    NVARCHAR(50),
    loan_purpose                   NVARCHAR(100),
    loan_title                     NVARCHAR(200),
    borrower_zip_code              NVARCHAR(20),
    borrower_state                 NVARCHAR(10),
    debt_to_income_ratio           NVARCHAR(50),
    delinquencies_last_2yrs        NVARCHAR(50),
    earliest_credit_line_date      NVARCHAR(50),
    fico_score_low                 NVARCHAR(50),
    fico_score_high                NVARCHAR(50),
    credit_inquiries_last_6mths    NVARCHAR(50),
    open_credit_accounts           NVARCHAR(50),
    public_derogatory_records      NVARCHAR(50),
    revolving_balance               NVARCHAR(50),
    revolving_utilization_rate     NVARCHAR(50),
    total_credit_accounts           NVARCHAR(50),
    total_payment_received          NVARCHAR(50),
    total_principal_received        NVARCHAR(50),
    total_interest_received         NVARCHAR(50),
    last_payment_date               NVARCHAR(50),
    last_payment_amount             NVARCHAR(50),
    application_type                 NVARCHAR(50),
    mortgage_accounts                NVARCHAR(50),
    bankruptcies_count               NVARCHAR(50)
);
GO

-- loads the cleanedcsv into staging
BULK INSERT staging_loandata
FROM 'C:\Users\My PC\Desktop\CreditRiskProject\lending_club_2015_2018_clean.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK,
    CODEPAGE = '65001'
);
GO

SELECT COUNT(*) AS row_count FROM staging_loandata; 

-- SECTION 2: DATA AUDIT 
SELECT loan_id, COUNT(*) AS duplicate_count 
FROM staging_loandata
GROUP BY loan_id
HAVING COUNT(*) > 1;

SELECT 
    SUM(CASE WHEN employment_length_years IS NULL OR employment_length_years = '' THEN 1 ELSE 0 END) AS missing_emp_length,
    SUM(CASE WHEN debt_to_income_ratio IS NULL OR debt_to_income_ratio = '' THEN 1 ELSE 0 END) AS missing_dti
FROM staging_loandata;

SELECT MIN(TRY_CAST(annual_income AS DECIMAL(12,2))) AS min_income, 
       MAX(TRY_CAST(annual_income AS DECIMAL(12,2))) AS max_income
FROM staging_loandata;

-- SECTION 3: COPY STAGING INTO A WORKING CLEAN TABLE
IF OBJECT_ID('loandata_clean','U') IS NOT NULL
    DROP TABLE loandata_clean;

SELECT 
    IDENTITY(INT,1,1) AS row_id,
    loan_id, loan_amount, funded_amount, loan_term_months, interest_rate,
    monthly_installment, loan_grade, loan_subgrade, employment_length_years,
    home_ownership_status, annual_income, income_verification_status,
    loan_issue_date, loan_status, loan_purpose, loan_title, borrower_zip_code,
    borrower_state, debt_to_income_ratio, delinquencies_last_2yrs,
    earliest_credit_line_date, fico_score_low, fico_score_high,
    credit_inquiries_last_6mths, open_credit_accounts, public_derogatory_records,
    revolving_balance, revolving_utilization_rate, total_credit_accounts,
    total_payment_received, total_principal_received, total_interest_received,
    last_payment_date, last_payment_amount, application_type,
    mortgage_accounts, bankruptcies_count
INTO loandata_clean
FROM staging_loandata;

ALTER TABLE loandata_clean
ADD CONSTRAINT pk_loandata_clean PRIMARY KEY (row_id);


-- SECTION 4: CLEAN CATEGORICAL COLUMNS
UPDATE loandata_clean 
SET
    loan_status                 = UPPER(TRIM(loan_status)),
    home_ownership_status       = UPPER(TRIM(home_ownership_status)),
    loan_grade                  = UPPER(TRIM(loan_grade)),
    loan_subgrade                = UPPER(TRIM(loan_subgrade)),
    income_verification_status  = UPPER(TRIM(income_verification_status)),
    loan_purpose                 = UPPER(TRIM(loan_purpose)),
    application_type             = UPPER(TRIM(application_type)),
    borrower_state                = UPPER(TRIM(borrower_state));


-- SECTION 5: CLEAN MESSY NUMERIC-LOOKING TEXT
UPDATE loandata_clean 
SET loan_term_months = TRIM(REPLACE(loan_term_months, 'months', ''));

UPDATE loandata_clean 
SET employment_length_years =
    CASE
        WHEN employment_length_years IS NULL OR TRIM(employment_length_years) = '' THEN NULL
        WHEN employment_length_years = '< 1 year' THEN '0'
        WHEN employment_length_years = '10+ years' THEN '10'
        ELSE TRIM(REPLACE(REPLACE(employment_length_years, ' years', ''), ' year', ''))
    END;

UPDATE loandata_clean 
SET
    delinquencies_last_2yrs      = CAST(ROUND(TRY_CAST(REPLACE(delinquencies_last_2yrs, CHAR(13), '') AS DECIMAL(10,2)), 0) AS INT),
    fico_score_low                 = CAST(ROUND(TRY_CAST(REPLACE(fico_score_low, CHAR(13), '') AS DECIMAL(10,2)), 0) AS INT),
    fico_score_high                 = CAST(ROUND(TRY_CAST(REPLACE(fico_score_high, CHAR(13), '') AS DECIMAL(10,2)), 0) AS INT),
    credit_inquiries_last_6mths    = CAST(ROUND(TRY_CAST(REPLACE(credit_inquiries_last_6mths, CHAR(13), '') AS DECIMAL(10,2)), 0) AS INT),
    open_credit_accounts            = CAST(ROUND(TRY_CAST(REPLACE(open_credit_accounts, CHAR(13), '') AS DECIMAL(10,2)), 0) AS INT),
    public_derogatory_records       = CAST(ROUND(TRY_CAST(REPLACE(public_derogatory_records, CHAR(13), '') AS DECIMAL(10,2)), 0) AS INT),
    total_credit_accounts            = CAST(ROUND(TRY_CAST(REPLACE(total_credit_accounts, CHAR(13), '') AS DECIMAL(10,2)), 0) AS INT),
    mortgage_accounts                 = CAST(ROUND(TRY_CAST(REPLACE(mortgage_accounts, CHAR(13), '') AS DECIMAL(10,2)), 0) AS INT),
    bankruptcies_count                 = CAST(ROUND(TRY_CAST(REPLACE(bankruptcies_count, CHAR(13), '') AS DECIMAL(10,2)), 0) AS INT);


-- SECTION 6: HANDLE MISSING VALUES
UPDATE loandata_clean 
SET
    debt_to_income_ratio       = NULLIF(TRIM(debt_to_income_ratio), ''),
    revolving_utilization_rate = NULLIF(TRIM(revolving_utilization_rate), ''),
    last_payment_date            = NULLIF(TRIM(last_payment_date), ''),
    last_payment_amount          = NULLIF(TRIM(last_payment_amount), '');

UPDATE loandata_clean 
SET borrower_zip_code = 'UNKNOWN'
WHERE borrower_zip_code IS NULL OR TRIM(borrower_zip_code) = '';


-- SECTION 7: FIX DATE FORMATS

UPDATE loandata_clean 
SET earliest_credit_line_date =
    CASE
        WHEN earliest_credit_line_date IS NULL OR earliest_credit_line_date = '' THEN NULL
        ELSE CONVERT(VARCHAR(10),
                DATEFROMPARTS(
                    CAST(RIGHT(earliest_credit_line_date, 4) AS INT),
                    CASE UPPER(LEFT(earliest_credit_line_date, 3))
                        WHEN 'JAN' THEN 1  WHEN 'FEB' THEN 2  WHEN 'MAR' THEN 3
                        WHEN 'APR' THEN 4  WHEN 'MAY' THEN 5  WHEN 'JUN' THEN 6
                        WHEN 'JUL' THEN 7  WHEN 'AUG' THEN 8  WHEN 'SEP' THEN 9
                        WHEN 'OCT' THEN 10 WHEN 'NOV' THEN 11 WHEN 'DEC' THEN 12
                    END,
                    1),
                23)
    END;

UPDATE loandata_clean 
SET last_payment_date =
    CASE
        WHEN last_payment_date IS NULL THEN NULL
        ELSE CONVERT(VARCHAR(10),
                DATEFROMPARTS(
                    CAST(RIGHT(last_payment_date, 4) AS INT),
                    CASE UPPER(LEFT(last_payment_date, 3))
                        WHEN 'JAN' THEN 1  WHEN 'FEB' THEN 2  WHEN 'MAR' THEN 3
                        WHEN 'APR' THEN 4  WHEN 'MAY' THEN 5  WHEN 'JUN' THEN 6
                        WHEN 'JUL' THEN 7  WHEN 'AUG' THEN 8  WHEN 'SEP' THEN 9
                        WHEN 'OCT' THEN 10 WHEN 'NOV' THEN 11 WHEN 'DEC' THEN 12
                    END,
                    1),
                23)
    END;


-- SECTION 8: DUPLICATE VALIDATION
WITH duplicate_rows AS ( 
    SELECT row_id, ROW_NUMBER() OVER (PARTITION BY loan_id ORDER BY row_id) AS rn
    FROM loandata_clean
)
DELETE FROM loandata_clean
WHERE row_id IN (SELECT row_id FROM duplicate_rows WHERE rn > 1);


-- SECTION 9: CAP THE ANNUAL_INCOME OUTLIER
DECLARE @income_cap DECIMAL(14,2);

SELECT TOP 1 @income_cap = 
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY CAST(annual_income AS DECIMAL(14,2))) OVER ()
FROM loandata_clean;

UPDATE loandata_clean
SET annual_income = CAST(@income_cap AS NVARCHAR(50))
WHERE CAST(annual_income AS DECIMAL(14,2)) > @income_cap;


-- SECTION 10: TIGHTEN DATA TYPES
ALTER TABLE loandata_clean ALTER COLUMN loan_id                     INT NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN loan_amount                 DECIMAL(12,2) NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN funded_amount                DECIMAL(12,2) NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN loan_term_months             TINYINT NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN interest_rate                DECIMAL(5,2) NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN monthly_installment          DECIMAL(10,2) NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN loan_grade                   CHAR(1) NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN loan_subgrade                 CHAR(2) NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN employment_length_years      TINYINT NULL;
ALTER TABLE loandata_clean ALTER COLUMN home_ownership_status        NVARCHAR(20) NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN annual_income                 DECIMAL(14,2) NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN income_verification_status   NVARCHAR(30) NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN loan_issue_date               DATE NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN loan_status                   NVARCHAR(30) NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN loan_purpose                  NVARCHAR(50) NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN loan_title                    NVARCHAR(200) NULL;
ALTER TABLE loandata_clean ALTER COLUMN borrower_zip_code             NVARCHAR(10) NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN borrower_state                CHAR(2) NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN debt_to_income_ratio          DECIMAL(6,2) NULL;
ALTER TABLE loandata_clean ALTER COLUMN delinquencies_last_2yrs       TINYINT NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN earliest_credit_line_date      DATE NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN fico_score_low                 SMALLINT NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN fico_score_high                SMALLINT NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN credit_inquiries_last_6mths    TINYINT NULL;
ALTER TABLE loandata_clean ALTER COLUMN open_credit_accounts           TINYINT NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN public_derogatory_records      TINYINT NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN revolving_balance               DECIMAL(12,2) NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN revolving_utilization_rate     DECIMAL(6,2) NULL;
ALTER TABLE loandata_clean ALTER COLUMN total_credit_accounts           TINYINT NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN total_payment_received          DECIMAL(12,2) NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN total_principal_received        DECIMAL(12,2) NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN total_interest_received         DECIMAL(12,2) NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN last_payment_date                DATE NULL;
ALTER TABLE loandata_clean ALTER COLUMN last_payment_amount              DECIMAL(12,2) NULL;
ALTER TABLE loandata_clean ALTER COLUMN application_type                 NVARCHAR(20) NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN mortgage_accounts                TINYINT NOT NULL;
ALTER TABLE loandata_clean ALTER COLUMN bankruptcies_count               TINYINT NOT NULL;

ALTER TABLE loandata_clean
ADD CONSTRAINT uq_loan_id UNIQUE (loan_id);


-- SECTION 11: FINAL VALIDATION
SELECT COUNT(*) AS total_rows FROM loandata_clean;

SELECT COUNT(*) AS null_dti FROM loandata_clean WHERE debt_to_income_ratio IS NULL; 
SELECT COUNT(*) AS null_emp_length FROM loandata_clean WHERE employment_length_years IS NULL; 

SELECT MIN(annual_income) AS min_income, MAX(annual_income) AS max_income FROM loandata_clean;

SELECT COUNT(*) AS negative_loan_amount FROM loandata_clean WHERE loan_amount < 0; 
SELECT COUNT(*) AS negative_interest_rate FROM loandata_clean WHERE interest_rate < 0; 
SELECT COUNT(*) AS zero_fico FROM loandata_clean WHERE fico_score_low = 0; 
SELECT COUNT(*) AS zero_income_count FROM loandata_clean WHERE annual_income = 0; 

select
    count(*) as total_loans,
    sum(loan_amount) as total_loan_amount,
    avg(interest_rate) as avg_interest_rate,
    avg(loan_amount) as avg_loan_amount
from loandata_clean;

select
    loan_status,
    count(*) as loan_count,
    cast(count(*) * 100.0 / (select count(*) from loandata_clean) as decimal(5,2)) as percentage_of_total
from loandata_clean
group by loan_status
order by loan_count desc;

select
    count(*) as defaulted_loans,
    sum(loan_amount) as total_defaulted_amount,
    cast(count(*) * 100.0 / (select count(*) from loandata_clean) as decimal(5,2)) as default_rate_pct
from loandata_clean
where loan_status in ('CHARGED OFF', 'DEFAULT');

select
    loan_grade,
    count(*) as total_loans,
    sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) as defaulted_loans,
    cast(sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) * 100.0 / count(*) as decimal(5,2)) as default_rate_pct,
    avg(interest_rate) as avg_interest_rate
from loandata_clean
group by loan_grade
order by loan_grade;

select
    case
        when fico_score_low < 600 then '< 600'
        when fico_score_low between 600 and 649 then '600-649'
        when fico_score_low between 650 and 699 then '650-699'
        when fico_score_low between 700 and 749 then '700-749'
        when fico_score_low between 750 and 799 then '750-799'
        else '800+'
    end as fico_band,
    count(*) as total_loans,
    sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) as defaulted_loans,
    cast(sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) * 100.0 / count(*) as decimal(5,2)) as default_rate_pct
from loandata_clean
group by
    case
        when fico_score_low < 600 then '< 600'
        when fico_score_low between 600 and 649 then '600-649'
        when fico_score_low between 650 and 699 then '650-699'
        when fico_score_low between 700 and 749 then '700-749'
        when fico_score_low between 750 and 799 then '750-799'
        else '800+'
    end
order by min(fico_score_low);

select min(fico_score_low) as min_fico, max(fico_score_low) as max_fico
from loandata_clean;

select
    loan_purpose,
    count(*) as total_loans,
    sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) as defaulted_loans,
    cast(sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) * 100.0 / count(*) as decimal(5,2)) as default_rate_pct,
    avg(loan_amount) as avg_loan_amount
from loandata_clean
group by loan_purpose
having count(*) > 1000  -- excludes extremely rare purposes with too few loans to be statistically meaningful
order by default_rate_pct desc;

select top 15
    borrower_state,
    count(*) as total_loans,
    sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) as defaulted_loans,
    cast(sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) * 100.0 / count(*) as decimal(5,2)) as default_rate_pct
from loandata_clean
group by borrower_state
having count(*) > 1000
order by default_rate_pct desc;

-- QUERY 8: default rate by employment length
select
    case when employment_length_years is null then 'NOT DISCLOSED' else cast(employment_length_years as nvarchar(10)) end as emp_length_years,
    count(*) as total_loans,
    sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) as defaulted_loans,
    cast(sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) * 100.0 / count(*) as decimal(5,2)) as default_rate_pct
from loandata_clean
group by employment_length_years
order by
    case when employment_length_years is null then 99 else employment_length_years end;


-- QUERY 9: default rate by dti band
select
    case
        when debt_to_income_ratio is null then 'NOT DISCLOSED'
        when debt_to_income_ratio < 10 then '< 10'
        when debt_to_income_ratio between 10 and 19.99 then '10-19.99'
        when debt_to_income_ratio between 20 and 29.99 then '20-29.99'
        when debt_to_income_ratio between 30 and 39.99 then '30-39.99'
        else '40+'
    end as dti_band,
    count(*) as total_loans,
    sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) as defaulted_loans,
    cast(sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) * 100.0 / count(*) as decimal(5,2)) as default_rate_pct
from loandata_clean
group by
    case
        when debt_to_income_ratio is null then 'NOT DISCLOSED'
        when debt_to_income_ratio < 10 then '< 10'
        when debt_to_income_ratio between 10 and 19.99 then '10-19.99'
        when debt_to_income_ratio between 20 and 29.99 then '20-29.99'
        when debt_to_income_ratio between 30 and 39.99 then '30-39.99'
        else '40+'
    end
order by min(isnull(debt_to_income_ratio, -1));


-- QUERY 10: default rate by annual income bracket
select
    case
        when annual_income < 30000 then '< 30k'
        when annual_income between 30000 and 59999.99 then '30k-59.9k'
        when annual_income between 60000 and 89999.99 then '60k-89.9k'
        when annual_income between 90000 and 119999.99 then '90k-119.9k'
        else '120k+'
    end as income_bracket,
    count(*) as total_loans,
    sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) as defaulted_loans,
    cast(sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) * 100.0 / count(*) as decimal(5,2)) as default_rate_pct
from loandata_clean
group by
    case
        when annual_income < 30000 then '< 30k'
        when annual_income between 30000 and 59999.99 then '30k-59.9k'
        when annual_income between 60000 and 89999.99 then '60k-89.9k'
        when annual_income between 90000 and 119999.99 then '90k-119.9k'
        else '120k+'
    end
order by min(annual_income);


-- QUERY 11: default rate trend over time (by loan issue year)
select
    year(loan_issue_date) as issue_year,
    count(*) as total_loans,
    sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) as defaulted_loans,
    cast(sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) * 100.0 / count(*) as decimal(5,2)) as default_rate_pct
from loandata_clean
group by year(loan_issue_date)
order by issue_year;


-- QUERY 12: default rate by home ownership status
select
    home_ownership_status,
    count(*) as total_loans,
    sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) as defaulted_loans,
    cast(sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) * 100.0 / count(*) as decimal(5,2)) as default_rate_pct
from loandata_clean
group by home_ownership_status
having count(*) > 1000
order by default_rate_pct desc;


-- QUERY 13: default rate by loan term (36 vs 60 months)
select
    loan_term_months,
    count(*) as total_loans,
    sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) as defaulted_loans,
    cast(sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) * 100.0 / count(*) as decimal(5,2)) as default_rate_pct,
    avg(interest_rate) as avg_interest_rate
from loandata_clean
group by loan_term_months
order by loan_term_months;


-- QUERY 14: default rate by income verification status
select
    income_verification_status,
    count(*) as total_loans,
    sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) as defaulted_loans,
    cast(sum(case when loan_status in ('CHARGED OFF', 'DEFAULT') then 1 else 0 end) * 100.0 / count(*) as decimal(5,2)) as default_rate_pct
from loandata_clean
group by income_verification_status
order by default_rate_pct desc;

select avg(fico_score_low) as avg_fico, avg(annual_income) as avg_income, count(*) as total
from loandata_clean
where debt_to_income_ratio >= 40;

select avg(fico_score_low) as avg_fico, avg(annual_income) as avg_income, count(*) as total
from loandata_clean
where debt_to_income_ratio >= 30 and debt_to_income_ratio < 40;

select income_verification_status, 
       avg(loan_amount) as avg_loan_amt, 
       avg(annual_income) as avg_income, 
       avg(debt_to_income_ratio) as avg_dti,
       count(*) as total
from loandata_clean
group by income_verification_status;
-- QUERY 1: CTE + CASE — risk segmentation by loan grade
with risk_segmented as (
    select
        loan_id, loan_grade, fico_score_low, debt_to_income_ratio, loan_status,
        case
            when loan_grade in ('A','B') then 'LOW RISK'
            when loan_grade in ('C','D') then 'MEDIUM RISK'
            else 'HIGH RISK'
        end as risk_segment
    from loandata_clean
)
select
    risk_segment,
    count(*) as total_loans,
    sum(case when loan_status in ('CHARGED OFF','DEFAULT') then 1 else 0 end) as defaulted_loans,
    cast(sum(case when loan_status in ('CHARGED OFF','DEFAULT') then 1 else 0 end) * 100.0 / count(*) as decimal(5,2)) as default_rate_pct
from risk_segmented
group by risk_segment
order by case risk_segment when 'LOW RISK' then 1 when 'MEDIUM RISK' then 2 else 3 end;


-- QUERY 2: RANK / DENSE_RANK — rank states by default rate
with state_risk as (
    select
        borrower_state,
        count(*) as total_loans,
        sum(case when loan_status in ('CHARGED OFF','DEFAULT') then 1 else 0 end) as defaulted_loans,
        cast(sum(case when loan_status in ('CHARGED OFF','DEFAULT') then 1 else 0 end) * 100.0 / count(*) as decimal(5,2)) as default_rate_pct
    from loandata_clean
    group by borrower_state
    having count(*) > 1000
)
select
    borrower_state,
    total_loans,
    default_rate_pct,
    rank() over (order by default_rate_pct desc) as risk_rank,
    dense_rank() over (order by default_rate_pct desc) as risk_dense_rank
from state_risk
order by risk_rank;


-- QUERY 3: RUNNING TOTAL — cumulative loan volume and defaulted amount by year-month
with monthly_summary as (
    select
        year(loan_issue_date) as issue_year,
        month(loan_issue_date) as issue_month,
        sum(loan_amount) as monthly_loan_amount,
        sum(case when loan_status in ('CHARGED OFF','DEFAULT') then loan_amount else 0 end) as monthly_defaulted_amount
    from loandata_clean
    group by year(loan_issue_date), month(loan_issue_date)
)
select
    issue_year,
    issue_month,
    monthly_loan_amount,
    sum(monthly_loan_amount) over (order by issue_year, issue_month rows unbounded preceding) as running_total_loan_amount,
    monthly_defaulted_amount,
    sum(monthly_defaulted_amount) over (order by issue_year, issue_month rows unbounded preceding) as running_total_defaulted_amount
from monthly_summary
order by issue_year, issue_month;


-- QUERY 4: LAG — year-over-year change in default rate (with maturity-bias note)
with yearly_default as (
    select
        year(loan_issue_date) as issue_year,
        count(*) as total_loans,
        sum(case when loan_status in ('CHARGED OFF','DEFAULT') then 1 else 0 end) as defaulted_loans,
        cast(sum(case when loan_status in ('CHARGED OFF','DEFAULT') then 1 else 0 end) * 100.0 / count(*) as decimal(5,2)) as default_rate_pct
    from loandata_clean
    group by year(loan_issue_date)
)
select
    issue_year,
    total_loans,
    default_rate_pct,
    lag(default_rate_pct) over (order by issue_year) as prev_year_default_rate,
    cast(default_rate_pct - lag(default_rate_pct) over (order by issue_year) as decimal(5,2)) as change_vs_prev_year
from yearly_default
order by issue_year;


-- QUERY 5: ROW_NUMBER — top 5 largest defaulted loans per grade
with ranked_defaults as (
    select
        loan_id, loan_grade, loan_amount, interest_rate, borrower_state, loan_status,
        row_number() over (partition by loan_grade order by loan_amount desc) as rn
    from loandata_clean
    where loan_status in ('CHARGED OFF','DEFAULT')
)
select loan_id, loan_grade, loan_amount, interest_rate, borrower_state
from ranked_defaults
where rn <= 5
order by loan_grade, loan_amount desc;


-- QUERY 6: SUBQUERY — purposes with default rate above the portfolio average
select
    loan_purpose,
    count(*) as total_loans,
    cast(sum(case when loan_status in ('CHARGED OFF','DEFAULT') then 1 else 0 end) * 100.0 / count(*) as decimal(5,2)) as default_rate_pct,
    (select cast(sum(case when loan_status in ('CHARGED OFF','DEFAULT') then 1 else 0 end) * 100.0 / count(*) as decimal(5,2))
     from loandata_clean) as portfolio_avg_default_rate
from loandata_clean
group by loan_purpose
having count(*) > 1000
   and cast(sum(case when loan_status in ('CHARGED OFF','DEFAULT') then 1 else 0 end) * 100.0 / count(*) as decimal(5,2)) >
       (select cast(sum(case when loan_status in ('CHARGED OFF','DEFAULT') then 1 else 0 end) * 100.0 / count(*) as decimal(5,2))
        from loandata_clean)
order by default_rate_pct desc;


-- QUERY 7: VIEW — reusable risk summary object (for power bi)
if object_id('vw_loan_risk_summary','V') is not null
    drop view vw_loan_risk_summary;
go

create or alter view vw_loan_risk_summary as
select
    loan_id, loan_grade, loan_subgrade, fico_score_low, fico_score_high,
    annual_income, debt_to_income_ratio, loan_amount, interest_rate,
    loan_purpose, borrower_state, loan_status, loan_issue_date,
    loan_term_months, income_verification_status,
    case
        when loan_grade in ('A','B') then 'LOW RISK'
        when loan_grade in ('C','D') then 'MEDIUM RISK'
        else 'HIGH RISK'
    end as risk_segment,
    case
        when loan_status in ('CHARGED OFF','DEFAULT') then 1
        else 0
    end as is_defaulted
from loandata_clean;

select top 10 * from vw_loan_risk_summary;

select * from vw_loan_risk_summary;