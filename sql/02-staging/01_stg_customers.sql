CREATE SCHEMA IF NOT EXISTS staging_fintrust;

CREATE TABLE
    IF NOT EXISTS staging_fintrust.stg_customers (
        customer_id STRING NOT NULL,
        full_name STRING,
        city STRING,
        segment STRING,
        monthly_income NUMERIC,
        created_at DATE,
        is_valid BOOL,
        loaded_at TIMESTAMP
    );

MERGE staging_fintrust.stg_customers AS tgt USING (
    SELECT
        customer_id,
        TRIM(full_name) AS full_name,
        INITCAP (TRIM(city)) AS city,
        TRIM(segment) AS segment,
        monthly_income,
        created_at,
        (
            customer_id IS NOT NULL
            AND monthly_income > 0
            AND segment IN ('Mass Market', 'Premium', 'SME')
            AND created_at IS NOT NULL
        ) AS is_valid,
        CURRENT_TIMESTAMP() AS loaded_at
    FROM
        raw_fintrust.customers
    WHERE
        customer_id IS NOT NULL QUALIFY ROW_NUMBER() OVER (
            PARTITION BY
                customer_id
            ORDER BY
                created_at DESC
        ) = 1
) AS src ON tgt.customer_id = src.customer_id WHEN MATCHED THEN
UPDATE
SET
    full_name = src.full_name,
    city = src.city,
    segment = src.segment,
    monthly_income = src.monthly_income,
    created_at = src.created_at,
    is_valid = src.is_valid,
    loaded_at = src.loaded_at WHEN NOT MATCHED THEN INSERT (
        customer_id,
        full_name,
        city,
        segment,
        monthly_income,
        created_at,
        is_valid,
        loaded_at
    )
VALUES
    (
        src.customer_id,
        src.full_name,
        src.city,
        src.segment,
        src.monthly_income,
        src.created_at,
        src.is_valid,
        src.loaded_at
    );