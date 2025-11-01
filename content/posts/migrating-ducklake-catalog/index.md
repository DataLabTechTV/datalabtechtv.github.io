---
title: Migrating DuckLake Catalog From SQLite to PostgreSQL
description: Learn how to migrate your existing DuckLake catalog from SQLite to PostgreSQL, without losing any data, and see it in action in a production environment.
date: 2025-10-28T12:00:00+0100
categories: [Data Engineering, DevOps]
tags: [ducklake, duckdb, data-stack, data-catalog, data-migration, sqlite, postgres,  video]
---

## Summary

Learn how to migrate your existing DuckLake catalog from SQLite to PostgreSQL, without losing any data, and see it in action in a production environment.

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; max-width: 100%;">
	<iframe
		src="https://www.youtube.com/embed/r-iV5S8CHPQ?si=0bg7GAVhok9_sMBu"
		frameborder="0"
		allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
		referrerpolicy="strict-origin-when-cross-origin"
		allowfullscreen
		style="position: absolute; top: 0; left: 0; width: 100%; height: 100%;">
	></iframe>
</div>

## Migrating with `pgloader`

Since `pgloader` is able to read from SQLite, we used this as our migration tool. The whole process was also implemented as a `just` command called `migrate-lakehouse-catalog-all`. It consists of loading the required environment variables from the `.env`, file creating the required PostgreSQL schemas, running the `pgloader` migration, and fixing incorrect data types.

### Basic Migration Script

The following code fragment, extracted from the `just` command, shows the migration process for a single catalog (`stage`, `graphs`, etc.).

```bash
echo "Migrating {{catalog}} catalog from SQLite to PostgreSQL..."

psql_conn_str="postgresql://$PGUSER:$PGPASSWORD@$PGHOST:$PGPORT/$PGDATABASE"

psql -c "CREATE SCHEMA IF NOT EXISTS $psql_schema"
pgloader --set search_path="'$psql_schema'" $sqlite_db_path $psql_conn_str
PGOPTIONS="--search-path=$psql_schema" psql -f "{{migrate_lakehouse_fix_script}}"
```

We could have used a more elabore `*.load` command file for `pgloader`, but since there weren't too many settings, we just used the CLI args with the `--set` option to configure the Postgres `search_path` to point to our schema, which we created using `psql`, and we ran a SQL script to assign the correct data types to columns that match the expected data type for a DuckLake Postgres catalog.

### Data Type Fixing

The following table illustrates how the target data types for the catalog tables in DuckLake get implemented in practice using SQLite and PostgreSQL natively, and how `pgloader` converts the types from SQLite to PostgreSQL during migration. In fact for SQLite, we're looking at type names that map to [type affinities](https://www.sqlite.org/datatype3.html#determination_of_column_affinity) and then to a [storage class](https://www.sqlite.org/datatype3.html#storage_classes_and_datatypes)—`BIGINT` is stored as `INTEGER`, while `VARCHAR` is stored as `TEXT`. Let's focus on the two rightmost columns, which should exactly match each other after migration, but don't.

| Data Type     | SQLite    | PostgreSQL                | SQLite ▶ PostgreSQL |
| ------------- | --------- | ------------------------- | ------------------- |
| `BIGINT`      | `BIGINT`  | `BIGINT`                  | `BIGINT`            |
| `BOOLEAN`     | `BIGINT`  | `BOOLEAN`                 | `BIGINT`            |
| `TIMESTAMPTZ` | `VARCHAR` | `TIMESTAMP WITH TIMEZONE` | `TEXT`              |
| `UUID`        | `VARCHAR` | `UUID`                    | `TEXT`              |
| `VARCHAR`     | `VARCHAR` | `CHARACTER VARYING`       | `TEXT`              |

Perhaps if DuckLake took advantage of type names that matched the desired affinity or class, then `pgloader` could would have done a better job at migration. For example, using `BOOLEAN` in SQLite would have mapped to the `NUMERIC` affinity, which in turn would end up being stored as an `INTEGER`. For datetime types, unfortunately, there is no equivalent solution, as these can be stored in `TEXT`, `REAL`, or `INTEGER` classes, so only by looking at the value could we determine the type. Also, there is no `UUID` type in SQLite, which similarly means that the type could only be determined by looking at values.

Since we cannot define a direct cast using a `*.load` command file, because there is no direct mapping, the best way to assign the correct typing to the migrated tables is to run a custom SQL script that alters the column types for columns that should have been `BOOLEAN`, `TIMESTAMPTZ` or `UUID`. We'll leave `VARCHAR` untouched, as it is essentially the same as `TEXT`, and `BIGINT` was already correctly migrated.

#### Affected Columns

After going through the [Full Schema Creation Script](https://ducklake.select/docs/stable/specification/tables/overview#full-schema-creation-script) for DuckLake, we compiled a summary of the columns that need altering, covering 10 out of 22 catalog tables.

| Table                                   | Column             | Type          |
| --------------------------------------- | ------------------ | ------------- |
| `ducklake_snapshot`                     | `snapshot_time`    | `TIMESTAMPTZ` |
| `ducklake_schema`                       | `schema_uuid`      | `UUID`        |
|                                         | `path_is_relative` | `BOOLEAN`     |
| `ducklake_table`                        | `table_uuid`       | `UUID`        |
|                                         | `path_is_relative` | `BOOLEAN`     |
| `ducklake_view`                         | `view_uuid`        | `UUID`        |
| `ducklake_data_file`                    | `path_is_relative` | `BOOLEAN`     |
| `ducklake_file_column_stats`            | `path_is_relative` | `BOOLEAN`     |
| `ducklake_column`                       | `nulls_allowed`    | `BOOLEAN`     |
| `ducklake_table_column_stats`           | `contains_null`    | `BOOLEAN`     |
|                                         | `contains_nan`     | `BOOLEAN`     |
| `ducklake_files_scheduled_for_deletion` | `path_is_relative` | `BOOLEAN`     |
|                                         | `schedule_start`   | `BOOLEAN`     |
| `ducklake_name_mapping`                 | `is_partition`     | `BOOLEAN`     |

#### Altering Column Types

The SQL script we used to assign the correct data types was the following:

```sql
ALTER TABLE ducklake_snapshot
    ALTER COLUMN snapshot_time
        TYPE TIMESTAMPTZ
        USING snapshot_time::TIMESTAMPTZ;

ALTER TABLE ducklake_schema
    ALTER COLUMN schema_uuid
        TYPE UUID
        USING schema_uuid::UUID,
    ALTER COLUMN path_is_relative
        TYPE BOOLEAN
        USING path_is_relative::INTEGER = 1;

ALTER TABLE ducklake_table
    ALTER COLUMN table_uuid
        TYPE UUID
        USING table_uuid::UUID,
    ALTER COLUMN path_is_relative
        TYPE BOOLEAN
        USING path_is_relative::INTEGER = 1;

ALTER TABLE ducklake_view
    ALTER COLUMN view_uuid
        TYPE UUID
        USING view_uuid::UUID;

ALTER TABLE ducklake_data_file
    ALTER COLUMN path_is_relative
        TYPE BOOLEAN
        USING path_is_relative::INTEGER = 1;

ALTER TABLE ducklake_file_column_stats
    ALTER COLUMN contains_nan
        TYPE BOOLEAN
        USING contains_nan::INTEGER = 1;

ALTER TABLE ducklake_delete_file
    ALTER COLUMN path_is_relative
        TYPE BOOLEAN
        USING path_is_relative::INTEGER = 1;

ALTER TABLE ducklake_column
    ALTER COLUMN nulls_allowed
        TYPE BOOLEAN
        USING nulls_allowed::INTEGER = 1;

ALTER TABLE ducklake_table_column_stats
    ALTER COLUMN contains_null
        TYPE BOOLEAN
        USING contains_null::INTEGER = 1,
    ALTER COLUMN contains_nan
        TYPE BOOLEAN
        USING contains_nan::INTEGER = 1;

ALTER TABLE ducklake_files_scheduled_for_deletion
    ALTER COLUMN path_is_relative
        TYPE BOOLEAN
        USING path_is_relative::INTEGER = 1,
    ALTER COLUMN schedule_start
        TYPE TIMESTAMPTZ
        USING schedule_start::TIMESTAMPTZ;

ALTER TABLE ducklake_name_mapping
    ALTER COLUMN is_partition
        TYPE BOOLEAN
        USING is_partition::INTEGER = 1;
```

In essence, we're running the following conversions:

- `TEXT` to `TIMESTAMPTZ` – a simple cast was enough
- `BIGINT` to `BOOLEAN` – we cast to `INTEGER` (optional) and compare to `1`
- `TEXT` to `UUID` – a simple cast was also enough

## Changes to DataLab Code

### Environment Variables

Our configuration changed from a local SQLite file per catalog to a schema in a remote PostgreSQL database per catalog. As such, we had to revise our configurable environment variables.

We added the new catalog configuration variables:

```bash
PSQL_CATALOG_HOST=docker-shared
PSQL_CATALOG_PORT=5432
PSQL_CATALOG_DB=lakehouse
PSQL_CATALOG_USER=lakehouse
PSQL_CATALOG_PASSWORD=lakehouse
PSQL_CATALOG_STAGE_SCHEMA=stage
PSQL_CATALOG_SECURE_STAGE_SCHEMA=secure_stage
PSQL_CATALOG_GRAPH_MART_SCHEMA=graphs_mart
PSQL_CATALOG_ANALYTICS_MART_SCHEMA=analytics_mart
```

We kept the `ENGINE_DB`, since a local DuckDB will still exist for compute:

```bash
ENGINE_DB=engine.duckdb
```

But we deprecated the SQLite catalog variables:

```bash
STAGE_DB=stage.sqlite
SECURE_STAGE_DB=secure_stage.sqlite
GRAPHS_MART_DB=marts/graphs.sqlite
ANALYTICS_MART_DB=marts/analytics.sqlite
```

### Just Command for Migration

The deprecated variables above are still required during the migration process, but you can delete them after running:

```bash
just migrate-lakehouse-catalog-all
```

The previous command will call `just migrate-lakehouse-catalog <catalog>` for each catalog. The output per catalog will look something like this:

```
just migrate-lakehouse-catalog stage
just check pgloader
Checking pgloader... ok
just check psql
Checking psql... ok
Testing lakehouse catalog connection... ok
Migrating stage catalog from SQLite to PostgreSQL...
CREATE SCHEMA
2025-10-24T09:19:58.011998Z LOG pgloader version "3.6.10~devel"
2025-10-24T09:19:58.099988Z LOG Migrating from #<SQLITE-CONNECTION sqlite:///datalab/local/stage.sqlite {100528A183}>
2025-10-24T09:19:58.099988Z LOG Migrating into #<PGSQL-CONNECTION pgsql://lakehouse@docker-shared:5432/lakehouse {10053A6573}>
2025-10-24T09:19:58.715916Z LOG report summary reset
                           table name     errors       rows      bytes      total time
-------------------------------------  ---------  ---------  ---------  --------------
                                fetch          0          0                     0.000s
                      fetch meta data          0         27                     0.048s
                       Create Schemas          0          0                     0.000s
                     Create SQL Types          0          0                     0.008s
                        Create tables          0         44                     0.132s
                       Set Table OIDs          0         22                     0.008s
-------------------------------------  ---------  ---------  ---------  --------------
                    ducklake_metadata          0          4     0.1 kB          0.044s
                    ducklake_snapshot          0         18     0.7 kB          0.044s
            ducklake_snapshot_changes          0         18     1.0 kB          0.044s
                      ducklake_schema          0          5     0.3 kB          0.044s
                       ducklake_table          0         13     1.0 kB          0.072s
                        ducklake_view          0          0                     0.068s
                         ducklake_tag          0          0                     0.076s
                  ducklake_column_tag          0          0                     0.076s
           ducklake_file_column_stats          0         71     3.4 kB          0.112s
                   ducklake_data_file          0         13     1.4 kB          0.112s
                 ducklake_delete_file          0          0                     0.112s
                      ducklake_column          0         75     3.0 kB          0.116s
                 ducklake_table_stats          0         13     0.3 kB          0.140s
              ducklake_partition_info          0          0                     0.140s
          ducklake_table_column_stats          0         71     2.4 kB          0.140s
        ducklake_file_partition_value          0          0                     0.188s
         ducklake_inlined_data_tables          0          0                     0.192s
            ducklake_partition_column          0          0                     0.144s
                ducklake_name_mapping          0          0                     0.224s
ducklake_files_scheduled_for_deletion          0          0                     0.192s
              ducklake_column_mapping          0          0                     0.192s
             ducklake_schema_versions          0         18     0.1 kB          0.224s
-------------------------------------  ---------  ---------  ---------  --------------
              COPY Threads Completion          0          4                     0.232s
                       Create Indexes          0          5                     0.016s
               Index Build Completion          0          5                     0.012s
                      Reset Sequences          0          0                     0.048s
                         Primary Keys          0          5                     0.012s
                  Create Foreign Keys          0          0                     0.000s
                      Create Triggers          0          0                     0.000s
                     Install Comments          0          0                     0.000s
-------------------------------------  ---------  ---------  ---------  --------------
                    Total import time          ✓        319    13.7 kB          0.320s
ALTER TABLE
ALTER TABLE
ALTER TABLE
ALTER TABLE
ALTER TABLE
ALTER TABLE
ALTER TABLE
ALTER TABLE
ALTER TABLE
ALTER TABLE
ALTER TABLE
```

### Refactoring for a PSQL Catalog

The files affected by the migration were the following:

```
.env.example           | 12 ++++++++++++
dlctl/cli.py           |  4 ++--
dlctl/dbt_handler.py   |  8 --------
justfile               |  5 +----
shared/settings.py     | 12 ++++--------
shared/templates.py    | 33 ++++++++++++++++++++++++++++-----
shared/tools.py        | 25 ++++++++++++++++++-------
transform/profiles.yml | 30 +++++++++++++++++++++++-------
```

The majority of the changes were related to using the new environment variables, but the most relevant ones were regarding the DuckLake configuration, affecting both `shared/templates.py` and `transform/profiles.yml`.

#### Template for `init.sql`

For `shared/templates.py`, we replaced the SQLite extension install with:

```sql
INSTALL postgres;
```

We added a PostgreSQL secret:

```sql
CREATE OR REPLACE SECRET postgres (
	TYPE postgres,
	HOST '$psql_host',
	PORT $psql_port,
	DATABASE $psql_db,
	USER '$psql_user',
	PASSWORD '$psql_password'
);
```

And a DuckLake secret, to simplify attachment:

```sql
CREATE OR REPLACE SECRET (
	TYPE ducklake,
	METADATA_PATH '',
	METADATA_PARAMETERS MAP {
		'TYPE': 'postgres',
		'SECRET': 'postgres'
	}
);
```

We replaced the attachment statements with a PostgreSQL catalog config based on the previous default secret (unnamed), using `METADATA_SCHEMA` to point to each separate catalog schema, within the `lakehouse` database:

```sql
ATTACH 'ducklake:' AS $psql_schema (
	METADATA_SCHEMA '$psql_schema',
	DATA_PATH 's3://$s3_bucket/$s3_prefix'
);
```

#### Updating dbt Profiles

We then reproduced the same configuration as previously in `transform/profiles.yml`:

```yaml
transform:
  outputs:
    lakehouse:
      type: duckdb
      path: "{{ env_var('LOCAL_DIR') }}/{{ env_var('ENGINE_DB') }}"
      extensions:
        - httpfs
        - parquet
        - ducklake
        - postgres
      secrets:
        - type: s3
          name: minio
          region: "{{ env_var('S3_REGION') }}"
          key_id: "{{ env_var('S3_ACCESS_KEY_ID') }}"
          secret: "{{ env_var('S3_SECRET_ACCESS_KEY') }}"
          endpoint: "{{ env_var('S3_ENDPOINT') }}"
          use_ssl: "{{ env_var('S3_USE_SSL') }}"
          url_style: "{{ env_var('S3_URL_STYLE') }}"
        - type: postgres
          name: postgres
          host: "{{ env_var('PSQL_CATALOG_HOST') }}"
          port: "{{ env_var('PSQL_CATALOG_PORT') }}"
          database: "{{ env_var('PSQL_CATALOG_DB') }}"
          user: "{{ env_var('PSQL_CATALOG_USER') }}"
          password: "{{ env_var('PSQL_CATALOG_PASSWORD') }}"
        - type: ducklake
          name: ""
          metadata_path: ""
          metadata_parameters:
            type: postgres
            secret: postgres
      attach:
        - path: "ducklake:"
          alias: stage
          options:
            metadata_schema: stage
            data_path: s3://{{ env_var('S3_BUCKET') }}/{{ env_var('S3_STAGE_PREFIX') }}
        - path: "ducklake:"
          alias: secure_stage
          options:
            metadata_schema: secure_stage
            data_path: s3://{{ env_var('S3_BUCKET') }}/{{ env_var('S3_SECURE_STAGE_PREFIX') }}
            encrypted: 1
        - path: "ducklake:"
          alias: graphs
          options:
            metadata_schema: graphs
            data_path: >
              s3://{{ env_var('S3_BUCKET') }}/{{ env_var('S3_GRAPHS_MART_PREFIX') }}
        - path: "ducklake:"
          alias: analytics
          options:
            metadata_schema: analytics
            data_path: >
              s3://{{ env_var('S3_BUCKET') }}/{{ env_var('S3_ANALYTICS_MART_PREFIX') }}
  target: lakehouse
```

Notice that we added the `name` attribute to each secrets entry, which we didn't use previously. This is mostly due to `metadata_parameters` pointing to a named `postgres` `secret`. In reality, only the Postgres secret required the `name` attribute, but we added this to all secrets for consistency.

####  Updating Backup Tool

Finally, we also updated our backup tool to run `pg_dump` instead of simply copying local SQLite files to a backup bucket in our object store.

Our file structure changed from:

```
s3://lakehouse/
└── backups/
    └── catalog/
        ├── YYYY_MM_DD/
        │   └── HH_mm_SS_sss/
        │       ├── engine.duckdb
        │       ├── stage.sqlite
        │       └── marts/*.sqlite
        └── manifest.json
```

To:

```
s3://lakehouse/
└── backups/
    └── catalog/
        ├── YYYY_MM_DD/
        │   └── HH_mm_SS_sss/
        │       └── lakehouse.dump
        └── manifest.json
```

So now, running the following commands will backup and restore `lakehouse.dump` files:

```bash
dlctl backup create
dlctl backup restore
```

In a production scenario, we might also want to consider a backup and/or migration workflow for our `lakehouse` bucket, as the catalog is pointless without the DuckLake parquet files. For now, however, the data lab infra we're running only provides a single object store endpoint, and our buckets all live in the same instance, which makes it pointless to backup on top of this.

For now, if you're migrating to new infrastructure, simply download your `lakehouse` bucket to an intermediate location and restore it back to the new bucket. You'll then be able to restore the PostgreSQL catalog backup from the new bucket.

## Updating ML Server Deployment

Now that our data stack is completely running on the [[Architecture Design|data lab infra]], we can update the `apps` docker compose project for our `mlserver` service, so that it connects to the PostgreSQL catalog and the MinIO storage.

Next you can see the environment variables that we added to `infra/apps/docker/compose.yml`, besides the already existing `MLFLOW_TRACKING_URI` and `KAFKA_BROKER_ENDPOINT`:

```yaml
services:
  mlserver:
    build:
      context: ../../../
      dockerfile: infra/apps/docker/mlserver/Dockerfile
    ports:
      - "8000:8000"
    environment:
      MLFLOW_TRACKING_URI: ${MLFLOW_TRACKING_URI}
      KAFKA_BROKER_ENDPOINT: ${KAFKA_BROKER_ENDPOINT}

      S3_ENDPOINT: ${S3_ENDPOINT}
      S3_USE_SSL: ${S3_USE_SSL}
      S3_URL_STYLE: ${S3_URL_STYLE}
      S3_ACCESS_KEY_ID: ${S3_ACCESS_KEY_ID}
      S3_SECRET_ACCESS_KEY: ${S3_SECRET_ACCESS_KEY}
      S3_REGION: ${S3_REGION}

      S3_BUCKET: ${S3_BUCKET}
      S3_STAGE_PREFIX: ${S3_STAGE_PREFIX}
      S3_SECURE_STAGE_PREFIX: ${S3_SECURE_STAGE_PREFIX}
      S3_GRAPHS_MART_PREFIX: ${S3_GRAPHS_MART_PREFIX}
      S3_ANALYTICS_MART_PREFIX: ${S3_ANALYTICS_MART_PREFIX}
      S3_EXPORTS_PREFIX: ${S3_EXPORTS_PREFIX}
      S3_BACKUPS_PREFIX: ${S3_BACKUPS_PREFIX}

      PSQL_CATALOG_HOST: ${PSQL_CATALOG_HOST}
      PSQL_CATALOG_PORT: ${PSQL_CATALOG_PORT}
      PSQL_CATALOG_DB: ${PSQL_CATALOG_DB}
      PSQL_CATALOG_USER: ${PSQL_CATALOG_USER}
      PSQL_CATALOG_PASSWORD: ${PSQL_CATALOG_PASSWORD}
      PSQL_CATALOG_STAGE_SCHEMA: ${PSQL_CATALOG_STAGE_SCHEMA}
      PSQL_CATALOG_SECURE_STAGE_SCHEMA: ${PSQL_CATALOG_SECURE_STAGE_SCHEMA}
      PSQL_CATALOG_GRAPHS_MART_SCHEMA: ${PSQL_CATALOG_GRAPHS_MART_SCHEMA}
      PSQL_CATALOG_ANALYTICS_MART_SCHEMA: ${PSQL_CATALOG_ANALYTICS_MART_SCHEMA}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 10s
      retries: 5
    restart: unless-stopped
```

We also had to re-run `terraform apply` for `infra/services/gitlab`, so that the CI/CD variables were updated with the new `.env` configs.

Once this was done, we simply committed and pushed to GitLab with `git push infra`, as described in [[Layer 3 - Services]], which redeployed the docker compose project.
