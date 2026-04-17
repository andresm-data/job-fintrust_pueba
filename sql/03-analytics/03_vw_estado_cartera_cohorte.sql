CREATE SCHEMA IF NOT EXISTS analytics_fintrust;

CREATE
OR REPLACE VIEW analytics_fintrust.vw_estado_cartera_cohorte AS
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
    cuotas_con_saldo AS (
        SELECT
            i.installment_id,
            i.loan_id,
            i.due_date,
            i.installment_status,
            i.total_due,
            COALESCE(pp.total_pagado, 0) AS total_pagado,
            GREATEST (i.total_due - COALESCE(pp.total_pagado, 0), 0) AS saldo_neto
        FROM
            staging_fintrust.stg_installments i
            LEFT JOIN pagos_por_cuota pp ON i.installment_id = pp.installment_id
    ),
    estado_por_credito AS (
        SELECT
            l.loan_id,
            l.customer_id,
            l.origination_date,
            l.loan_cohort,
            l.principal_amount,
            l.loan_status,
            c.segment,
            c.city,
            CASE
                WHEN l.loan_status = 'DEFAULT' THEN 'EN MORA'
                WHEN MAX(
                    CASE
                        WHEN cs.installment_status = 'LATE' THEN 1
                        ELSE 0
                    END
                ) = 1 THEN 'EN MORA'
                ELSE 'AL DÍA'
            END AS estado_cartera,
            MAX(
                CASE
                    WHEN cs.installment_status = 'LATE' THEN DATE_DIFF (CURRENT_DATE(), cs.due_date, DAY)
                    ELSE 0
                END
            ) AS dias_atraso,
            SUM(
                CASE
                    WHEN cs.installment_status IN ('LATE', 'DUE', 'PARTIAL') THEN cs.saldo_neto
                    ELSE 0
                END
            ) AS saldo_pendiente
        FROM
            staging_fintrust.stg_loans l
            INNER JOIN staging_fintrust.stg_customers c ON l.customer_id = c.customer_id
            LEFT JOIN cuotas_con_saldo cs ON l.loan_id = cs.loan_id
        WHERE
            l.is_valid = TRUE
            AND c.is_valid = TRUE
            AND l.loan_status != 'CLOSED'
        GROUP BY
            l.loan_id,
            l.customer_id,
            l.origination_date,
            l.loan_cohort,
            l.principal_amount,
            l.loan_status,
            c.segment,
            c.city
    )
SELECT
    loan_cohort AS cohorte_originacion,
    segment AS segmento,
    estado_cartera,
    COUNT(loan_id) AS num_creditos,
    SUM(principal_amount) AS total_capital_colocado,
    SUM(saldo_pendiente) AS total_saldo_pendiente,
    ROUND(AVG(dias_atraso), 1) AS promedio_dias_atraso,
    MAX(dias_atraso) AS max_dias_atraso,
    ROUND(
        SAFE_DIVIDE (
            COUNTIF (estado_cartera = 'EN MORA'),
            COUNT(loan_id)
        ) * 100,
        2
    ) AS tasa_mora_pct
FROM
    estado_por_credito
GROUP BY
    loan_cohort,
    segment,
    estado_cartera
ORDER BY
    loan_cohort,
    segment,
    estado_cartera;