# FINTRUST

Pipeline de ingeniería de datos sobre Google BigQuery que implementa una arquitectura
medallón en tres capas (raw, staging, analytics) para FinTrust. Incluye validaciones de calidad de datos con Great Expectations y consultas analíticas
sobre desembolsos, recaudo y gestión de cartera.

---

## Tabla de contenido

1. [Descripción del proyecto](#1-descripción-del-proyecto)
2. [Estructura del proyecto](#2-estructura-del-proyecto)
3. [Instalación](#3-instalación)
4. [Uso](#4-uso)




&nbsp;

---

## 1. Descripción del proyecto

El repositorio implementa un pipeline de datos de extremo a extremo para el negocio
de crédito de consumo de FinTrust, ejecutado sobre Google Cloud Platform (GCP) con
BigQuery como motor de almacenamiento y procesamiento. El objetivo central es
centralizar, limpiar y analizar cuatro entidades operativas —clientes, créditos,
cuotas y pagos— garantizando la trazabilidad de cada registro desde su ingesta hasta
su consumo analítico.

El flujo de datos traversa tres esquemas de BigQuery organizados en capas:

- **`raw_fintrust`** — recibe los datos de origen sin modificación alguna. Contiene
  las tablas `customers`, `loans`, `installments` y `payments`, creadas mediante
  sentencias DDL con datos de prueba representativos.

- **`staging_fintrust`** — aplica transformaciones de limpieza, normalización y
  deduplicación mediante operaciones `MERGE`. Cada registro marcado como inválido
  (`is_valid = FALSE`) es aislado del procesamiento analítico sin ser eliminado de la
  capa, preservando la trazabilidad completa. La carga es incremental para pagos
  (basada en *watermark* sobre `loaded_at`) y por `MERGE` completo para las demás
  entidades, dado que no disponen de campo `updated_at`.

- **`analytics_fintrust`** — consolida el resultado analítico en dos tablas mart
  materializadas (`mart_desembolsos_diarios`, `mart_recaudo_diario`) y dos vistas no
  materializadas (`vw_estado_cartera_cohorte`, `vw_top_creditos_atraso`). Las tablas
  mart almacenan datos históricos estáticos; las vistas reflejan el estado actual de
  la cartera en tiempo real.

El módulo Python (`python/`) implementa un pipeline de validación de calidad de datos
mediante Great Expectations. Ejecuta cuatro suites de expectativas sobre
las tablas de la capa staging (37 expectativas en total), complementadas con
verificaciones personalizadas de integridad referencial entre tablas y de consistencia
temporal entre fechas de pago y fechas de originación de cada crédito.




&nbsp;

---

## 2. Estructura del proyecto

```
fintrust/
├── README.md                                   # Documentación principal del repositorio
├── bonus/                                      # Carpeta reservada para entregables adicionales
├── docs/                                       # Documentación técnica del pipeline
│   ├── supuestos_y_decisiones.md               # Supuestos de diseño y decisiones de arquitectura
│   └── validaciones_gx.md                      # Catálogo de expectativas de Great Expectations
├── python/                                     # Módulos Python del pipeline de validación
│   ├── main.py                                 # Punto de entrada del pipeline de validación
│   ├── requirements.txt                        # Dependencias del entorno virtual
│   └── validacion_gx.py                        # Suites GX, integridad referencial y consistencia temporal
└── sql/                                        # Scripts SQL por capa del pipeline
    ├── 01-raw/                                 # DDL e inserción de datos en la capa raw
    │   ├── 01_customers.sql                    # Tabla raw: maestro de clientes
    │   ├── 02_loans.sql                        # Tabla raw: créditos desembolsados
    │   ├── 03_installments.sql                 # Tabla raw: plan de cuotas
    │   └── 04_payments.sql                     # Tabla raw: registro de pagos
    ├── 02-staging/                             # Transformaciones y limpieza (capa staging)
    │   ├── 01_stg_customers.sql                # Staging: limpieza y deduplicación de clientes
    │   ├── 02_stg_loans.sql                    # Staging: enriquecimiento y filtrado de créditos
    │   ├── 03_stg_installments.sql             # Staging: cálculo de saldo pendiente por cuota
    │   └── 04_stg_payments.sql                 # Staging: filtro de pagos inválidos o revertidos
    ├── 03-analytics/                           # Tablas mart y vistas analíticas (capa gold)
    │   ├── 01_mart_desembolsos_diarios.sql     # Mart: desembolsos diarios agregados por segmento
    │   ├── 02_mart_recaudo_diario.sql          # Mart: recaudo diario consolidado
    │   ├── 03_vw_estado_cartera_cohorte.sql    # Vista: estado de cartera por cohorte de originación
    │   └── 04_vw_top_creditos_atraso.sql       # Vista: créditos con mayor número de días en mora
    └── 04-queries-negocio/                     # Consultas ad-hoc para preguntas de negocio
```




&nbsp;

---

## 3. Instalación

### Requisitos previos

- Python 3.11 o superior.
- Proyecto de GCP con la API de BigQuery habilitada.
- Permisos `BigQuery Data Editor` y `BigQuery Job User` sobre el proyecto de destino.
- (Opcional) Archivo JSON de cuenta de servicio con los permisos anteriores, si no se
  utilizan las credenciales de aplicación predeterminadas (ADC).

### Clonación del repositorio

```bash
git clone https://github.com/andresm-data/job-fintrust_pueba.git
cd job-fintrust_pueba
```

### Configuración del entorno virtual

```bash
python -m venv venv
source venv/bin/activate          # Linux / macOS
# venv\Scripts\activate           # Windows
```

### Instalación de dependencias

```bash
pip install --upgrade pip
pip install -r python/requirements.txt
```

### Variables de entorno

| Variable           | Obligatoria | Descripción                                                        |
|--------------------|-------------|-------------------------------------------------------------------|
| `GCP_PROJECT_ID`   | Sí          | Identificador del proyecto de GCP donde residen los datasets.     |
| `GCP_CREDENTIALS`  | No          | Ruta absoluta al archivo JSON de la cuenta de servicio. Si se omite, el cliente utiliza las credenciales de aplicación predeterminadas (ADC). |

```bash
export GCP_PROJECT_ID="proyecto-gcp"
export GCP_CREDENTIALS="/ruta/al/service_account.json"   # opcional
```

### Ejecución de los scripts SQL

Los scripts SQL deben ejecutarse en el orden numérico indicado por su prefijo,
primero la capa `01-raw/`, luego `02-staging/` y finalmente `03-analytics/`.
La ejecución puede realizarse desde la consola de BigQuery o mediante la herramienta
de línea de comandos `bq`:

```bash
bq query --use_legacy_sql=false < sql/01-raw/01_customers.sql
```




&nbsp;

---

## 4. Uso

### Ejecución del pipeline de validación con credenciales de aplicación predeterminadas (ADC)

El siguiente comando inicia el pipeline completo de validación. Se asume que las
credenciales de la sesión activa de `gcloud` poseen los permisos requeridos:

```bash
export GCP_PROJECT_ID="proyecto-gcp"
python python/main.py
```

### Ejecución con archivo de clave de cuenta de servicio

Cuando se requiere autenticación explícita mediante una cuenta de servicio, se
especifica la ruta al archivo JSON antes de invocar el módulo:

```bash
export GCP_PROJECT_ID="proyecto-gcp"
export GCP_CREDENTIALS="/ruta/al/service_account.json"
python python/main.py
```

### Interpretación de la salida

El pipeline emite registros estructurados en la salida estándar con el siguiente
esquema:

```
YYYY-MM-DD HH:MM:SS  INFO      Suite: stg_customers                       8/8 passed
YYYY-MM-DD HH:MM:SS  INFO        ✓  expect_column_values_to_not_be_null   col:customer_id
YYYY-MM-DD HH:MM:SS  WARNING     ✗  expect_column_values_to_be_in_set     col:segment
YYYY-MM-DD HH:MM:SS  WARNING         observed_value: {'Masivo'}
```

El proceso retorna el código de salida `0` si la totalidad de las validaciones
resulta exitosa, o `1` en caso de que al menos una expectativa o verificación
personalizada arroje una falla.
