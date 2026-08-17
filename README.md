# Data Migration from MySQL to Snowflake with Full CI/CD Pipeline

A complete **end-to-end data engineering portfolio project** demonstrating how to build a production-grade ELT pipeline that migrates the **Olist Brazilian e-commerce dataset** from a MySQL source (Aiven cloud) into a Snowflake data warehouse, using a **dbt medallion architecture** (Bronze → Silver → Gold), orchestrated on **AWS** via Step Functions, ECS Fargate, and Lambda — all deployed through a **GitHub Actions CI/CD pipeline**.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture & Data Flow](#architecture--data-flow)
- [Infrastructure Components](#infrastructure-components)
- [Data Pipeline Details](#data-pipeline-details)
- [CI/CD Pipeline](#cicd-pipeline)
- [Local Development Setup](#local-development-setup)
- [Deployment Guide](#deployment-guide)
- [Testing](#testing)
- [Security Considerations](#security-considerations)
- [Project Structure](#project-structure)

---

## Project Overview

### What This Project Demonstrates

| Capability | Implementation |
|---|---|
| **Extract** | Incremental MySQL ingestion with keyset and watermark strategies |
| **Load** | Snowflake COPY INTO via external S3 stage + stored procedures |
| **Transform** | dbt medallion architecture (Bronze → Silver → Gold) with tests |
| **Orchestrate** | AWS Step Functions chaining ECS Fargate + Lambda |
| **Deploy** | GitHub Actions CI/CD → ECR → ECS/Lambda |

### Tech Stack

| Category | Tools |
|---|---|
| **Source Database** | MySQL 8.x (Aiven managed) |
| **Cloud Storage** | Amazon S3 |
| **Data Warehouse** | Snowflake |
| **Transformation** | dbt Core + dbt-snowflake |
| **Orchestration** | AWS Step Functions |
| **Compute** | AWS ECS Fargate, AWS Lambda |
| **Container Registry** | Amazon ECR |
| **CI/CD** | GitHub Actions |
| **Language** | Python 3.11 |
| **Linting** | Ruff |
| **Testing** | Pytest |
| **Dependency Management** | uv (lockfile) |

---

## Architecture & Data Flow

### High-Level Architecture

```
┌──────────────┐      ┌──────────────────┐      ┌──────────────┐
│   MySQL      │      │   ECS Fargate    │      │   Amazon S3  │
│   (Aiven)    │─────▶│   Ingestion      │─────▶│   Raw JSON   │
│   Source DB  │      │   Container      │      │   Files      │
└──────────────┘      └──────────────────┘      └──────┬───────┘
                                                        │
                          ┌─────────────────────────────┘
                          ▼
                   ┌─────────────────┐      ┌──────────────────────┐
                   │  AWS Lambda     │─────▶│  Snowflake RAW       │
                   │  Snowflake      │      │  Schema (COPY INTO)  │
                   │  Loader         │      │                      │
                   └─────────────────┘      └──────────┬───────────┘
                                                        │
                          ┌─────────────────────────────┘
                          ▼
                   ┌─────────────────┐      ┌──────────────────────┐
                   │  ECS Fargate    │─────▶│  Snowflake           │
                   │  dbt Container  │      │  BRONZE → SILVER →   │
                   │                 │      │  GOLD Schemas        │
                   └─────────────────┘      └──────────────────────┘
                          │
                          ▼
                   ┌─────────────────┐
                   │  AWS Step       │
                   │  Functions      │
                   │  Orchestrator   │
                   └─────────────────┘
```

### Pipeline Stages

1. **Extract** — `MySQL_Connector.py` runs on ECS Fargate, paginates through 9 MySQL tables using keyset or column-based watermark strategies, writes date-partitioned JSON files to S3, and tracks incremental state in `pipeline-state/watermark_state.json`.

2. **Load** — Step Functions invokes the `olist-snowflake-loader` Lambda, which calls the Snowflake stored procedure `load_all_tables()`. This runs `COPY INTO` from the S3 external stage (via Snowflake Storage Integration) into the 9 raw tables.

3. **Transform** — Step Functions launches the `olist-dbt-task` ECS Fargate task, which runs `dbt run` against the Snowflake warehouse, materializing models through the three medallion layers.

4. **Orchestrate** — AWS Step Functions chains all three stages with error handling, exit code checks, and SNS failure alerts.

---

## Infrastructure Components

### AWS Resources

| Resource | Name / ID | Purpose |
|---|---|---|
| **ECS Cluster** | `olist-cluster` | Runs Fargate tasks |
| **ECS Task Definition** | `olist-ingestion-task` | Ingestion container |
| **ECS Task Definition** | `olist-dbt-task` | dbt container |
| **Lambda Function** | `olist-snowflake-loader` | Triggers Snowflake stored proc |
| **ECR Repository** | `<account-id>.dkr.ecr.<region>.amazonaws.com` | Container image storage |
| **Step Functions** | `Olist pipeline: ingestion → Snowflake load → dbt` | Orchestrates the full pipeline |
| **SNS Topic** | `olist-alerts` | Pipeline failure notifications |

### Snowflake Objects

Created via `SnowFlake/settingup_snowflake.sql`:

| Object | Name | Purpose |
|---|---|---|
| **Database** | `olist_dw` | Data warehouse database |
| **Schema** | `raw` | Raw landing zone |
| **Schema** | `bronze` | Cleaned, typed models |
| **Schema** | `silver` | Conformed, tested models |
| **Schema** | `gold` | Dimensional model (star schema) |
| **Storage Integration** | `s3_olist_integration` | Secure S3 → Snowflake link (IAM role-based, no keys) |
| **File Format** | `json_format` | JSON parser (`STRIP_OUTER_ARRAY = TRUE`) |
| **External Stage** | `olist_raw_stage` | Points to `s3://olist-raw-datasets/ecommerce-dataset/` |
| **Stored Procedure** | `load_today(target_table)` | Date-partitioned `COPY INTO` for a single table |
| **Stored Procedure** | `load_all_tables()` | Loops all 9 tables calling `load_today` |
| **Task** | `daily_load_all` | Scheduled CRON `0 6 * * * UTC` (fallback load) |

### 9 Olist Tables

| # | Table Name | Ingestion Strategy |
|---|---|---|
| 1 | `raw_olist_customers` | Keyset (composite PK) |
| 2 | `raw_olist_orders` | Keyset (composite PK) |
| 3 | `raw_olist_order_items` | Keyset (composite PK) |
| 4 | `raw_olist_sellers` | Keyset (composite PK) |
| 5 | `raw_olist_products` | Keyset (composite PK) |
| 6 | `raw_olist_geolocation` | Column-based watermark |
| 7 | `raw_olist_product_category_translation` | Column-based watermark |
| 8 | `raw_olist_order_payments` | Column-based watermark |
| 9 | `raw_olist_order_reviews` | Column-based watermark |

---

## Data Pipeline Details

### 1. Ingestion — `Ingestion/MySQL_Connector.py`

**What it does:** Connects to the MySQL source (Aiven), extracts data from 9 tables in incremental batches, and writes JSON files to S3.

**Key design decisions:**

- **Two pagination strategies** are used based on table structure:
  - **Keyset pagination** — For tables with composite primary keys. Uses `WHERE (keys) > (last_keys) ORDER BY keys LIMIT 5000` for efficient traversal without offset drift.
  - **Column-based watermark** — For tables with a single monotonically increasing column (e.g., `review_id`, `payment_sequential`). Uses `WHERE column > last_value ORDER BY column LIMIT 5000`.

- **Watermark state** is persisted to S3 at `pipeline-state/watermark_state.json`, enabling resumable ingestion. On restart, the connector picks up from where it left off.

- **Date-partitioned output** — JSON files are written to `ecommerce-dataset/<table>/YYYY/MM/DD/<table>_batchNNNNN_<timestamp>.json`, with each row stamped with `_ingested_at`.

- **Batch size** — 5,000 rows per batch, with empty-batch detection to stop iteration.

**Dependencies:** `boto3`, `mysql-connector-python`, `python-dotenv`

---

### 2. Snowflake Loader — `Lambda/snowflake_loader.py`

**What it does:** A Lambda function (container image-based) triggered by Step Functions. It:
1. Retrieves Snowflake credentials from **AWS Secrets Manager** via the `SNOWFLAKE_SECRET_ARN` environment variable
2. Connects to Snowflake
3. Calls `CALL olist_dw.raw.load_all_tables()`
4. Returns the result to Step Functions

This is the bridge between the S3 raw JSON files and the Snowflake raw schema. The stored procedure dynamically builds `COPY INTO` statements using the date-partitioned S3 paths that the ingestion script writes to.

**Dependencies:** `boto3`, `snowflake-connector-python`

---

### 3. dbt Transformation — `dbt_olist_data_model/`

The transformation layer uses **dbt** with a **medallion architecture** (Bronze → Silver → Gold), where all models are **incremental** and driven by the `_ingested_at` timestamp.

#### Bronze Layer (`models/bronze/`)

- **Purpose:** Type-casted, null-coalesced copies of raw tables
- **Materialization:** Incremental
- **Models:** `br_olist_customers`, `br_olist_orders`, `br_olist_order_items`, `br_olist_order_payments`, `br_olist_order_reviews`, `br_olist_products`, `br_olist_sellers`, `br_olist_geolocation`, `br_olist_product_category_translation`
- **Key logic:** Casts timestamps via `try_to_timestamp_ntz`, null-coalesces strings, filters by `_ingested_at > max(ingested_at)` for incremental processing
- **Source declaration:** `Source.yml` declares `raw_olist` source pointing to `olist_dw.raw`

#### Silver Layer (`models/silver/`)

- **Purpose:** Cleansed, conformed, business-ready models with data quality tests
- **Materialization:** Incremental
- **Models:** `slv_orders`, `slv_order_items`, `slv_customers`, `slv_order_payments`, `slv_order_reviews`, `slv_sellers`, `slv_products`, `slv_geolocation`
- **Key logic:** Normalizes `order_status`, derives flags (`is_delivered`, `is_late`, `has_comment`), computes `delivery_days`, trims whitespace, applies `initcap`/`upper` normalization, replaces nulls with `'Unknown'`
- **Data tests** (defined in `schema.yml`):
  - `unique` + `not_null` on primary keys
  - `relationships` tests for referential integrity (e.g., `order_items.order_id → orders.order_id`)

#### Gold Layer (`models/gold/`)

- **Purpose:** Dimensional model (star schema) for analytics
- **Materialization:** Incremental with `merge` strategy
- **Dimension tables:** `dim_customers`, `dim_sellers`, `dim_products`, `dim_reviews`, `dim_payments`, `dim_geolocation`
- **Fact tables:** `fct_orders`, `fct_order_items`
- **Key design:**
  - Surrogate keys via `md5(<id>) as <entity>_sk`
  - `fct_orders` aggregates items, payments, and reviews per order with `customer_sk`
  - `fct_order_items` joins items with orders, carrying `customer_sk`, `product_sk`, `seller_sk`

#### dbt Configuration

- **Profile:** `dbt_olist_data_model` (defined in `profiles.yml`)
- **Target:** `prod` (Snowflake)
- **Connection:** All parameters via `env_var()` — no hardcoded credentials
- **Schemas:** `bronze`, `silver`, `gold` (one per layer)
- **Threads:** 1 (sequential model execution)
- **Custom macro:** `generate_schema_name.sql` — uses the model's custom schema if set, otherwise falls back to the target schema

---

## CI/CD Pipeline

### GitHub Actions Workflow — `.github/workflows/CICD_Pipeline.yml`

**Triggers:** Push and Pull Request to `main` branch

**Jobs (4 total, with dependencies):**

```
┌─────────────────────┐
│  1. unit-tests      │
│  (Lint + Pytest)    │
└─────────┬───────────┘
          │
          ├────────────────────────────────────────┐
          ▼                                        ▼
┌─────────────────────┐                ┌─────────────────────────────┐
│  2. docker-build-   │                │  4. build-and-deploy-       │
│  smoke-test-and-push│                │  snowflake-loader           │
│  (Ingestion + dbt)  │                │  (Lambda container image)   │
└─────────┬───────────┘                └─────────────────────────────┘
          │
          ▼
┌─────────────────────┐
│  3. update-ecs-     │
│  task-definitions   │
└─────────────────────┘
```

### Job Details

#### Job 1: `unit-tests`
- **Runner:** `ubuntu-latest`
- **Steps:**
  1. Checkout code
  2. Set up Python 3.11
  3. Install `pytest`, `ruff`, and `Ingestion/requirements.txt`
  4. Run `ruff check Ingestion/` (lint)
  5. Run `pytest Test/ -v` (unit tests)

#### Job 2: `docker-build-smoke-test-and-push`
- **Depends on:** `unit-tests`
- **Steps:**
  1. Configure AWS credentials (from GitHub Secrets)
  2. Login to Amazon ECR
  3. Build `olist-ingestion` Docker image (tagged with commit SHA)
  4. Build `olist-dbt` Docker image (tagged with commit SHA)
  5. Smoke test both images (`docker run --rm <image> --version`)
  6. Push both images to ECR

#### Job 3: `update-ecs-task-definitions`
- **Depends on:** `docker-build-smoke-test-and-push`
- **Steps:**
  1. Download current ECS task definitions (`olist-ingestion-task`, `olist-dbt-task`)
  2. Use `jq` to update the container image URI to the new SHA-tagged image
  3. Strip read-only fields (`taskDefinitionArn`, `revision`, `status`, etc.)
  4. Register new task definition revisions

#### Job 4: `build-and-deploy-snowflake-loader`
- **Depends on:** `unit-tests` (runs in parallel with jobs 2+3)
- **Steps:**
  1. Build `olist-snowflake-loader` image (`--platform linux/amd64 --provenance=false`)
  2. Push to ECR
  3. Update Lambda function code via `aws lambda update-function-code`
  4. Wait for Lambda update to complete

### GitHub Secrets Required

| Secret Name | Purpose |
|---|---|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key |
| `AWS_REGION` | AWS region (e.g., `eu-west-1`) |
| `AWS_ACCOUNT_ID` | AWS account ID |

---

## Local Development Setup

### Prerequisites

- Python 3.11
- Docker (for container builds)
- AWS CLI configured with appropriate credentials
- Snowflake account with appropriate permissions
- MySQL database (or Aiven cloud instance)
- uv (recommended) or pip for dependency management

### 1. Clone the Repository

```bash
git clone https://github.com/<your-username>/Data-Migration-from-MySQL-Database-to-Migration-with-Full-CI-CD-Pipeline.git
cd Data-Migration-from-MySQL-Database-to-Migration-with-Full-CI-CD-Pipeline
```

### 2. Set Up Python Environment

```bash
# Using uv (recommended)
uv sync

# Or using pip
python -m venv .venv
source .venv/Scripts/activate   # Windows: .venv\Scripts\activate
pip install -r Ingestion/requirements.txt
pip install pytest ruff dbt-core dbt-snowflake
```

### 3. Configure Environment Variables

Create a `.env` file in the project root:

```env
# MySQL (Aiven)
MYSQL_HOST=<your-mysql-host>
MYSQL_USER=<your-mysql-user>
MYSQL_PASSWORD=<your-mysql-password>

# S3
S3_BUCKET_NAME=olist-raw-datasets

# Snowflake
SNOWFLAKE_ACCOUNT=<your-snowflake-account>
SNOWFLAKE_USER=<your-snowflake-user>
SNOWFLAKE_PASSWORD=<your-snowflake-password>
SNOWFLAKE_ROLE=<your-snowflake-role>
SNOWFLAKE_DATABASE=olist_dw
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
```

> **Note:** The `.env` file is git-ignored and must never be committed.

### 4. Run Locally

```bash
# Run ingestion script directly
python Ingestion/MySQL_Connector.py

# Run dbt models
cd dbt_olist_data_model
dbt run

# Run dbt tests
dbt test
```

### 5. Build Docker Images Locally

```bash
# Ingestion image
docker build -f Docker/Dockerfile.ingestion -t olist-ingestion .

# dbt image
docker build -f Docker/Dockerfile.dbt -t olist-dbt .

# Snowflake loader image (Lambda)
docker build -f Docker/Dockerfile.snowflake-loader -t olist-snowflake-loader .
```

---

## Deployment Guide

### Step 1: Provision Snowflake Infrastructure

Run the Snowflake setup script to create all required objects:

```sql
-- Execute in Snowflake as ACCOUNTADMIN or a role with sufficient privileges
-- File: SnowFlake/settingup_snowflake.sql
```

This creates:
- Database `olist_dw` with `raw`, `bronze`, `silver`, `gold` schemas
- Storage Integration `s3_olist_integration` (requires an IAM role)
- External Stage `olist_raw_stage`
- JSON File Format `json_format`
- 9 raw tables
- Stored Procedures `load_today()` and `load_all_tables()`
- Scheduled Task `daily_load_all`

### Step 2: Create the S3 → Snowflake IAM Role

Create an IAM role in AWS that Snowflake's Storage Integration can assume:

1. Create an IAM role with a trust policy for Snowflake
2. Attach a policy allowing `s3:GetObject` and `s3:listBucket` on `s3://olist-raw-datasets/`
3. Update the ARN in `settingup_snowflake.sql` before running

### Step 3: Set Up AWS Secrets Manager

Store the Snowflake credentials in AWS Secrets Manager:

```bash
aws secretsmanager create-secret \
  --name olist/snowflake-credentials \
  --secret-string '{
    "SNOWFLAKE_ACCOUNT": "<your-account>",
    "SNOWFLAKE_USER": "<your-user>",
    "SNOWFLAKE_PASSWORD": "<your-password>",
    "SNOWFLAKE_ROLE": "<your-role>",
    "SNOWFLAKE_WAREHOUSE": "<your-warehouse>"
  }'
```

Note the secret ARN — set it as the `SNOWFLAKE_SECRET_ARN` environment variable on the Lambda function.

### Step 4: Push Docker Images to ECR

```bash
# Login to ECR
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com

# Build and push each image
docker build -f Docker/Dockerfile.ingestion -t olist-ingestion .
docker tag olist-ingestion:latest <account-id>.dkr.ecr.<region>.amazonaws.com/olist-ingestion:<tag>
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/olist-ingestion:<tag>

# Repeat for olist-dbt and olist-snowflake-loader
```

### Step 5: Create ECS Task Definitions

Create two ECS Fargate task definitions:
- `olist-ingestion-task` — runs the `olist-ingestion` container
- `olist-dbt-task` — runs the `olist-dbt` container

Both should use Fargate launch type with appropriate CPU/memory and network configuration.

### Step 6: Create the Lambda Function

Create the `olist-snowflake-loader` Lambda function:
- **Runtime:** Container image
- **Image:** Pushed `olist-snowflake-loader` from ECR
- **Environment variable:** `SNOWFLAKE_SECRET_ARN` = ARN from Step 3
- **IAM Role:** Must have permission to read from Secrets Manager

### Step 7: Deploy the Step Functions State Machine

Import `Orchestration/aws_step_function_script.json` into AWS Step Functions:

1. Open the AWS Step Functions console
2. Create a new state machine
3. Import the JSON definition
4. Replace the placeholder values:
   - `subnet-REPLACE-ME` → your actual subnet ID
   - `sg-REPLACE-ME` → your actual security group ID
5. Ensure the Step Functions IAM role has permissions for:
   - `ecs:RunTask` (for Fargate tasks)
   - `lambda:InvokeFunction` (for the Lambda)
   - `sns:Publish` (for alerts)
6. Deploy the state machine

---

## Testing

### Unit Tests — `Test/test_mysql_connector.py`

Comprehensive unit tests for the ingestion script using `unittest.mock` to mock AWS S3 and MySQL connections.

**Test coverage:**

| Test Area | What's Tested |
|---|---|
| `json_default` serialization | `date`, `datetime`, `Decimal`, `bytes`, unsupported types |
| `load_watermarks` | Missing key (returns `{}`), existing key (roundtrip), error handling |
| `save_watermarks` | S3 upload with correct key |
| `upload_batch` | `_ingested_at` stamping, correct S3 key format, empty batch skip |
| `ingest_column_strategy` | Column-based pagination, short batch termination, no rows scenario |
| `ingest_keyset_strategy` | Composite key pagination, watermark advancement |

### Running Tests

```bash
# Run all tests
pytest Test/ -v

# Run with coverage (if pytest-cov is installed)
pytest Test/ -v --cov=Ingestion --cov-report=term-missing
```

### Linting

```bash
# Lint the Ingestion code with Ruff
ruff check Ingestion/
```

The `ruff` configuration in `pyproject.toml` ignores `DTZ003` (missing timezone in datetime usage).

---

## Security Considerations

### Credentials Handling

| Component | Method | Notes |
|---|---|---|
| **GitHub Actions** | Repository Secrets | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, etc. |
| **Lambda (Snowflake)** | AWS Secrets Manager | Credentials fetched at runtime via `SNOWFLAKE_SECRET_ARN` |
| **dbt Profile** | Environment Variables | `profiles.yml` uses `env_var()` — no hardcoded secrets |
| **Local Development** | `.env` file | Git-ignored; **never commit** |

### Security Best Practices Implemented

- **Secrets Manager** for Lambda — Snowflake credentials are never stored in the container image or environment variables in plaintext
- **Storage Integration** — Snowflake connects to S3 via IAM role assumption (no access keys)
- **GitHub Secrets** — AWS credentials are stored as encrypted repository secrets
- **`.gitignore`** — Prevents `.env`, `.venv/`, `__pycache__/`, `.dbt/` from being committed

### Security Recommendations

- **Rotate credentials** if `.env` was ever committed to git history
- **Move ingestion MySQL credentials** to AWS Secrets Manager (currently in `.env`)
- **Use VPC endpoints** for S3 and Secrets Manager traffic
- **Enable CloudTrail** for audit logging of all API calls
- **Review IAM policies** regularly and apply least-privilege principle

---

## Project Structure

```
.
├── .github/
│   └── workflows/
│       └── CICD_Pipeline.yml          # GitHub Actions CI/CD pipeline
│
├── dbt_olist_data_model/              # dbt project
│   ├── dbt_project.yml                # dbt project configuration
│   ├── profiles.yml                   # dbt connection profile (Snowflake)
│   ├── models/
│   │   ├── bronze/                    # Layer 1: Type-casted raw tables
│   │   │   ├── Source.yml             # Source declarations
│   │   │   ├── br_olist_customers.sql
│   │   │   ├── br_olist_orders.sql
│   │   │   ├── br_olist_order_items.sql
│   │   │   ├── br_olist_order_payments.sql
│   │   │   ├── br_olist_order_reviews.sql
│   │   │   ├── br_olist_products.sql
│   │   │   ├── br_olist_sellers.sql
│   │   │   ├── br_olist_geolocation.sql
│   │   │   └── br_olist_product_category_translation.sql
│   │   ├── silver/                    # Layer 2: Cleansed, tested models
│   │   │   ├── schema.yml            # Data quality tests
│   │   │   ├── slv_orders.sql
│   │   │   ├── slv_order_items.sql
│   │   │   ├── slv_customers.sql
│   │   │   ├── slv_order_payments.sql
│   │   │   ├── slv_order_reviews.sql
│   │   │   ├── slv_sellers.sql
│   │   │   ├── slv_products.sql
│   │   │   └── slv_geolocation.sql
│   │   └── gold/                     # Layer 3: Star schema
│   │       ├── dim_customers.sql
│   │       ├── dim_sellers.sql
│   │       ├── dim_products.sql
│   │       ├── dim_reviews.sql
│   │       ├── dim_payments.sql
│   │       ├── dim_geolocation.sql
│   │       ├── fct_orders.sql
│   │       └── fct_order_items.sql
│   ├── macros/
│   │   └── generate_schema_name.sql  # Custom schema name macro
│   ├── seeds/                         # Seed data (if any)
│   ├── snapshots/                     # SCD snapshots (if any)
│   └── tests/                         # dbt tests
│
├── Docker/
│   ├── Dockerfile.ingestion           # Container for MySQL → S3 ingestion
│   ├── Dockerfile.dbt                 # Container for dbt run
│   └── Dockerfile.snowflake-loader    # Lambda container for Snowflake load
│
├── Ingestion/
│   ├── MySQL_Connector.py             # Source extraction script
│   └── requirements.txt               # boto3, mysql-connector-python, python-dotenv
│
├── Lambda/
│   ├── snowflake_loader.py            # Lambda handler (calls Snowflake stored proc)
│   └── requirements.txt               # boto3, snowflake-connector-python
│
├── Orchestration/
│   └── aws_step_function_script.json  # AWS Step Functions state machine definition
│
├── SnowFlake/
│   └── settingup_snowflake.sql        # Snowflake infrastructure (DDL + stored procs)
│
├── Test/
│   └── test_mysql_connector.py        # Unit tests for ingestion script
│
├── .env                               # Local environment variables (git-ignored)
├── .gitignore                         # Git ignore rules
├── .python-version                    # Python 3.11
├── profiles.yml                       # dbt profile (project root)
├── pyproject.toml                     # Python project config (deps, ruff, pytest)
├── uv.lock                            # uv dependency lockfile
└── README.md                          # This file
```

---

## Orchestration Flow

The AWS Step Functions state machine executes the following sequence:

```
┌─────────────────────┐
│  RunIngestionTask   │  ECS Fargate: olist-ingestion-task
│  (ecs:runTask.sync) │  Extracts MySQL → S3
└─────────┬───────────┘
          │ exit code == 0?
          ▼
┌─────────────────────┐     ┌─────────────────┐
│  CheckIngestion-    │ No  │  Ingestion-     │
│  ExitCode           │────▶│  Failed (SNS)   │
└─────────┬───────────┘     └─────────────────┘
          │ Yes
          ▼
┌─────────────────────┐
│  RunSnowflakeLoad   │  Lambda: olist-snowflake-loader
│  (lambda:invoke)    │  Calls COPY INTO stored proc
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐     ┌─────────────────┐
│  RunDbtTask         │ No  │  DbtFailed      │
│  (ecs:runTask.sync) │────▶│  (SNS)          │
│  Runs dbt run       │     └─────────────────┘
└─────────┬───────────┘
          │ Yes
          ▼
┌─────────────────────┐
│  PipelineSucceeded  │  (optional SNS notification)
└─────────────────────┘
```

**Error Handling:** Each stage includes a `Catch` block that publishes a failure message to the `olist-alerts` SNS topic before transitioning to a terminal `Fail` state.

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes
4. Run tests (`pytest Test/ -v`) and linting (`ruff check Ingestion/`)
5. Commit with a descriptive message
6. Push and open a Pull Request against `main`

---

## License

This project is for educational and portfolio purposes.

---

**Built by [Iyke](https://github.com/iyke34)** — Data Engineering Portfolio Project
