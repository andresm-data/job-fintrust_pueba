# Supuestos, Decisiones de Diseño y Transformaciones Aplicadas

## Plataforma y entorno de ejecución

El pipeline se diseñó sobre GCP con BigQuery como motor principal, ya que los tipos del DDL (`STRING`, `INT64`, `NUMERIC`, `BOOL`, `TIMESTAMP`) y funciones como `CURRENT_TIMESTAMP()` y `QUALIFY` son nativos de BigQuery, por lo que adaptar el proyecto a otro motor como PostgreSQL o DuckDB implicaría varios reprocesos. El proyecto se organiza en tres schemas: `raw_fintrust` con los datos originales sin modificar, `staging_fintrust` con los datos limpios y validados, y `analytics_fintrust` con las tablas y vistas que alimentan el análisis de negocio.

---

## Supuesto: Definición de "mora"

Se usó el criterio de que un crédito está en mora si su `loan_status` es `'DEFAULT'` o si tiene al menos una cuota con `installment_status = 'LATE'`. Lo que clasifica a un crédito como vencido cuando tiene cuotas sin pagar tras su fecha de vencimiento.

---

## Supuesto: Saldo pendiente neto

El saldo de cada cuota se calcula como la diferencia entre el total adeudado y la suma de los pagos confirmados (no revertidos, no pendientes), llevando el resultado a cero si los pagos superan el monto debido. Se asume que todos los pagos reducen la obligación total de la cuota sin distinguir entre capital e interés.

---

## Estrategia de carga incremental

Para clientes, créditos y cuotas se aplica un MERGE completo en cada ejecución, ya que las fuentes no tienen campo `updated_at` que permita detectar cambios. Los volúmenes son pequeños, por lo que el costo no es significativo. Para pagos se aprovecha el campo `loaded_at` de la tabla raw para una carga incremental basada en watermark, lo que hace el proceso eficiente a medida que la tabla crece.

---

## Diseño de la capa analytics (gold)

Los marts de desembolsos y recaudo se materializan en tablas físicas porque los datos históricos son estáticos y recalcularlos en cada consulta sería costoso. Las vistas de estado de cartera y top de créditos en atraso, en cambio, se dejan sin materializar porque reflejan el estado actual del portafolio y deben mostrar siempre los datos más recientes.

---

## Limitaciones conocidas y trabajo futuro

Hay varios puntos que convendría resolver antes de llevar esto a producción. No se calculan los tramos de mora según la normatividad vigente, lo que limita los reportes regulatorios; hacerlo requeriría calcular los días exactos de mora por cuota. El saldo pendiente tampoco distingue entre capital e interés, lo que restringe los análisis contables; la solución sería construir una tabla de amortización teórica por crédito. Las tablas materializadas se reconstruyen por completo en cada ejecución, lo cual no escala bien; lo ideal sería un append incremental con ventana de fechas. Finalmente, los timestamps de `loaded_at` no están normalizados a UTC, lo que introduce riesgo de duplicados en cambios de hora.
