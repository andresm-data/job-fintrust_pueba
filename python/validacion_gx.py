# -*- coding:utf-8 -*-
import logging
import os
import sys
from typing import Callable

import great_expectations as gx
import pandas as pd
from google.cloud import bigquery
from great_expectations.core import ExpectationSuite
from great_expectations.expectations import (
    ExpectColumnValuesToBeBetween, ExpectColumnValuesToBeInSet,
    ExpectColumnValuesToBeUnique, ExpectColumnValuesToNotBeNull,
    ExpectTableRowCountToBeGreaterThan)


# =============================================================================
PROJECT_ID = os.environ.get("GCP_PROJECT_ID")
STAGING_DS = "staging_fintrust"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("validacion_gx")


# =============================================================================
def get_bq_client() -> bigquery.Client:
    """
    Crea un cliente de BigQuery utilizando las credenciales proporcionadas.

    Returns
    -------
    bigquery.Client
        Cliente de BigQuery autenticado con las credenciales proporcionadas.

    Raises
    ------
    ImportError
        Si no se encuentra el módulo 'google.oauth2.service_account'
    """
    creds_path = os.environ.get("GCP_CREDENTIALS")
    if creds_path:
        from google.oauth2 import service_account

        creds = service_account.Credentials.from_service_account_file(
            creds_path,
            scopes=["https://www.googleapis.com/auth/cloud-platform"],
        )

        return bigquery.Client(project=PROJECT_ID, credentials=creds)

    return bigquery.Client(project=PROJECT_ID)


# =============================================================================
def load_table(client: bigquery.Client, table: str) -> pd.DataFrame:
    """
    Ejecuta una consulta para cargar toda la tabla especificada desde BigQuery
    y retorna un DataFrame de pandas con los resultados.

    Parameters
    ----------
    client: bigquery.Client
        Cliente de BigQuery autenticado.
    table: str
        Nombre de la tabla a cargar.

    Returns
    -------
    pd.DataFrame
        DataFrame de pandas con los resultados de la consulta.
    """
    query = f"SELECT * FROM `{PROJECT_ID}.{STAGING_DS}.{table}`"
    log.info("  Cargando %s.%s …", STAGING_DS, table)
    df = client.query(query).to_dataframe()
    log.info("  %s filas cargadas.", len(df))

    return df


# =============================================================================
def run_suite(
    context: gx.AbstractDataContext,
    suite_name: str,
    df: pd.DataFrame,
    add_expectations: Callable[[ExpectationSuite], None],
) -> tuple[int, int]:
    """
    Ejecuta una suite de validación de Great Expectations sobre un DataFrame dado.

    Parameters
    ----------
    context: gx.AbstractDataContext
        Contexto de Great Expectations.
    suite_name: str
        Nombre de la suite de validación.
    df: pd.DataFrame
        DataFrame de pandas a validar.
    add_expectations: Callable[[ExpectationSuite], None]
        Función que agrega expectativas a la suite.

    Returns
    -------
    tuple[int, int]
        Cantidad de expectativas que pasaron y fallaron.
    """
    try:
        data_source = context.data_sources.add_pandas(name=suite_name)

    except Exception:
        data_source = context.data_sources[suite_name]

    asset = data_source.add_dataframe_asset(name=f"{suite_name}_asset")
    batch_def = asset.add_batch_definition_whole_dataframe(
        f"{suite_name}_batch"
    )

    # Crea la suite y agrega expectativas
    suite = context.suites.add(ExpectationSuite(name=suite_name))
    add_expectations(suite)

    # Crea la validación y la ejecuta
    val_def = context.validation_definitions.add(
        gx.ValidationDefinition(
            name=f"{suite_name}_validation",
            data=batch_def,
            suite=suite,
        )
    )
    result = val_def.run(batch_parameters={"dataframe": df})

    passed = sum(1 for r in result.results if r.success)
    failed = len(result.results) - passed

    log.info(
        "Suite: %-35s  %d/%d passed", suite_name, passed, len(result.results)
    )

    for r in result.results:
        icon = "✓" if r.success else "✗"
        col = r.expectation_config.kwargs.get("column", "—")
        etype = r.expectation_config.expectation_type
        log.info("  %s  %-50s  col:%s", icon, etype, col)

        if not r.success:
            obs = r.result.get("observed_value", "?")
            log.warning("      observed_value: %s", obs)

    return passed, failed


# =============================================================================
def expectations_customers(suite: ExpectationSuite) -> None:
    """
    Agrega expectativas de calidad de datos para la tabla stg_customers.

    Parameters
    ----------
    suite: ExpectationSuite
        Suite de expectativas a la que se agregarán las expectativas específicas
        para la tabla stg_customers.
    """
    suite.add_expectation(ExpectTableRowCountToBeGreaterThan(value=0))
    suite.add_expectation(ExpectColumnValuesToNotBeNull(column="customer_id"))
    suite.add_expectation(ExpectColumnValuesToBeUnique(column="customer_id"))
    suite.add_expectation(ExpectColumnValuesToNotBeNull(column="full_name"))
    suite.add_expectation(ExpectColumnValuesToNotBeNull(column="city"))
    suite.add_expectation(ExpectColumnValuesToNotBeNull(column="created_at"))
    suite.add_expectation(
        ExpectColumnValuesToBeInSet(column="segment", value_set=[
                                    "Mass Market", "Premium", "SME"])
    )
    suite.add_expectation(
        ExpectColumnValuesToBeBetween(
            column="monthly_income", min_value=0, strict_min=True)
    )


# =============================================================================
def expectations_loans(suite: ExpectationSuite) -> None:
    """
    Agrega expectativas de calidad de datos para la tabla stg_loans.

    Parameters
    ----------
    suite: ExpectationSuite
        Suite de expectativas a la que se agregarán las expectativas específicas
        para la tabla stg_loans.
    """
    suite.add_expectation(ExpectTableRowCountToBeGreaterThan(value=0))
    suite.add_expectation(ExpectColumnValuesToNotBeNull(column="loan_id"))
    suite.add_expectation(ExpectColumnValuesToBeUnique(column="loan_id"))
    suite.add_expectation(ExpectColumnValuesToNotBeNull(column="customer_id"))
    suite.add_expectation(
        ExpectColumnValuesToNotBeNull(column="origination_date")
    )
    suite.add_expectation(ExpectColumnValuesToNotBeNull(column="loan_cohort"))
    suite.add_expectation(
        ExpectColumnValuesToBeInSet(
            column="loan_status", value_set=["ACTIVE", "CLOSED", "DEFAULT"]
        )
    )
    # Tasa anual entre 1% y 99% (formato decimal 0.01–0.99)
    suite.add_expectation(
        ExpectColumnValuesToBeBetween(
            column="annual_rate", min_value=0.01, max_value=0.99)
    )
    # Monto desembolsado positivo
    suite.add_expectation(
        ExpectColumnValuesToBeBetween(column="principal_amount", min_value=1)
    )
    # Plazo entre 1 y 360 meses
    suite.add_expectation(
        ExpectColumnValuesToBeBetween(
            column="term_months", min_value=1, max_value=360)
    )
    suite.add_expectation(ExpectColumnValuesToNotBeNull(column="product_type"))


# =============================================================================
def expectations_installments(suite: ExpectationSuite) -> None:
    """
    Agrega expectativas de calidad de datos para la tabla stg_installments.

    Parameters
    ----------
    suite: ExpectationSuite
        Suite de expectativas a la que se agregarán las expectativas específicas
        para la tabla stg_installments.
    """
    suite.add_expectation(ExpectTableRowCountToBeGreaterThan(value=0))
    suite.add_expectation(
        ExpectColumnValuesToNotBeNull(column="installment_id")
    )
    suite.add_expectation(
        ExpectColumnValuesToBeUnique(column="installment_id")
    )
    suite.add_expectation(ExpectColumnValuesToNotBeNull(column="loan_id"))
    suite.add_expectation(ExpectColumnValuesToNotBeNull(column="due_date"))
    suite.add_expectation(
        ExpectColumnValuesToBeInSet(
            column="installment_status",
            value_set=["PAID", "PARTIAL", "LATE", "DUE"],
        )
    )
    # Principal positivo
    suite.add_expectation(
        ExpectColumnValuesToBeBetween(
            column="principal_due", min_value=0, strict_min=True)
    )
    # Interés no negativo
    suite.add_expectation(
        ExpectColumnValuesToBeBetween(column="interest_due", min_value=0)
    )
    # Número de cuota positivo
    suite.add_expectation(
        ExpectColumnValuesToBeBetween(column="installment_number", min_value=1)
    )
    # total_due no negativo
    suite.add_expectation(
        ExpectColumnValuesToBeBetween(column="total_due", min_value=0)
    )


# =============================================================================
def expectations_payments(suite: ExpectationSuite) -> None:
    """
    Agrega expectativas de calidad de datos para la tabla stg_payments.

    Parameters
    ----------
    suite: ExpectationSuite
        Suite de expectativas a la que se agregarán las expectativas específicas
        para la tabla stg_payments.
    """
    suite.add_expectation(ExpectTableRowCountToBeGreaterThan(value=0))
    suite.add_expectation(ExpectColumnValuesToNotBeNull(column="payment_id"))
    suite.add_expectation(ExpectColumnValuesToBeUnique(column="payment_id"))
    suite.add_expectation(ExpectColumnValuesToNotBeNull(column="loan_id"))
    suite.add_expectation(
        ExpectColumnValuesToNotBeNull(column="installment_id")
    )
    suite.add_expectation(ExpectColumnValuesToNotBeNull(column="payment_date"))
    # Monto positivo
    suite.add_expectation(
        ExpectColumnValuesToBeBetween(
            column="payment_amount", min_value=0, strict_min=True)
    )
    suite.add_expectation(
        ExpectColumnValuesToBeInSet(
            column="payment_status", value_set=["CONFIRMED", "PENDING", "REVERSED"]
        )
    )


# =============================================================================
def check_referential_integrity(
    df_loans: pd.DataFrame,
    df_installments: pd.DataFrame,
    df_payments: pd.DataFrame,
) -> dict[str, dict]:
    """
    Valida integridad referencial entre las tablas stg_loans, stg_installments y
    stg_payments.

    Parameters
    ----------
    df_loans: pd.DataFrame
        DataFrame con los datos de stg_loans.
    df_installments: pd.DataFrame
        DataFrame con los datos de stg_installments.
    df_payments: pd.DataFrame
        DataFrame con los datos de stg_payments.

    Returns
    -------
    dict[str, dict]
        Diccionario con los resultados de las validaciones de integridad
        referencial, indicando si pasaron o fallaron, el conteo de
        violaciones y ejemplos de IDs problemáticos.
    """
    loan_ids = set(df_loans["loan_id"])
    installment_ids = set(df_installments["installment_id"])

    # payment.loan_id debe existir en stg_loans
    orphan_pay_loan = df_payments[~df_payments["loan_id"].isin(loan_ids)]

    # payment.installment_id debe existir en stg_installments
    orphan_pay_inst = df_payments[~df_payments["installment_id"].isin(
        installment_ids)]

    # installment.loan_id debe existir en stg_loans
    orphan_inst_loan = df_installments[~df_installments["loan_id"].isin(
        loan_ids)]

    return {
        "payments → loans  (loan_id)": {
            "pass": len(orphan_pay_loan) == 0,
            "violations": len(orphan_pay_loan),
            "ids": orphan_pay_loan["payment_id"].tolist()[:10],
        },
        "payments → installments  (installment_id)": {
            "pass": len(orphan_pay_inst) == 0,
            "violations": len(orphan_pay_inst),
            "ids": orphan_pay_inst["payment_id"].tolist()[:10],
        },
        "installments → loans  (loan_id)": {
            "pass": len(orphan_inst_loan) == 0,
            "violations": len(orphan_inst_loan),
            "ids": orphan_inst_loan["installment_id"].tolist()[:10],
        },
    }


# =============================================================================
def check_temporal_consistency(
    df_payments: pd.DataFrame,
    df_loans: pd.DataFrame,
) -> dict[str, dict]:
    """
    Valida la consistencia temporal entre las fechas de pago en stg_payments y
    las fechas de originación en stg_loans, asegurando que no existan pagos
    registrados antes de la fecha de originación del préstamo correspondiente.

    Parameters
    ----------
    df_payments: pd.DataFrame
        DataFrame con los datos de stg_payments.
    df_loans: pd.DataFrame
        DataFrame con los datos de stg_loans.

    Returns
    -------
    dict[str, dict]
        Diccionario con los resultados de la validación de consistencia temporal,
        indicando si pasó o falló, el conteo de violaciones y ejemplos de IDs
        problemáticos.
    """
    merged = df_payments.merge(
        df_loans[["loan_id", "origination_date"]], on="loan_id", how="left"
    )
    merged["payment_date"] = pd.to_datetime(merged["payment_date"])
    merged["origination_date"] = pd.to_datetime(merged["origination_date"])

    violations = merged[merged["payment_date"] < merged["origination_date"]]

    return {
        "payment_date >= origination_date": {
            "pass":       len(violations) == 0,
            "violations": len(violations),
            "ids":        violations["payment_id"].tolist()[:10],
        }
    }


# =============================================================================
def print_custom_checks(section: str, checks: dict[str, dict]) -> int:
    """
    Imprime los resultados de validaciones personalizadas y
    retorna la cantidad de validaciones que fallaron.

    Parameters
    ----------
    section: str
        Nombre de la sección de validaciones.
    checks: dict[str, dict]
        Diccionario con los resultados de las validaciones.

    Returns
    -------
    int
        Cantidad de validaciones que fallaron.
    """
    log.info("─" * 50)
    log.info("%s:", section)
    failures = 0

    for name, result in checks.items():
        icon = "✓" if result["pass"] else "✗"
        log.info("  %s  %s  (violaciones: %d)",
                 icon, name, result["violations"])
        if not result["pass"]:
            failures += 1
            log.warning("      IDs problemáticos: %s", result["ids"])

    return failures


# =============================================================================
def main() -> int:
    """
    Función principal que ejecuta las validaciones de calidad de datos.

    Returns
    -------
    int
        Código de salida: 0 si todas las validaciones pasan, 1 si alguna falla.

    Raises
    ------
    Exception
        Si ocurre un error durante la carga de datos o la ejecución de las suites.
    """
    log.info("Validación de calidad de datos")

    try:
        client = get_bq_client()
        df_customers = load_table(client, "stg_customers")
        df_loans = load_table(client, "stg_loans")
        df_installments = load_table(client, "stg_installments")
        df_payments = load_table(client, "stg_payments")

    except Exception as exc:
        log.error("Error cargando datos desde BigQuery: %s", exc)
        return 1

    context = gx.get_context(mode="ephemeral")

    total_passed = 0
    total_failed = 0

    suites = [
        ("stg_customers", df_customers, expectations_customers),
        ("stg_loans", df_loans, expectations_loans),
        ("stg_installments", df_installments, expectations_installments),
        ("stg_payments", df_payments, expectations_payments),
    ]

    for suite_name, df, add_exp in suites:
        try:
            p, f = run_suite(context, suite_name, df, add_exp)
            total_passed += p
            total_failed += f

        except Exception as exc:
            log.error("Error ejecutando suite '%s': %s", suite_name, exc)
            total_failed += 1

    ri = check_referential_integrity(df_loans, df_installments, df_payments)
    total_failed += print_custom_checks("Integridad referencial", ri)

    tc = check_temporal_consistency(df_payments, df_loans)
    total_failed += print_custom_checks("Consistencia temporal", tc)

    if total_failed == 0:
        log.info("RESULTADO FINAL:  TODAS LAS VALIDACIONES PASARON  ✓")
        log.info("Validaciones correctas: %d", total_passed)

    else:
        log.error("RESULTADO FINAL:  %d VALIDACIÓN(ES) FALLARON  ✗", total_failed)
        log.info(
            "Validaciones correctas: %d  |  Validaciones fallidas: %d",
            total_passed, total_failed)

    return 0 if total_failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
