# Validaciones de Calidad de Datos — FinTrust

---

## Contexto

El sistema de FinTrust gestiona créditos de consumo y recaudos. Cualquier anomalía en los datos puede derivar en sanciones o multas, pérdidas financieras no detectadas o decisiones de riesgo erróneas. Las validaciones aquí descritas forman la primera línea de defensa en la capa *staging* del pipeline.

---

## Suite 1 — `stg_customers`

### 1.1 Tabla no vacía
| Expectativa | `ExpectTableRowCountToBeGreaterThan(value=0)` |
|---|---|
| **Propósito** | Verifica que la tabla contenga al menos un registro. Una tabla vacía indica un fallo en la ingesta y haría que todos los análisis de clientes arrojaran resultados vacíos. |

### 1.2 No nulidad en `customer_id`
| Expectativa | `ExpectColumnValuesToNotBeNull(column="customer_id")` |
|---|---|
| **Propósito** | `customer_id` es la llave primaria del maestro de clientes. Sin ella, el registro no puede vincularse con créditos, cuotas ni pagos, rompiendo toda la cadena analítica. |

### 1.3 Unicidad de `customer_id`
| Expectativa | `ExpectColumnValuesToBeUnique(column="customer_id")` |
|---|---|
| **Propósito** | Garantiza que cada cliente aparezca una sola vez. Los duplicados generan doble conteo en métricas de cartera y pueden asignar segmentos distintos al mismo cliente físico. |

### 1.4 No nulidad en `full_name`
| Expectativa | `ExpectColumnValuesToNotBeNull(column="full_name")` |
|---|---|
| **Propósito** | El nombre completo es un campo de identificación obligatorio en los reportes a la SFC. Un cliente sin nombre no puede ser correctamente identificado ante la entidad regulatoria. |

### 1.5 No nulidad en `city`
| Expectativa | `ExpectColumnValuesToNotBeNull(column="city")` |
|---|---|
| **Propósito** | La ciudad es necesaria para el análisis geográfico de la cartera. Sin ella, el cliente queda excluido de los reportes de concentración regional. |

### 1.6 No nulidad en `created_at`
| Expectativa | `ExpectColumnValuesToNotBeNull(column="created_at")` |
|---|---|
| **Propósito** | La fecha de creación permite ordenar cronológicamente la base de clientes y calcular métricas de antigüedad. Un valor nulo imposibilita cualquier análisis temporal sobre el cliente. |

### 1.7 Segmento en dominio controlado
| Expectativa | `ExpectColumnValuesToBeInSet(column="segment", value_set=["Mass Market", "Premium", "SME"])` |
|---|---|
| **Propósito** | El segmento es una variable crítica para pricing y reporting. Un valor fuera del catálogo (p. ej., `"Masivo"` por error tipográfico) fragmenta los resultados analíticos y sesga las métricas de concentración de cartera. |

### 1.8 Ingreso mensual positivo
| Expectativa | `ExpectColumnValuesToBeBetween(column="monthly_income", min_value=0, strict_min=True)` |
|---|---|
| **Propósito** | El ingreso mensual es el insumo principal del scoring crediticio. Un valor nulo, cero o negativo indica un error en la fuente y distorsiona el análisis de capacidad de pago. |

---

## Suite 2 — `stg_loans`

### 2.1 Tabla no vacía
| Expectativa | `ExpectTableRowCountToBeGreaterThan(value=0)` |
|---|---|
| **Propósito** | Confirma que existen créditos registrados. Una tabla vacía impide calcular cualquier métrica de cartera, desembolso o mora. |

### 2.2 No nulidad en `loan_id`
| Expectativa | `ExpectColumnValuesToNotBeNull(column="loan_id")` |
|---|---|
| **Propósito** | `loan_id` es la llave primaria del crédito. Sin él, las cuotas y pagos asociados quedan huérfanos y no pueden ser rastreados en el pipeline. |

### 2.3 Unicidad de `loan_id`
| Expectativa | `ExpectColumnValuesToBeUnique(column="loan_id")` |
|---|---|
| **Propósito** | Duplicate créditos inflarian el total desembolsado y podrían generar planes de cuotas duplicados, distorsionando el saldo de cartera. |

### 2.4 No nulidad en `customer_id`
| Expectativa | `ExpectColumnValuesToNotBeNull(column="customer_id")` |
|---|---|
| **Propósito** | Vincula cada crédito con su titular. Sin esta referencia, el crédito queda sin dueño y los análisis de exposición por cliente (riesgo de concentración) son incorrectos. |

### 2.5 No nulidad en `origination_date`
| Expectativa | `ExpectColumnValuesToNotBeNull(column="origination_date")` |
|---|---|
| **Propósito** | La fecha de originación es el punto de inicio del ciclo de vida del crédito. Sin ella no es posible construir cohortes de desembolso ni validar la consistencia temporal de los pagos. |

### 2.6 No nulidad en `loan_cohort`
| Expectativa | `ExpectColumnValuesToNotBeNull(column="loan_cohort")` |
|---|---|
| **Propósito** | La cohorte agrupa créditos por período de originación, lo que es esencial para los reportes de evolución de cartera. Un valor nulo excluye el crédito de dichos análisis. |

### 2.7 Estado de crédito en dominio controlado
| Expectativa | `ExpectColumnValuesToBeInSet(column="loan_status", value_set=["ACTIVE", "CLOSED", "DEFAULT"])` |
|---|---|
| **Propósito** | El estado determina si el crédito se incluye en el cálculo de cartera vigente o en riesgo. Valores fuera del catálogo generan inconsistencias en las vistas de mora y en los reportes a la SFC. |

### 2.8 Tasa de interés en rango lógico [0.01 – 0.99]
| Expectativa | `ExpectColumnValuesToBeBetween(column="annual_rate", min_value=0.01, max_value=0.99)` |
|---|---|
| **Propósito** | Detecta la confusión entre formato porcentual y decimal (p. ej., `24` en vez de `0.24`). Una tasa fuera de rango contamina el cálculo de intereses esperados y los modelos de valoración de cartera. |

### 2.9 Monto de desembolso positivo
| Expectativa | `ExpectColumnValuesToBeBetween(column="principal_amount", min_value=1)` |
|---|---|
| **Propósito** | Un crédito con monto cero o negativo es inválido financiera y legalmente. Afecta directamente las métricas de desembolso acumulado y el cálculo del saldo de cartera. |

### 2.10 Plazo en meses entre 1 y 360
| Expectativa | `ExpectColumnValuesToBeBetween(column="term_months", min_value=1, max_value=360)` |
|---|---|
| **Propósito** | Un plazo de 0 meses hace inoperable la generación del plan de cuotas; uno superior a 360 (30 años) indica casi siempre un error de ingreso. El rango cubre el espectro realista de productos FinTrust. |

### 2.11 No nulidad en `product_type`
| Expectativa | `ExpectColumnValuesToNotBeNull(column="product_type")` |
|---|---|
| **Propósito** | El tipo de producto diferencia líneas de crédito (consumo, hipotecario, microcrédito). Un valor nulo impide segmentar la cartera por línea y puede alterar los análisis de distribución de productos. |

---

## Suite 3 — `stg_installments`

### 3.1 Tabla no vacía
| Expectativa | `ExpectTableRowCountToBeGreaterThan(value=0)` |
|---|---|
| **Propósito** | Verifica que existan cuotas registradas. Sin cuotas no es posible calcular saldos pendientes, mora ni recaudo esperado. |

### 3.2 No nulidad en `installment_id`
| Expectativa | `ExpectColumnValuesToNotBeNull(column="installment_id")` |
|---|---|
| **Propósito** | Es el identificador único de la cuota. Sin él, los pagos no pueden ser asociados a su cuota correspondiente, rompiendo el seguimiento del estado de pago. |

### 3.3 Unicidad de `installment_id`
| Expectativa | `ExpectColumnValuesToBeUnique(column="installment_id")` |
|---|---|
| **Propósito** | Cuotas duplicadas inflan artificialmente el saldo acumulado y pueden hacer que un mismo pago cancele dos registros de deuda en lugar de uno. |

### 3.4 No nulidad en `loan_id`
| Expectativa | `ExpectColumnValuesToNotBeNull(column="loan_id")` |
|---|---|
| **Propósito** | Vincula la cuota con su crédito padre. Sin esta referencia, la cuota queda huérfana y su saldo no se consolida en el total del crédito. |

### 3.5 No nulidad en `due_date`
| Expectativa | `ExpectColumnValuesToNotBeNull(column="due_date")` |
|---|---|
| **Propósito** | La fecha de vencimiento es el parámetro que determina si una cuota está en mora. Sin ella, el cálculo de días de atraso es imposible. |

### 3.6 Estado de cuota en dominio controlado
| Expectativa | `ExpectColumnValuesToBeInSet(column="installment_status", value_set=["PAID", "PARTIAL", "LATE", "DUE"])` |
|---|---|
| **Propósito** | El estado es el insumo primario del análisis de mora. Un valor no reconocido hace que la cuota no sea contabilizada en ninguna categoría, silenciando potencial cartera en riesgo. |

### 3.7 Principal de cuota positivo
| Expectativa | `ExpectColumnValuesToBeBetween(column="principal_due", min_value=0, strict_min=True)` |
|---|---|
| **Propósito** | Un capital pendiente de cero o negativo es matemáticamente inválido en cualquier plan de amortización y disminuiría artificialmente el saldo de cartera. |

### 3.8 Interés de cuota no negativo
| Expectativa | `ExpectColumnValuesToBeBetween(column="interest_due", min_value=0)` |
|---|---|
| **Propósito** | Un interés negativo, salvo nota de crédito explícita, indica un error en el cálculo del sistema originador. Contamina el ingreso financiero proyectado de la entidad. |

### 3.9 Número de cuota positivo
| Expectativa | `ExpectColumnValuesToBeBetween(column="installment_number", min_value=1)` |
|---|---|
| **Propósito** | El número de cuota ordena el plan de pagos. Un valor menor a 1 (cero o negativo) rompe el ordenamiento del plan y puede generar errores en el cálculo de la posición de mora. |

### 3.10 Total de cuota no negativo
| Expectativa | `ExpectColumnValuesToBeBetween(column="total_due", min_value=0)` |
|---|---|
| **Propósito** | `total_due` es la suma de capital e interés de la cuota. Un valor negativo indicaría una inconsistencia entre sus componentes y afectaría el cálculo del saldo total pendiente del crédito. |

---

## Suite 4 — `stg_payments`

### 4.1 Tabla no vacía
| Expectativa | `ExpectTableRowCountToBeGreaterThan(value=0)` |
|---|---|
| **Propósito** | Confirma que existen pagos registrados. Un resultado vacío puede significar una falla en la ingesta y haría que los reportes de recaudo muestren valores de cero. |

### 4.2 No nulidad en `payment_id`
| Expectativa | `ExpectColumnValuesToNotBeNull(column="payment_id")` |
|---|---|
| **Propósito** | Es el identificador único del pago. Sin él, el registro no puede ser rastreado ni auditado, y la integridad referencial con otras tablas no puede ser verificada. |

### 4.3 Unicidad de `payment_id`
| Expectativa | `ExpectColumnValuesToBeUnique(column="payment_id")` |
|---|---|
| **Propósito** | Pagos duplicados inflan el recaudo reportado y pueden marcar cuotas como pagadas cuando aún tienen saldo pendiente. Es una de las anomalías de mayor impacto financiero. |

### 4.4 No nulidad en `loan_id`
| Expectativa | `ExpectColumnValuesToNotBeNull(column="loan_id")` |
|---|---|
| **Propósito** | Permite asociar el pago con el crédito al que pertenece, condición necesaria para actualizar el saldo de cartera y verificar la consistencia temporal del pago. |

### 4.5 No nulidad en `installment_id`
| Expectativa | `ExpectColumnValuesToNotBeNull(column="installment_id")` |
|---|---|
| **Propósito** | Vincula el pago con la cuota específica que cancela. Sin esta referencia, el estado de la cuota no puede actualizarse correctamente y el recaudo no se refleja en el plan de pagos. |

### 4.6 No nulidad en `payment_date`
| Expectativa | `ExpectColumnValuesToNotBeNull(column="payment_date")` |
|---|---|
| **Propósito** | La fecha del pago es indispensable para el análisis de recaudo diario y para verificar que el pago ocurrió después de la originación del crédito. |

### 4.7 Monto de pago positivo
| Expectativa | `ExpectColumnValuesToBeBetween(column="payment_amount", min_value=0, strict_min=True)` |
|---|---|
| **Propósito** | La capa de staging ya filtra pagos de `$0`, por lo que esta prueba actúa como red de seguridad que confirma que dicha limpieza funcionó correctamente. Un pago de $0 no reduce cartera pero puede activar cambios de estado en la cuota. |

### 4.8 Estado de pago en dominio controlado
| Expectativa | `ExpectColumnValuesToBeInSet(column="payment_status", value_set=["CONFIRMED", "PENDING", "REVERSED"])` |
|---|---|
| **Propósito** | Solo los pagos confirmados deben reducir el saldo de cartera. Valores fuera de catálogo pueden hacer que pagos no confirmados sean contabilizados, o que pagos reales sean ignorados en las métricas de recaudo. |

---

## Suite 5 — Integridad Referencial (validación personalizada)

Estas comprobaciones no utilizan Great Expectations sino lógica de conjuntos en pandas. Su propósito es garantizar que las relaciones entre tablas sean coherentes antes de alimentar las vistas analíticas.

### 5.1 `payments.loan_id` → `stg_loans`
| Verificación | Todo `loan_id` en `stg_payments` debe existir en `stg_loans` |
|---|---|
| **Propósito** | Un pago sin crédito padre es un registro huérfano que no puede ser reconciliado con el saldo de cartera. Indica ya sea un error de ingesta o una eliminación indebida en la tabla de créditos. |

### 5.2 `payments.installment_id` → `stg_installments`
| Verificación | Todo `installment_id` en `stg_payments` debe existir en `stg_installments` |
|---|---|
| **Propósito** | Si el pago no puede ser asociado a ninguna cuota, no es posible actualizar su estado ni calcular correctamente el saldo de deuda pendiente del crédito. |

### 5.3 `installments.loan_id` → `stg_loans`
| Verificación | Todo `loan_id` en `stg_installments` debe existir en `stg_loans` |
|---|---|
| **Propósito** | Cuotas sin crédito padre son incobrables en el sistema: no pueden ser reportadas, cobradas ni asociadas a un cliente, contaminando el saldo global de cartera. |

---

## Suite 6 — Consistencia Temporal (validación personalizada)

### 6.1 Fecha de pago posterior a la originación
| Verificación | `payment_date >= origination_date` para cada pago según su crédito |
|---|---|
| **Propósito** | Es físicamente imposible recibir un pago antes de que el crédito haya sido desembolsado. Una violación señala una fecha errónea (ya sea en el pago o en la originación) que distorsionaría el análisis de recaudo por cohorte y los modelos de riesgo. |

---

## Validaciones Custom en Python

### 5. Integridad Referencial

| Check | Descripción |
|---|---|
| `payments → loans (loan_id)` | Todo pago debe estar vinculado a un crédito existente en `stg_loans`. Un pago huérfano no puede ser imputado a ningún cliente, imposibilitando el análisis de recaudo por segmento. |
| `payments → installments (installment_id)` | Todo pago debe referenciar una cuota real. Pagos que referencian cuotas inexistentes (como P101 → I999) son señal de errores en el sistema origen o potencialmente de fraude. |
| `installments → loans (loan_id)` | Toda cuota debe pertenecer a un crédito válido. Cuotas huérfanas inflarian artificialmente el saldo pendiente de cartera sin estar respaldadas por un desembolso real. |

### 6. Consistencia Temporal: `payment_date >= origination_date`

| Check | `payment_date >= origination_date` del crédito asociado |
|---|---|
| **Justificación** | Un pago registrado antes de la fecha en que se otorgó el crédito es fisicamente imposible. Esta anomalía indica: (a) un error de digitación en las fechas, (b) un problema de migración de datos históricos, o (c) en un escenario adverso, una manipulación intencional para mejorar artificialmente el historial de pagos de un cliente. Es un control crítico para el área de auditoría interna y cumplimiento. |

---

## Código de salida del script

| Código | Significado |
|---|---|
| `0` | Todas las validaciones pasaron. Pipeline puede continuar. |
| `1` | Al menos una validación falló o se produjo un error de conexión. El pipeline debe detenerse para revisión. |
