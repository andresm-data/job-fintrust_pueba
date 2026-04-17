CREATE SCHEMA IF NOT EXISTS staging_fintrust;

CREATE TABLE
    IF NOT EXISTS staging_fintrust.stg_installments (
        installment_id STRING NOT NULL,
        loan_id STRING,
        installment_number INT64,
        due_date DATE,
        principal_due NUMERIC,
        interest_due NUMERIC,
        installment_status STRING,
        total_due NUMERIC,
        is_valid BOOL,
        loaded_at TIMESTAMP
    );

MERGE staging_fintrust.stg_installments AS tgt USING (
    SELECT
        i.installment_id,
        i.loan_id,
        i.installment_number,
        i.due_date,
        i.principal_due,
        i.interest_due,
        UPPER(TRIM(i.installment_status)) AS installment_status,
        i.principal_due + i.interest_due AS total_due,
        (
            i.installment_id IS NOT NULL
            AND i.loan_id IS NOT NULL
            AND i.installment_number > 0
            AND i.installment_number <= l.term_months
            AND i.due_date >= l.origination_date
            AND i.principal_due > 0
            AND i.interest_due >= 0
            AND UPPER(TRIM(i.installment_status)) IN ('PAID', 'PARTIAL', 'LATE', 'DUE')
        ) AS is_valid,
        CURRENT_TIMESTAMP() AS loaded_at
    FROM
        raw_fintrust.installments i
        INNER JOIN raw_fintrust.loans l ON i.loan_id = l.loan_id
    WHERE
        i.installment_id IS NOT NULL
        AND i.installment_number <= l.term_months
        AND i.due_date >= l.origination_date QUALIFY ROW_NUMBER() OVER (
            PARTITION BY
                i.installment_id
            ORDER BY
                i.due_date
        ) = 1
) AS src ON tgt.installment_id = src.installment_id WHEN MATCHED THEN
UPDATE
SET
    loan_id = src.loan_id,
    installment_number = src.installment_number,
    due_date = src.due_date,
    principal_due = src.principal_due,
    interest_due = src.interest_due,
    installment_status = src.installment_status,
    total_due = src.total_due,
    is_valid = src.is_valid,
    loaded_at = src.loaded_at WHEN NOT MATCHED THEN INSERT (
        installment_id,
        loan_id,
        installment_number,
        due_date,
        principal_due,
        interest_due,
        installment_status,
        total_due,
        is_valid,
        loaded_at
    )
VALUES
    (
        src.installment_id,
        src.loan_id,
        src.installment_number,
        src.due_date,
        src.principal_due,
        src.interest_due,
        src.installment_status,
        src.total_due,
        src.is_valid,
        src.loaded_at
    );