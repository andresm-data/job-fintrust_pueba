CREATE SCHEMA IF NOT EXISTS analytics_fintrust;

CREATE
OR REPLACE TABLE analytics_fintrust.mart_desembolsos_diarios AS
SELECT
    l.origination_date AS fecha_desembolso,
    c.city AS ciudad,
    c.segment AS segmento,
    l.product_type AS tipo_producto,
    COUNT(l.loan_id) AS num_creditos,
    SUM(l.principal_amount) AS total_desembolsado,
    AVG(l.principal_amount) AS promedio_desembolso,
    MIN(l.principal_amount) AS min_desembolso,
    MAX(l.principal_amount) AS max_desembolso
FROM
    staging_fintrust.stg_loans l
    INNER JOIN staging_fintrust.stg_customers c ON l.customer_id = c.customer_id
WHERE
    l.is_valid = TRUE
    AND c.is_valid = TRUE
GROUP BY
    l.origination_date,
    c.city,
    c.segment,
    l.product_type
ORDER BY
    l.origination_date,
    c.city,
    c.segment;