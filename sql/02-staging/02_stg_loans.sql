CREATE SCHEMA IF NOT EXISTS staging_fintrust;

CREATE TABLE IF NOT EXISTS staging_fintrust.stg_loans (
  loan_id           STRING  NOT NULL,
  customer_id       STRING,
  origination_date  DATE,
  principal_amount  NUMERIC,
  annual_rate       NUMERIC,
  term_months       INT64,
  loan_status       STRING,
  product_type      STRING,
  loan_cohort       STRING,
  is_valid          BOOL,
  loaded_at         TIMESTAMP
);

MERGE staging_fintrust.stg_loans AS tgt
USING (
  SELECT
    loan_id,
    customer_id,
    origination_date,
    principal_amount,
    annual_rate,
    term_months,
    UPPER(TRIM(loan_status))                  AS loan_status,
    TRIM(product_type)                        AS product_type,
    FORMAT_DATE('%Y-%m', origination_date)    AS loan_cohort,
    (
      loan_id          IS NOT NULL
      AND customer_id  IS NOT NULL
      AND principal_amount > 0
      AND annual_rate  BETWEEN 0.01 AND 0.99
      AND term_months  > 0
      AND UPPER(TRIM(loan_status)) IN ('ACTIVE', 'CLOSED', 'DEFAULT')
      AND origination_date IS NOT NULL
    )                                         AS is_valid,
    CURRENT_TIMESTAMP()                       AS loaded_at
  FROM raw_fintrust.loans
  WHERE loan_id IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY loan_id ORDER BY origination_date DESC) = 1
) AS src
ON tgt.loan_id = src.loan_id

WHEN MATCHED THEN
  UPDATE SET
    customer_id      = src.customer_id,
    origination_date = src.origination_date,
    principal_amount = src.principal_amount,
    annual_rate      = src.annual_rate,
    term_months      = src.term_months,
    loan_status      = src.loan_status,
    product_type     = src.product_type,
    loan_cohort      = src.loan_cohort,
    is_valid         = src.is_valid,
    loaded_at        = src.loaded_at

WHEN NOT MATCHED THEN
  INSERT (
    loan_id, customer_id, origination_date, principal_amount, annual_rate,
    term_months, loan_status, product_type, loan_cohort, is_valid, loaded_at
  )
  VALUES (
    src.loan_id, src.customer_id, src.origination_date, src.principal_amount,
    src.annual_rate, src.term_months, src.loan_status, src.product_type,
    src.loan_cohort, src.is_valid, src.loaded_at
  );
