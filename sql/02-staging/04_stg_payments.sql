CREATE SCHEMA IF NOT EXISTS staging_fintrust;

CREATE TABLE
    IF NOT EXISTS staging_fintrust.stg_payments (
        payment_id STRING NOT NULL,
        loan_id STRING,
        installment_id STRING,
        payment_date DATE,
        payment_amount NUMERIC,
        payment_channel STRING,
        payment_status STRING,
        raw_loaded_at TIMESTAMP,
        has_null_channel BOOL,
        is_reversed BOOL,
        is_pending BOOL,
        loaded_at TIMESTAMP
    );

MERGE staging_fintrust.stg_payments AS tgt USING (
    SELECT
        p.payment_id,
        p.loan_id,
        p.installment_id,
        p.payment_date,
        p.payment_amount,
        p.payment_channel,
        p.payment_status,
        p.loaded_at AS raw_loaded_at,
        p.payment_channel IS NULL AS has_null_channel,
        p.payment_status = 'REVERSED' AS is_reversed,
        p.payment_status = 'PENDING' AS is_pending,
        CURRENT_TIMESTAMP() AS loaded_at
    FROM
        raw_fintrust.payments p
        INNER JOIN raw_fintrust.installments i ON p.installment_id = i.installment_id
    WHERE
        p.payment_amount > 0
        AND p.loaded_at > (
            SELECT
                COALESCE(
                    MAX(raw_loaded_at),
                    TIMESTAMP('1970-01-01 00:00:00 UTC')
                )
            FROM
                staging_fintrust.stg_payments
        ) QUALIFY ROW_NUMBER() OVER (
            PARTITION BY
                p.payment_id
            ORDER BY
                p.loaded_at DESC
        ) = 1
) AS src ON tgt.payment_id = src.payment_id WHEN MATCHED THEN
UPDATE
SET
    loan_id = src.loan_id,
    installment_id = src.installment_id,
    payment_date = src.payment_date,
    payment_amount = src.payment_amount,
    payment_channel = src.payment_channel,
    payment_status = src.payment_status,
    raw_loaded_at = src.raw_loaded_at,
    has_null_channel = src.has_null_channel,
    is_reversed = src.is_reversed,
    is_pending = src.is_pending,
    loaded_at = src.loaded_at WHEN NOT MATCHED THEN INSERT (
        payment_id,
        loan_id,
        installment_id,
        payment_date,
        payment_amount,
        payment_channel,
        payment_status,
        raw_loaded_at,
        has_null_channel,
        is_reversed,
        is_pending,
        loaded_at
    )
VALUES
    (
        src.payment_id,
        src.loan_id,
        src.installment_id,
        src.payment_date,
        src.payment_amount,
        src.payment_channel,
        src.payment_status,
        src.raw_loaded_at,
        src.has_null_channel,
        src.is_reversed,
        src.is_pending,
        src.loaded_at
    );