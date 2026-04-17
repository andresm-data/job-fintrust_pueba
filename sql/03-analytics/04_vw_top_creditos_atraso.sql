CREATE SCHEMA IF NOT EXISTS analytics_fintrust;

CREATE
OR REPLACE VIEW analytics_fintrust.vw_top_creditos_atraso AS
WITH
    pagos_por_cuota AS (
        SELECT
            installment_id,
            SUM(payment_amount) AS total_pagado
        FROM
            staging_fintrust.stg_payments
        WHERE
            is_reversed = FALSE
            AND is_pending = FALSE
        GROUP BY
            installment_id
    ),
    metricas_por_credito AS (
        SELECT
            l.loan_id,
            l.customer_id,
            c.full_name AS nombre_cliente,
            c.city AS ciudad,
            c.segment AS segmento,
            l.product_type AS tipo_producto,
            l.origination_date AS fecha_desembolso,
            l.loan_cohort AS cohorte,
            l.principal_amount AS monto_desembolsado,
            l.loan_status AS estado_credito,
            COUNTIF (i.installment_status = 'LATE') AS num_cuotas_mora,
            MAX(
                CASE
                    WHEN i.installment_status = 'LATE' THEN DATE_DIFF (CURRENT_DATE(), i.due_date, DAY)
                    ELSE 0
                END
            ) AS dias_atraso,
            SUM(
                CASE
                    WHEN i.installment_status IN ('LATE', 'DUE', 'PARTIAL') THEN GREATEST (i.total_due - COALESCE(pp.total_pagado, 0), 0)
                    ELSE 0
                END
            ) AS saldo_pendiente,
            SUM(
                CASE
                    WHEN i.installment_status = 'PAID' THEN i.total_due
                    ELSE 0
                END
            ) AS monto_recuperado
        FROM
            staging_fintrust.stg_loans l
            INNER JOIN staging_fintrust.stg_customers c ON l.customer_id = c.customer_id
            INNER JOIN staging_fintrust.stg_installments i ON l.loan_id = i.loan_id
            LEFT JOIN pagos_por_cuota pp ON i.installment_id = pp.installment_id
        WHERE
            l.is_valid = TRUE
            AND l.loan_status != 'CLOSED'
        GROUP BY
            l.loan_id,
            l.customer_id,
            c.full_name,
            c.city,
            c.segment,
            l.product_type,
            l.origination_date,
            l.loan_cohort,
            l.principal_amount,
            l.loan_status
        HAVING
            COUNTIF (i.installment_status = 'LATE') > 0
            OR l.loan_status = 'DEFAULT'
    )
SELECT
    ROW_NUMBER() OVER (
        ORDER BY
            dias_atraso DESC,
            saldo_pendiente DESC
    ) AS ranking,
    loan_id,
    customer_id,
    nombre_cliente,
    ciudad,
    segmento,
    tipo_producto,
    cohorte,
    fecha_desembolso,
    monto_desembolsado,
    estado_credito,
    num_cuotas_mora,
    dias_atraso,
    saldo_pendiente,
    monto_recuperado,
    ROUND(
        SAFE_DIVIDE (saldo_pendiente, monto_desembolsado) * 100,
        2
    ) AS pct_saldo_sobre_desembolso
FROM
    metricas_por_credito
ORDER BY
    dias_atraso DESC,
    saldo_pendiente DESC
LIMIT
    10;