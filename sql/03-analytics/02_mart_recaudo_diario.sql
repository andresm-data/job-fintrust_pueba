-- ============================================================
-- Capa:        analytics (gold)
-- Dataset:     analytics_fintrust
-- Tabla:       mart_recaudo_diario
-- Pregunta:    Recaudo diario total vs. recaudo aplicado a cuotas vencidas.
-- Descripción: Tabla materializada. Clasifica cada pago confirmado según
--              si fue recibido DESPUÉS de la fecha de vencimiento de la
--              cuota (recaudo de mora) o dentro del plazo (recaudo corriente).
--              Criterio de mora temporal: payment_date > due_date.
-- Fuente:      staging_fintrust.stg_payments
--              staging_fintrust.stg_installments
-- ============================================================
CREATE SCHEMA IF NOT EXISTS analytics_fintrust;

CREATE
OR REPLACE TABLE analytics_fintrust.mart_recaudo_diario AS
SELECT
    p.payment_date AS fecha_recaudo,
    COUNT(p.payment_id) AS num_pagos,
    SUM(p.payment_amount) AS total_recaudo,
    -- Recaudo corriente: pagado dentro del plazo (payment_date <= due_date)
    SUM(
        CASE
            WHEN p.payment_date <= i.due_date THEN p.payment_amount
            ELSE 0
        END
    ) AS recaudo_corriente,
    -- Recaudo de mora: pagado después del vencimiento (payment_date > due_date)
    SUM(
        CASE
            WHEN p.payment_date > i.due_date THEN p.payment_amount
            ELSE 0
        END
    ) AS recaudo_mora,
    -- Porcentaje del recaudo diario que corresponde a mora
    ROUND(
        SAFE_DIVIDE (
            SUM(
                CASE
                    WHEN p.payment_date > i.due_date THEN p.payment_amount
                    ELSE 0
                END
            ),
            SUM(p.payment_amount)
        ) * 100,
        2
    ) AS pct_recaudo_mora,
    -- Número de pagos tardíos
    COUNTIF (p.payment_date > i.due_date) AS num_pagos_tardios
FROM
    staging_fintrust.stg_payments p
    INNER JOIN staging_fintrust.stg_installments i ON p.installment_id = i.installment_id
    -- Solo pagos confirmados y no revertidos
WHERE
    p.is_reversed = FALSE
    AND p.is_pending = FALSE
GROUP BY
    p.payment_date
ORDER BY
    p.payment_date;