---
title: PostgreSQL Maximalism
description: Learn about PostgreSQL's extensions for all use cases.
date: 2025-05-27T12:00:00+0100
draft: false
categories: ["Data Engineering"]
tags: ["databases", "postgres", "extensions", "unedited", "video", "series", "research-notes"]
---

## Summary

Unedited research notes for my "PostgreSQL Maximalism" series. This is likely more than enough information, if you're looking into extending Postgres for your storage and querying needs. For an easier-to-digest, follow-up version, check the video series. For your convenience, each extension category is properly annotated in the videos as chapters.

<iframe width="560" height="315" src="https://www.youtube.com/embed/N36OlwP8U_I" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## Research

### Document Store

- [Built-In Key-Value Support](https://www.postgresql.org/docs/current/hstore.html)
- [Built-In XML Support](https://www.postgresql.org/docs/16/functions-xml.html)
- [Built-In JSON Support](https://www.postgresql.org/docs/current/functions-json.html)
	- Native types and functions for writing and reading JSON data.
- [pg_jsonschema](https://github.com/supabase/pg_jsonschema)
	- Adds JSON schema validation functions for robustness.

### Column Store and Analytics

- [pg_mooncake](https://github.com/Mooncake-Labs/pg_mooncake)
	- "Postgres-Native Data Warehouse"
	- Provides column stores in PostgreSQL (Iceberg, Delta Lake).
	- Uses DuckDB to query.
	- Unlike `pg_duckdb` and `pg_analytics`, `pg_mooncake` can write out data to Iceberg or Delta Lake formats via transactional `INSERT`/`UPDATE`/`DELETE`.
- [pg_duckdb](https://github.com/duckdb/pg_duckdb)
	- Developed by [Hydra](https://docs.hydra.so/overview) and [MotherDuck](https://motherduck.com/docs/getting-started/).
	- MotherDuck integration.
	- Maybe this will replace `pg_mooncake` when DuckDB extends integration with Iceberg or Delta Lake.
- [pg_analytics](https://github.com/paradedb/pg_analytics)
	- Part of [ParadeDB](https://www.paradedb.com/).
	- Based on [DuckDB](https://duckdb.org/docs/stable/).
	- Recently archived and deprecated in favor of `pg_search`.
- [pg_lakehouse](https://www.paradedb.com/blog/introducing_lakehouse)
	- Precursor to `pg_analytics.`
	- Based on [Apache DataFusion](https://datafusion.apache.org/).
	- Used to be a part of the ParadeDB codebase.
- [columnar](https://github.com/hydradatabase/columnar)
	- Developed by Hydra.
	- Also used in `pg_timeseries`.

### Time Series Store and Real-Time

- [timescaledb](https://github.com/timescale/timescaledb)
	- A solution by Timescale.
	- Provides a lot more functions to handle time series than `pg_timeseries`.
	- Low latency makes it adequate for real-time analytics.
	- Supports incremental views through [continuous aggregates](https://docs.timescale.com/use-timescale/latest/continuous-aggregates/).
	- Has some overlap with `pg_mooncake`, but can't write to Iceberg or Delta Lake, using them directly as the storage layer.
	- Supports [tiered storage](https://docs.timescale.com/use-timescale/latest/data-tiering/)
- [pg_timeseries](https://github.com/tembo-io/pg_timeseries)
	- A solution by Tembo.
	- "The Timescale License would restrict our use of features such as compression, incremental materialized views, and bottomless storage."
	- Supports [incremental materialized views](https://tembo.io/docs/product/stacks/analytical/timeseries#using-incremental-views).

### Vector Store

- [pgvector](https://github.com/pgvector/pgvector)
	- Vector database.
	- Approximate indexing
		- HNSW: [Hierarchical Navigable Small World](https://en.wikipedia.org/wiki/Hierarchical_navigable_small_world)
		- IVFFlat: Inverted File Flat
	- Supported by GCP Cloud SQL and AWS RDS.
	- How does it compare to `pg_search`?
- [pgvectorscale](https://github.com/timescale/pgvectorscale/)
	- A solution by Timescale.
	- Learns from Microsoft's [DiskANN](https://github.com/microsoft/DiskANN):
		- "Graph-structured Indices for Scalable, Fast, Fresh and Filtered Approximate Nearest Neighbor Search"
	- Efficiency layer over `pgvector` via:
		- StreamingDiskANN indexing approach
		- Statistical Binary Quantization
		- Label-based filtered vector search

### Artificial Intelligence

- [pgai](https://github.com/timescale/pgai)
	- A solution by Timescale.
	- "A suite of tools to develop RAG, semantic search, and other AI applications"
	- Takes advantage of `pgvectorscale` for improved performance.
	- Features
		- Loading datasets from Hugging Face.
		- Computing vector embeddings.
		- Chunking text.
		- Semantic search or RAG via OpenAI, Ollama, or Cohere.
- [pg_vectorize](https://github.com/tembo-io/pg_vectorize)
	- A solution by Tembo (powers their VectorDB stack).
	- Similar to `pgai`, supporting RAG and semantic search, but relies directly on `pgvector`.
	- Supports Hugging Face's Sentence-Transformers as well as OpenAI's embeddings.
	- Supports direct interaction with LLMs.
- [pgrag](https://github.com/neondatabase-labs/pgrag)
	- Rust-based, experimental solution by Neon.
	- Complete pipeline support from text extraction (PDF, DOCX) to chat completion based on ChatGPT's API.
	- Support for [bge-small-en-v1.5](https://huggingface.co/BAAI/bge-small-en-v1.5) or OpenAI's embeddings.
	- Distance computation and ranking based on `pgvector`.
	- Reranking based on [jina-reranker-v1-tiny-en](https://huggingface.co/jinaai/jina-reranker-v1-tiny-en) also available.

### Full-Text Search

- [Built-In Full-Text Search Support](https://www.postgresql.org/docs/16/functions-textsearch.html)
	- Generalized Inverted Index (GIN).
	-  `tsvector` and `tsquery` data types.
	- Text preprocessing pipeline configurations usable by `to_tsvector` and `to_tsquery`.
	- The `english` configuration runs the following operations:
		- Tokenize text by spaces and punctuation;
		- Convert to lower case;
		- Remove stop words;
		- Apply Porter stemmer.
	- Example ranking/scoring functions  `ts_rank` and `ts_rank_cd`.
- [ParadeDB](https://github.com/paradedb/paradedb)
	- Search and Analytics.
		- Search
			- `pg_search` (ParadeDB's rust-based version)
				- Previously named `pg_bm25`.
				- This is huge and it takes a long long time to compile!
				- Adds a ton of Lucene-like features, based on [Tantivy](https://github.com/quickwit-oss/tantivy), a Rust-based Lucene alternative.
				- Still doesn't provide a text-based query parser.
		- Analytics
			- `pg_analytics`
				- This has been deprecated, due to refocus on `pg_search`, even for analytics.
	- Part of [ParadeDB](https://www.paradedb.com/).
- [pg_trgm](https://www.postgresql.org/docs/current/pgtrgm.html)
	- Built-in extension.
	- Character-based trigrams.
	- Useful for fuzzy search based on string similarity (e.g., product name matching).
	- Can be optimized via GIN and GiST indexes.
- [pg_fuzzystrmatch](https://www.postgresql.org/docs/current/fuzzystrmatch.html)
	- Built-in extension.
	- Provides functions to match and measure similar-sounding strings.
- [pg_similarity](https://github.com/eulerto/pg_similarity)
	- Text similarity functions.
	- Supported by GCP Cloud SQL and AWS RDS.
	- Last commit over 5 years ago.
	- Has forks to fix compilation with the latest versions of PostgreSQL.

### Graph Store

- [pgrouting](https://docs.pgrouting.org/latest/en/index.html)
	- Extension of PostGIS
	- Graph algorithms
- [AgensGraph](https://github.com/skaiworldwide-oss/agensgraph)
	- PostgreSQL fork, not an extension.
	- If it doesn't integrate, why use this instead of a more specialized graph database, like Neo4j?
	- Architecture diagram shows that it has its own separate graph storage layer.
	- Query language
		- SQL (ANSI)
		- Cypher ([openCypher](https://opencypher.org/))
	- [Visualization](https://github.com/skaiworldwide-oss/AgensGraphViewer)
- [age](https://github.com/apache/age)
	- Extension inspired by AgensGraph.
	- Query language
		- ANSI SQL
		- Cypher ([openCypher](https://opencypher.org/))
		- No Gremlin support ([yet](https://github.com/apache/age/issues/431))
	- [Visualization](https://github.com/apache/age-viewer)
	- No graph algorithms.
- [pggraph](https://github.com/raitraidma/pggraph)
	- SQL implementations of Dijkstra and Kruskal.
	- DOA (Dead On Arrival), this has been abandoned for 9 years.

### Message Queue

- [pgmq](https://github.com/tembo-io/pgmq)
	- A solution by Tembo.
	- Type: extension.
	- Official libraries for Rust and Python.
	- Community libraries for Dart, Go, Elixir, Java, Kotlin, JavaScript, TypeScript, .NET.
	- Actively maintained.
- [pgq](https://github.com/pgq/pgq)
	- A solution by Skype and a part of SkyTools.
	- Type: extension.
	- Official library for Python (last released for Python 3.8).
	- Still maintained, but no meaningful changes over the last two years.
	- [Documentation](https://pgq.github.io/extension/pgq/files/external-sql.html)
- [pg_message_queue](https://github.com/rpdelaney/pg-message-queue)
	- Type: extension.
	- Abandoned for over 8 years.
- [pgqueuer](https://pgqueuer.readthedocs.io/)
	- Type: Python library.
	- Needs to be setup via `pgq install`, which creates required tables and indexes.
- [pg-boss](https://github.com/timgit/pg-boss)
	- Type: JavaScript library.
	- Setup is done in-code, by creating the queue.
- [queue_classic](https://github.com/QueueClassic/queue_classic)
	- Type: Ruby library.
	- Postgres connection is setup via an environment variable.

## Description

### Documents

Document formats, like JSON, XML, or YAML, model hierarchical data that follow a tree-like structure.

This kind of data is frequently stored in document databases like MongoDB (BSON), or simply using a key-value store, like RocksDB, where the value can only be deserialized and used in-code.

Postgres natively supports JSON via its `json` and `jsonb` data types, as well as XML via its `xml` data type. It also supports key-value storage via the `hstore` extension, which is available by default. While the `xml` data type supports XML validation via the `xmlschema_valid` function, for JSON there is an extension called `pg_jsonschema` that adds support for validation based on a JSON Schema.

### Analytics and Time Series

Transactional and analytics operations have different requirements. By default, Postgres is row-oriented, which is ideal for transactions (e.g., updating a user profile), but for analytics it's usually more efficient to rely on column-oriented storage (e.g., averaging movie ratings, per age group). In this context, partitioning data is often a requirement as well, as to reduce complexity thus increasing performance.

On the data engineering community, formats like Apache Iceberg or Delta Lake, which add a metadata layer on top of Apache Parquet, are becoming a requirement for data lakehouse architectures. This layer tracks snapshots (data versioning), schema structure, partition information, and parquet file locations.

Another trend in the DE community is DuckDB, an in-process column-oriented database.  Built for analytics, DuckDB is able to support medium scale data science tasks on a single laptop, and that's why we love it! Think of it as a counterpart to SQLite, which is a well-liked row-oriented in-process database.

Column-oriented and analytics has been brought to Postgres via extensions like `pg_mooncake`, `pg_duckdb`, or `pg_analytics`.

There are also time series specific extensions that support real time and analytics by providing additional features, like incremental views, or functions like `time_bucket_gapfill` (add missing dates), or `locf` and `interpolate` to fill-in missing values.

Time series specific extensions include the well-known `timeseriesdb`, or the more recent `pg_timeseries`.

### Vectors and AI

One of the fundamental requirements of vector stores is that they provide efficient vector similarity calculations. This is usually achieved through specialized indexing that supports approximated similarity computations.

Extensions like the well-known `pgvector`, or its complement `pgvectorscale`, both support querying nearest-neighbors, on `pgvector` via HNSW and IVFFlat indexes, and on `pgvectorscale` via a StreamDiskANN index. Nearest-neighbors can be computed based on multiple distance functions, such as Euclidean/L2, cosine, or Jaccard.

Regardless of whether AI operations belongs in the database, extensions to facilitate text embedding and LLM integration still exist, integrating with `pgvector`.

AI extensions include `pgai` and `pg_vectorize`, both supporting direct LLM querying, text embedding, and RAG and similarity search. In both extensions, text embedding is made possible either based on Hugging Face models, by querying OpenAI's embedding API, or via Ollama's API, which also powers the direct access to LLMs and RAG features. There is also `pgrag`, a more recent, experimental extension focused on delivering a complete pipeline for RAG, being the only one that supports text extraction from PDF or DOCX files, as well as a specialized reranking model to help improve the outcome before generating the text completion.

All this is made possible by accessing Python APIs under the hood, via PL/Python. While these features can be convenient at times, I tend to think that they do not belong in the database, but rather on its own Python codebase. The database should be exclusively concerned with storage and retrieval, so, unless there are performance reasons that justify integrating complex data processing features with the database, I believe this should be avoided. An example of this is `pgvector` and `pgvectorscale`, where indexing approaches were required to efficiently solve the vector distance computations — and indexing belongs in the database.

### Search

#### Built-In

##### Full-Text Search

PostgreSQL provides basic full-text search features out-of-the-box with its Generalized Inverted Index (GIN), `tsvector` and `tsquery` data types, and corresponding functions and operators (e.g., `@@` for matching a `tsvector` with a `tsquery`, or `||` for concatenating `tsvector`), supporting negation (`!!`), conjunction (`&&`), disjunction (`||`), and phrase queries (`<->`). Documents and queries can be parsed using `to_tsvector` or `to_tsquery`, which default to the `english` configuration — tokenizes text by spaces and punctuation, normalizes to lower case, removes stop words, and applies Porter stemmer.

Since PostgreSQL 11, there is the `websearch_to_tsquery` function, which gives us the ability to parse keyword queries directly, like we do on Google or with Apache Lucene, however there are differences.

For example, parsing the following keyword query:

```
"data science" "state of the art" algorithms models
```

Would result in the PostgreSQL equivalent:

```SQL
'data' <-> 'scienc' & 'state' <3> 'art'
    & 'algorithm' & 'model'
```

Which is essentially a conjunction (AND) of the two phrases and the two terms, along with stemming and stop word handling.

However, search engines commonly default to disjunction (OR). Since results are often ranked, search engines just push results with a less and less matched tokens to the end of the results list.

We can rank the matched documents, either by using `ts_rank`, which is based on term frequency and proximity, or by using `ts_rank_cd`, which factors in cover density ranking (i.e., query term distance in the document). However, in order to retrieve documents that only partially match the query, we'd need to manually parse the query:

```sql
phraseto_tsquery('data science')
	|| phraseto_tsquery('state of the art')
	|| to_tsquery('algorithm | model')
```

Which is query-dependent and require us to build a query parser to handle this outside of SQL. If we do that, we can rank our documents by creating the GIN index:

```sql
CREATE INDEX idx_doc_fulltext ON doc
USING GIN (to_tsvector('english', content));
```

And using the following query:

```sql
WITH search AS (
    SELECT
        id,
        content,
        to_tsvector('english', content) AS d,
        phraseto_tsquery('data science')
			|| phraseto_tsquery('state of the art')
			|| to_tsquery('algorithm | model') AS q
    FROM
        doc
)
SELECT ts_rank(d, q) AS score, id, content
FROM search
WHERE d @@ q
ORDER BY score DESC;
```

Note that Postgres uses the designation "rank" to refer to the score. For example, in the docs, when describing the weights for `to_tsrank`, they use phrases like "2 divides the rank by the document length", where "rank" is really the returned score (no ranks are returned by `ts_rank` or `ts_rank_cd`).

Also note that these functions do not return the raw score, so the following won't be equivalent:

```sql
ts_rank(d, q, 2)
ts_rank(d, q) / length(d)
```

#####  Fuzzy String Matching

By default, Postgres also provides two extensions called `pg_trgm` and `fuzzystrmatch`. The first uses character-based trigrams to provide fuzzy string matching and compute string similarity. The second provides functions to match and measure similar-sounding strings.

#### Extensions

There are other third-party extensions to compute string similarity, like `pg_similarity`, which provides several distance functions like L1/Manhattan, L2/Euclidean or Levenshtein, and other less commonly used methods like Monge-Elkan, Needleman-Wunsch or Smith-Waterman-Gotoh. While frequently offered in cloud services, including GCP and AWS, this extension appears to be unmaintained and incompatible with the latest versions of Postgres (forks exist to make it compilable).

Finally, there is a fairly large and mature project, called ParadeDB, which provides a `pg_search` extension. Since the built-in support for full-text search on Postgres only provides two example ranking functions, the `pg_search` extension, initially called `pg_bm25`, was created to bring the BM25 ranking function to Postgres. It has since matured quite a lot, providing innumerous features supported by a new `bm25` index. This index provides configurable segment sizes, as well as a separate text preprocessing configuration that can be set per field during indexing. A new operator `@@@` is also introduced for matching, and field-based queries and boosting are supported. Several useful functions are provided to for checking term existence, fuzzy matching, range filtering, set matching, or phrase matching. JSON can also be indexed and queried, and "more like this" queries are also supported. Similarity search is supported via the `pgvector` extension.

### Graphs

This category is where Postgres does not shine. While graph storage can be done directly by creating a table for nodes and for relationships, this does not scale for real-world graph querying, particularly for demanding graph algorithms. A graph database usually relies on index-free adjacency to ensure efficiency, which is not supported by Postgres. The alternative is to index the ID columns of the relationships table, which means that complex graph queries, that require long walks or traversals, will need to query an index for each step it takes, without considering caching. For large graphs, this is highly inefficient. As far as I know, there is no Postgres extension that solves this problem at this moment.

Alternatives for graph storage include AgensGraph, which is a Postgres fork rather than an extension, as well as Apache AGE (A Graph Extension), which was inspired by AgensGraph. Both support ANSI SQL as well as openCypher for querying, with AGE having an [open issue](https://github.com/apache/age/issues/431) on GitHub to implement Apache Gremlin support as well. AgensGraph has limited support for graph algorithms, while AGE has none at all, rather providing user defined functions. An project called `pggraph` implemented the Dijkstra and Kruskal graph algorithms using pure SQL, but has since been abandoned — it didn't provide any specialized storage, but rather just functions to apply to your own relationships table via a SQL query parameter.

Finally, perhaps the most interesting extension we can use for graph algorithms is `pgrouting`, which is built on top of `postgis`, as it is designed to add network analysis support for geospatial routing. While this still does not provide a custom storage layer for graphs, with index-free adjacency, it does provide a wide range of graph algorithms.

### Message Queues

Message queueing software implements the producer-consumer pattern (one-to-one) and usually supports the publish-subscribe pattern as well (one-to-many / topics / events). Well-known software in this category includes Redis, ZeroMQ, RabbitMQ, or Apache Kafka, all of which provide interface libraries for several different languages — this is a requirement for message-oriented middleware, as different components are often written in different languages.

While any of the previous options are likely more efficient than a Postgres-based implementation, for simple use cases there are a few extensions and libraries that implement message queues on top of Postgres. There is `pgmq`, from Tembo, the same authors of `pg_timeseries` and `pg_vectorize`. This integrates with over 10 languages via official (Rust and Python) and community libraries, providing a `create` queue function, as well as `send` and `read` functions, alongside other utilities, to support the producer-consumer pattern. For the publish-subscribe pattern, we only found the `pgq` extension from Skype, which similarly provides a `create_queue` function, as well as `insert_event`,  `register_consumer` and `get_batch_events` functions.

All other extensions and libraries we found only implement the producer-consumer pattern. There is `pg_message_queue` which is an extension that  provides functions `pg_mq_create_queue`, `pg_mq_send_message`, and `pg_mq_get_msg_bin` (bytes) or `pg_mq_get_msg_text` (plain text) — it also supports `LISTEN` for asynchronous notifications. There are also libraries supported on Postgres to help handle job queues: `pgqueuer` for Python, `pg-boss` for JavaScript, and `queue_classic`, `que`, `good_job` or `delayed_job` for Ruby.

## Comparison

PGDG - PostgreSQL Global Development Group

### Documents

**Alternatives to:** [RocksDB](https://rocksdb.org/), [eXist-db](https://exist-db.org/exist/apps/homepage/index.html), [MongoDB](https://www.mongodb.com/)

|     | Extension                                                              | Author   | Created     | Description                           |
| --- | ---------------------------------------------------------------------- | -------- | ----------- | ------------------------------------- |
| 🔴  | [hstore](https://www.postgresql.org/docs/16/hstore.html)               | PGDG     | 2008        | Bundled key-value type and functions. |
| 🔴  | [xml](https://www.postgresql.org/docs/16/functions-xml.html)           | PGDG     | 2008        | Native XML type and functions.        |
| 🟢  | [json / jsonb](https://www.postgresql.org/docs/16/functions-json.html) | PGDG     | 2012 / 2014 | Native JSON types and functions.      |
| 🟢  | [pg_jsonschema](https://github.com/supabase/pg_jsonschema/)            | Supabase | 2022        | JSON schema validation.               |

### Analytics and Time Series

**Alternatives to:** [DuckDB](https://duckdb.org/), [Apache Cassandra](https://cassandra.apache.org/), [Amazon RedShift](https://aws.amazon.com/redshift/), [Google BigQuery](https://cloud.google.com/bigquery), [Snowflake](https://www.snowflake.com/), [InfluxDB](https://www.influxdata.com/), [Prometheus](https://prometheus.io/), [Amazon Timestream](https://aws.amazon.com/timestream/)

|     | Extension                                                                   | Author             | Created | Description                                                                                                                                                                                                                                       |
| --- | --------------------------------------------------------------------------- | ------------------ | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 🟢  | [pg_mooncake](https://pgmooncake.com/docs/quick-start)                      | Mooncake Labs      | 2024    | Column store based on Iceberg or Delta Lake, that transparently uses DuckDB vectorization for analytics queries, but also lets us extract Iceberg or Delta Lake for processing externally (e.g., using `polars` or `duckdb`).                     |
| 🔴  | [pg_duckdb](https://github.com/duckdb/pg_duckdb/tree/main/docs)             | Hydra & MotherDuck | 2024    | Official extension for DuckDB that integrates with MotherDuck and cloud storage (e.g., AWS S3, Google GCS).                                                                                                                                       |
| 🔴  | [pg_analytics](https://github.com/paradedb/pg_analytics/)                   | ParadeDB           | 2024    | Similar to `pg_duckdb`. Added support for DuckDB as part of ParadeDB, but it was discontinued in favor of integrating analytics directly into `pg_search` instead.                                                                                |
| 🔴  | [pg_lakehouse](https://www.paradedb.com/blog/introducing_lakehouse)         | ParadeDB           | 2024    | Added support for Apache DataFusion to ParadeDB, but it was deprecated in favor of `pg_analytics` and a DuckDB backend.                                                                                                                           |
| 🟡  | [columnar](https://columnar.docs.hydra.so/)                                 | Hydra              | 2022    | Columnar storage engine at the core of Hydra, a data warehouse replacement built on top of PostgreSQL.                                                                                                                                            |
| 🟢  | [timescaledb](https://docs.timescale.com/)                                  | Timescale          | 2017    | Well-known time series storage solution based on the hypertable, a temporally partitioned table. Adequate for real-time solutions due to its low latency and incremental materialized views. Provides a wide range of useful analytics functions. |
| 🔴  | [pg_timeseries](https://tembo.io/docs/product/stacks/analytical/timeseries) | Tembo              | 2024    | Similar to `timescaledb`, but extremely lacking in analytics functions. Built to compete with the limiting Timescale License.                                                                                                                     |

### Vectors and AI

**Alternatives to:** [Pinecone](https://www.pinecone.io/), [Weaviate](https://weaviate.io/), [Milvus](https://milvus.io/), [Azure AI Search](https://azure.microsoft.com/en-us/products/ai-services/ai-search)

|     | Extension                                                              | Author             | Created | Description                                                                                                                                                                                                                                                                                                                                                                |
| --- | ---------------------------------------------------------------------- | ------------------ | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 🟢  | [pgvector](https://github.com/pgvector/pgvector/blob/master/README.md) | Andrew Kane et al. | 2021    | Provides a `vector` type, as well as several similarity functions that power kNN. Efficiency is reached by implementing the [HNSW](https://en.wikipedia.org/wiki/Hierarchical_navigable_small_world) and [IVFFlat](https://docs.oracle.com/en/database/oracle/oracle-database/23/vecse/understand-inverted-file-flat-vector-indexes.html) approximate indexing strategies. |
| 🔴  | [pg_vectorscale](https://github.com/timescale/pgvectorscale/)          | Timescale          | 2023    | Extends `pgvector` with the StreamingDiskANN index (inspired by Microsoft's DiskANN), and adds Statistical Binary Quantization for compression, and label-based filtered vector search for vector operations with added filtering over categories.                                                                                                                         |
| 🟢  | [pgai](https://docs.timescale.com/ai/latest/)                          | Timescale          | 2024    | Relies on `pg_vectorscale` to provide semantic search, RAG via OpenAI, Ollama or Cohere, text chunking, computing text embeddings, or loading Hugging Face datasets.                                                                                                                                                                                                       |
| 🔴  | [pg_vectorize](https://tembo.io/pg_vectorize/)                         | Tembo              | 2023    | Similar to `pgai`, but relies directly on `pgvector` to provide semantic search, and RAG via Hugging Face's Sentence-Transformers, OpenAI's embeddings or Ollama. It also supports direct interactions with LLMs.                                                                                                                                                          |
| 🔴  | [pgrag](https://github.com/neondatabase-labs/pgrag)                    | Neon               | 2024    | Focused on providing a complete RAG pipeline, provides text extraction from PDF or DOCX, as well as support for reranking via [jinaai/jina-reranker-v1-tiny-en](https://huggingface.co/jinaai/jina-reranker-v1-tiny-en). Embeddings are either based on [BAAI/bge-small-en-v1.5](https://huggingface.co/BAAI/bge-small-en-v1.5) or OpenAI, and it only supports ChatGPT for generation. |

### Search

**Alternatives to:** [Elasticsearch](https://www.elastic.co/elasticsearch), [Apache Solr](https://solr.apache.org/)

|     | Extension                                                                          | Author               | Created | Description                                                                                                                                                                                                                                                                                                                                                                                                                            |
| --- | ---------------------------------------------------------------------------------- | -------------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 🟢  | [tsvector / tsquery](https://www.postgresql.org/docs/16/functions-textsearch.html) | PGDG                 | 2008    | Native text preprocessing, document/query vector representation and matching, basic ranking functions, and GIN index to support efficient full-text search.                                                                                                                                                                                                                                                                            |
| 🟢  | [pg_search](https://docs.paradedb.com/documentation/overview)                      | ParadeDB             | 2023    | Historically introduced as `pg_bm25`, as it focused on bringing BM25 into Postgres, it now also provides several Lucene-like features, supported on [Tantivy](https://github.com/quickwit-oss/tantivy), a Rust-based Lucene alternative. It also provides its own `bm25` index with several text preprocessing settings (e.g. support for n-grams). It supports field-based and range queries, as well as set filtering, and boosting. |
| 🟢  | [pg_trgm](https://www.postgresql.org/docs/current/pgtrgm.html)                     | PGDG                 | 2011    | Bundled character-based trigram matching, useful for string similarity and autocompletion.                                                                                                                                                                                                                                                                                                                                             |
| 🔴  | [fuzzystrmatch](https://www.postgresql.org/docs/16/fuzzystrmatch.html)             | PGDG                 | 2005    | Bundled string similarity functions, with support for matching similar-sounding names via Daitch-Mokotoff Soundex.                                                                                                                                                                                                                                                                                                                     |
| 🔴  | [pg_similarity](https://github.com/eulerto/pg_similarity)                          | Euler Taveira et al. | 2011    | Large collection of text-similarity functions, like L1/Manhattan, L2/Euclidean or Levenshtein, and other less known approaches  like Monge-Elkan, Needleman-Wunsch or Smith-Waterman-Gotoh.                                                                                                                                                                                                                                            |

### Graphs

**Alternatives to:** [Neo4j](https://neo4j.com/), [OrientDB](https://github.com/orientechnologies), [KuzuDB](https://kuzudb.com/)

|     | Extension                                                                    | Author              | Created | Description                                                                                                                                                                                                                                                                                     |
| --- | ---------------------------------------------------------------------------- | ------------------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 🟢  | [pgrouting](https://docs.pgrouting.org/latest/en/index.html)                 | pgRouting community | 2010    | Built on top of `postgis`, it was designed to add network analysis support for geospatial routing. Despite its focus, this is likely the most complete graph extension for Postgres, supporting multiple graph algorithms, although none of the state-of-the-art approaches (e.g., embeddings). |
| 🔴  | [AgensGraph](https://www.skaiworldwide.com/en-US/resources?filterKey=manual) | SKAI Worldwide      | 2016    | Technically a Postgres fork, supporting ANSI SQL and openCypher, with few graph algorithms.                                                                                                                                                                                                     |
| 🔴  | [age](https://age.apache.org/age-manual/master/index.html)                   | Apache              | 2020    | Apache AGE (A Graph Extension) supports ANSI SQL and openCypher, and might come to support [Apache Gremlin](https://github.com/apache/age/issues/431). Unfortunately, no graph algorithms are provided.                                                                                         |
| 🔴  | [pggraph](https://github.com/raitraidma/pggraph)                             | Rait Raidma         | 2016    | Meant as a collection of graph algorithms for Postgres, it only implemented Dijkstra and Kruskal, but the project has been abandoned.                                                                                                                                                           |

### Message  Queues

**Alternatives to:** [Redis](https://redis.io/) ([Queue](https://redis.io/glossary/redis-queue/), [Pub/Sub](https://redis.io/docs/latest/develop/interact/pubsub/)), [ZeroMQ](https://zeromq.org/), [RabbitMQ](https://www.rabbitmq.com/), [Apache Kafka](https://kafka.apache.org/), [Amazon Simple Queue Service](https://aws.amazon.com/sqs/), [Google Cloud Pub/Sub](https://cloud.google.com/pubsub)

**Two main categories:** producer-consumer (one-to-one), and publish-subscribe (one-to-many, event-driven).

Libraries are focused on job queues and support scheduling as well.

|     | Extension                                                         | Author                    | Created | Description                                                                                                                                                                                                                                                                                                                                                                                                                |
| --- | ----------------------------------------------------------------- | ------------------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 🟢  | [pgmq](https://pgmq.github.io/pgmq/)                              | Tembo                     | 2023    | Provides a `create` queue function, as well as `send` and `read` functions, alongside other utilities, to support the producer-consumer pattern. Integrates with over 10 languages via official (Rust and Python) and community libraries.                                                                                                                                                                                 |
| 🔴  | [pgq](https://github.com/pgq/pgq)                                 | Skype                     | 2016    | Provides a `create_queue` function, as well as `insert_event`,  `register_consumer` and `get_batch_events` functions. It supports the publish-subscribe pattern.                                                                                                                                                                                                                                                           |
| 🔴  | [pg_message_queue](https://github.com/rpdelaney/pg-message-queue) | Chris Travers             | 2013    | Provided the functions `pg_mq_create_queue`, `pg_mq_send_message`, and `pg_mq_get_msg_bin` (bytes) or `pg_mq_get_msg_text` (plain text), and also supported  `LISTEN` for asynchronous notifications. Originally published via an SVN repository and later migrated to Google Code, the code by the original creator is no longer available or maintained. While a fork exists on GitHub,  the project has been abandoned. |
| 🔴  | [pgqueuer](https://pgqueuer.readthedocs.io/en/latest/index.html)  | Jan Bjørge Løvland et al. | 2024    | Python library (`pgqueuer`) and CLI tool (`pgq`) that relies on `asyncpg` instead of `psycopg2` (like `pgmq`). It can be configured using default Postgres environment variables, but there is no default env var to set the connection string. Queues are managed programmatically and via the CLI and only one queue exists per database, stored in the `pgqueuer_jobs` table.                                           |
| 🔴  | [pg-boss](https://github.com/timgit/pg-boss)                      | Tim Jones et al.          | 2016    | Node.js library that provides the `PgBoss` object, instantiated with a connection string. This creates the `pgboss` schema where the queues are named and managed.                                                                                                                                                                                                                                                         |
| 🔴  | [delayed_job](https://github.com/collectiveidea/delayed_job)      | Shopify                   | 2008    | Ruby library extracted from Shopify. It supports Active Job and it is not specific to Postgres. It provides multiple features to handle diverse tasks at Shopify and one of the features is named queues. Not the best option for a general purpose message queue library on top of Postgres.                                                                                                                              |
| 🔴  | [que](https://github.com/que-rb/que)                              | Chris Hanks et al.        | 2013    | Ruby library that focuses on reliability and performance, taking advantage of PostgreSQL's advisory locks, which are application-specific locks that can be set at session-level or transaction-level. These fail immediately when locked instead of blocking like row-level locks do, so workers can try another job.                                                                                                     |
| 🔴  | [good_job](https://github.com/bensheldon/good_job)                | Ben Sheldon et al.        | 2020    | Ruby library. Inspired by `delayed_job` and `que`, it also uses advisory locks, but provides Active Job and Rails support.                                                                                                                                                                                                                                                                                                 |
| 🔴  | [queue_classic](https://github.com/QueueClassic/queue_classic)    | Ryan Smith et al.         | 2011    | Ruby library specialized in concurrent locking and supporting multiple queues and workers that can handle any of those named queues.                                                                                                                                                                                                                                                                                       |

## Bits

- Before PostgreSQL there was Postgres, which didn't support SQL but an implementation of QUEL (POSTQUEL). QUEL was inspired by relational algebra and created as a part of the Ingres Database.
- [pgcli](https://www.pgcli.com/) is a useful `pgsql` alternative that adds syntax highlighting, autocompletion, multiline editing, and external editor support.
- [Harlequin](https://harlequin.sh/) is a SQL IDE for the command line, supporting DuckDB natively, but also SQLite, PostgreSQL, or MariaDB, via plugins.
		- It can be installed via `uv` by running: `uv tool install harlequin[postgres]`
		- Create a Postgres profile via: `uvx harlequin --config`
		- And then connect using: `uvx harlequin --profile <profile>`
		- If it's the default profile, you can just run: `uvx harlequin`
- [WhoDB](https://whodb.com/) is as web client with support for PostgreSQL, MongoDB, Redis, SQLite, etc. that can be deployed as a docker image and connect to our `postgresql-maximalism` via `host.docker.internal`. It also supports conversational querying via an Ollama supported LLM — must have Ollama installed, along with the required models, and run `ollama serve`.
- When looking for Postgres extensions, there are two registries we can search:
	- [PGXN](https://pgxn.org/), the PostgreSQL eXtension Network.
		- `pgxn` can be installed using `pip install pgxnclient`.
		- Install extension: `pgxn install pgmq`
		- Load extension: `pgxn load -d dbname pgmq`
	- [Trunk](https://pgt.dev/), a Postgres extension registry.
		- `trunk` can be installed using `cargo install pg-trunk`.
		- Install extension: `trunk install pgmq` will install the `pgmq` extension.
		- Load extension: `psql -d dbname -c "CREATE EXTENSION pgmq;"`
- On Postgres, temporary tables are scoped to a session defaulting to `ON COMMIT PRESERVE ROWS`, however SQL clients often timeout sessions, so be aware of this if you're working interactively.
	- For example, VSCode's SQLTools requires `idleTimeoutMillis` to be set per connection, or else it will default to 10s before closing idle sessions. I set mine to 1h (3,600,000ms). Make sure to save the connection and reconnect, when changing this. You can also set it to 0, in which case only manually disconnecting and reconnecting will force the session to be closed.
- Did you know that `$$ ... $$`  blocks are just a different way to quote strings? And did you know that these blocks can be nested by using a quote identifier like `$myblock$ ... $myblock$`?
- [PIGSTY (PostgreSQL In Great STYle)](https://pigsty.io/) is a PostgreSQL local-first RDS alternative that supports nearly all extensions we tested, excluding `pgai`, but it does support it's competitor, `pg_vectorize`, from Tembo.

## Resources

- [PGXN - PostgreSQL Extension Network](https://pgxn.org/)
- [Trunk - A Postgres Extension Registry](https://pgt.dev/)
- [Just use Postgres](https://mccue.dev/pages/8-16-24-just-use-postgres)
- [Postgres as a Graph Database: (Ab)using pgRouting](https://supabase.com/blog/pgrouting-postgres-graph-database)
- [GCP: Configure PostgreSQL extensions](https://cloud.google.com/sql/docs/postgres/extensions)
- [AWS: Extension versions for Amazon RDS for PostgreSQL](https://docs.aws.amazon.com/AmazonRDS/latest/PostgreSQLReleaseNotes/postgresql-extensions.html)
- [Elasticsearch as a column store](https://www.elastic.co/blog/elasticsearch-as-a-column-store)
- [pg_mooncake: Fast Analytics in Postgres with Columnstore Tables and DuckDB](https://www.mooncake.dev/blog/how-we-built-pgmooncake)
- [Anomaly Detection in Time Series Using Statistical Analysis](https://medium.com/booking-com-development/anomaly-detection-in-time-series-using-statistical-analysis-cc587b21d008)
- [PostgreSQL Wiki: Incremental View Maintenance](https://wiki.postgresql.org/wiki/Incremental_View_Maintenance)
- [Everything You Need to Know About Incremental View Maintenance](https://materializedview.io/p/everything-to-know-incremental-view-maintenance)
- [What Goes Around Comes Around... And Around...](https://db.cs.cmu.edu/papers/2024/whatgoesaround-sigmodrec2024.pdf)
- [Faster JSON Generation with PostgreSQL](https://hashrocket.com/blog/posts/faster-json-generation-with-postgresql)
- [PIGSTY (PostgreSQL In Great STYle)](https://pigsty.io/)
- [TimescaleDB: Best Practices for Time Partitioning](https://docs.timescale.com/use-timescale/latest/hypertables/about-hypertables/#best-practices-for-time-partitioning)
- [TimescaleDB: Compression policy](https://docs.timescale.com/use-timescale/latest/compression/compression-policy/)
- [TimeScale Forum: Tuple decompression limit exceeded by operation](https://www.timescale.com/forum/t/tuple-decompression-limit-exceeded-by-operation/2465)
- [Hugging Face Datasets: jettisonthenet/timeseries_trending_youtube_videos_2019-04-15_to_2020-04-15](https://huggingface.co/datasets/jettisonthenet/timeseries_trending_youtube_videos_2019-04-15_to_2020-04-15)
- [Hugging Face Datasets: wykonos/movies](https://huggingface.co/datasets/wykonos/movies)
- [Ollama: nomic-embed-text](https://ollama.com/library/nomic-embed-text)
- [timescale/pgai : Migrating from the extension to the python library](https://github.com/timescale/pgai/blob/main/docs/vectorizer/migrating-from-extension.md)
- [Timescale: SQL interface for pgvector and pgvectorscale](https://docs.timescale.com/ai/latest/sql-interface-for-pgvector-and-timescale-vector/)
