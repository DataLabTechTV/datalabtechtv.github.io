---
title: "LabStore - Part 4 - Building an Object Store in Go: IAM - Identity and Access Management"
description: Building an IAM service on top of SQLite in Go, from config handling to proper secret encryption.
date: 2025-12-23T12:00:00+0100
categories: [Software Engineering]
tags: [iam, s3, go, object-store, aws, authentication, video]
---

## Summary

Learn how to build an IAM service on top of SQLite in Go, from config handling to proper secret encryption. We'll cover the required actions to implement an MVP, and SQLite pragmas and patterns to ensure performance. You'll learn how to design the database schema for IAM, and how to implement SQLite CRUD in Go, with concurrency, using buffered channels. We'll also touch on symmetric encryption, based on 256-bit AES-GCM, for secure secret storage, and describe our approach to organizing business logic and HTTP handlers, while also touching on interesting JSON marshaling details that arose during development.

Follow this series with IllumiKnow Labs, and let's see where this journey takes us. Hopefully you'll learn a lot along the way!

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; max-width: 100%;">
	<iframe
		src="https://www.youtube.com/embed/C5nCE5tOhLQ"
		frameborder="0"
		allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
		referrerpolicy="strict-origin-when-cross-origin"
		allowfullscreen
		style="position: absolute; top: 0; left: 0; width: 100%; height: 100%;">
	></iframe>
</div>

## Introducing IAM

An IAM API essentially handles CRUD operations for users, groups, and policies. Users can have access keys to access the S3 service, and they can also belong to groups. Policies are used for access control, and they can be attached to users or groups. IAM also supports inline or embedded policies, directly added to users or groups, but we do not support this option for now.

### Minimum Viable Actions

After a few iterations, we ended up with the follow list of IAM actions, for which we provide working but partial implementations:

- We only provide a single access key per user, matching the username, and providing a randomly generated secret key (overridden on subsequent creation requests);
- We do not support all response fields or errors;
- The IAM service is unprotected (i.e., there is no authentication, so it needs to be secured, for example behind a reverse proxy with TLS and HTTP auth).

Regardless, the existing IAM implementation is enough to do most tasks, and we're quite happy with it, given that our target was to reach an MVP.

Below is an overview of the IAM actions that we support in LabStore, with links to the respective pages in the official AWS IAM documentation:

- Users
    - [CreateUser](https://docs.aws.amazon.com/IAM/latest/APIReference/API_CreateUser.html)
    - [CreateAccessKey](https://docs.aws.amazon.com/IAM/latest/APIReference/API_CreateAccessKey.html)
    - [GetUser](https://docs.aws.amazon.com/IAM/latest/APIReference/API_GetUser.html)
    - [ListAccessKeys](https://docs.aws.amazon.com/IAM/latest/APIReference/API_ListAccessKeys.html)
    - [DeleteUser](https://docs.aws.amazon.com/IAM/latest/APIReference/API_DeleteUser.html)
    - [DeleteAccessKey](https://docs.aws.amazon.com/IAM/latest/APIReference/API_DeleteAccessKey.html)
- Groups
    - [CreateGroup](https://docs.aws.amazon.com/IAM/latest/APIReference/API_CreateGroup.html)
    - [AddUserToGroup](https://docs.aws.amazon.com/IAM/latest/APIReference/API_AddUserToGroup.html)
    - [GetGroup](https://docs.aws.amazon.com/IAM/latest/APIReference/API_GetGroup.html)
    - [DeleteGroup](https://docs.aws.amazon.com/IAM/latest/APIReference/API_DeleteGroup.html)
    - [RemoveUserFromGroup](https://docs.aws.amazon.com/IAM/latest/APIReference/API_RemoveUserFromGroup.html)
- Policies
    - [CreatePolicy](https://docs.aws.amazon.com/IAM/latest/APIReference/API_CreatePolicy.html)
    - [AttachUserPolicy](https://docs.aws.amazon.com/IAM/latest/APIReference/API_AttachUserPolicy.html)
    - [AttachGroupPolicy](https://docs.aws.amazon.com/IAM/latest/APIReference/API_AttachGroupPolicy.html)
    - [GetPolicy](https://docs.aws.amazon.com/IAM/latest/APIReference/API_GetPolicy.html)
    - [ListAttachedUserPolicies](https://docs.aws.amazon.com/IAM/latest/APIReference/API_ListAttachedUserPolicies.html)
    - [ListAttachedGroupPolicies](https://docs.aws.amazon.com/IAM/latest/APIReference/API_ListAttachedGroupPolicies.html)
    - [DeletePolicy](https://docs.aws.amazon.com/IAM/latest/APIReference/API_DeletePolicy.html)
    - [DetachUserPolicy](https://docs.aws.amazon.com/IAM/latest/APIReference/API_DetachUserPolicy.html)
    - [DetachGroupPolicy](https://docs.aws.amazon.com/IAM/latest/APIReference/API_DetachGroupPolicy.html)

### Policy Document

A policy is defined by a JSON document with the following format:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListAllMyBuckets"],
      "Resource": ["*"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:Get*",
        "s3:List*"
      ],
      "Resource": [
        "arn:aws:s3:::test-bucket",
        "arn:aws:s3:::test-bucket/*"
      ]
    }
  ]
}
```

We support both `Allow` and `Deny` effects, AWS-compatible ARN identifiers for resource names, and the following S3 actions:

- `*` –  matches all actions
- `s3:ListAllMyBuckets`
- `s3:CreateBucket`
- `s3:DeleteBucket`
- `s3:ListBucket`
- `s3:PutObject`
- `s3:GetObject`
- `s3:DeleteObject`

We also support globbing for resources (e.g., `arn:aws:s3:::test-bucket/*`) and actions (e.g., `s3:Get*`).

## Backend Configuration

We implemented the [LabStore configuration](https://github.com/IllumiKnowLabs/labstore/blob/fd579886846c42f5bb7c464e2f09123d6df52a13/backend/internal/config/config.go) for IAM via [spf13/viper](https://github.com/spf13/viper), with lower priority for defaults, followed by the [labstore.yml](https://github.com/IllumiKnowLabs/labstore/blob/fd579886846c42f5bb7c464e2f09123d6df52a13/labstore.example.yml) config file, environment variables, and, with the highest priority, command line arguments.

In order to keep it simple, we use a consistent naming convention across config sources. For example, if we're setting `backend` configs, which are used by the `labstore-server` command, then a setting like `backend.storage.data_dir` in the YAML file can be overridden by `LABSTORE_BACKEND_STORAGE_DATA_DIR`, where `LABSTORE_` is the prefix for all LabStore configs set via env vars. We can also override the env var using the CLI, but this time, since the context is not ambiguous (e.g., for `labstore-server` we know we're handling LabStore backend configs), we only use `--storage-data-dir` without any prefix . This behavior is consistent across the application—in summary, for env vars we add a prefix to avoid potential collisions with other program environments, and for the CLI we remove the unrequired prefix to make arguments more manageable, but, regardless, we always name configs consistently across all sources.

Below is an example for the `backend` config. We also have three other sections, which we do not cover here, named `web`, `shared`, and `benchmark` (covered on the [previous video](https://youtu.be/1KK4ibyqG2s)).

```yaml
backend:
  storage:
    data_dir: ./data
    keys_dir: ./keys
  admin:
    server:
      host: 0.0.0.0
      port: 6787
    auth:
      access_key: admin
      secret_key: adminadmin
  iam:
    server:
      host: 0.0.0.0
      port: 6788
    db:
      max_open_conns: 3
      max_idle_conns: 3
      write_chan_cap: 32
      timeout_ms: 5000
      read_cache_size_kib: 65536
      writer_cache_size_kib: 16384
  s3:
    server:
      host: 0.0.0.0
      port: 6789
    paging:
      max_keys: 1000
    io:
      buffer_size: 262144
```

Notice that we moved the storage configs into its own namespace, and created separate namespaces for the `admin`, `iam`, and `s3` servers. The admin server only provides a health check endpoint currently, but we plan to use it in the future for other LabStore-specific tasks. The S3 server exposes our object store through an S3-compatible API. Finally, the IAM server, that we introduce here today, provides a subset of AWS IAM compatible endpoints to help manage users, groups, and policies.

### Storage Changes

The directory structure has also evolved to make room for the IAM requirements. We now configure a `data_dir` and a `keys_dir`.

- While objects were previously stored directly on the `data_dir`, they are now stored in an `objects/` subdirectory inside the `data_dir`.
- We added a new `metadata/` subdirectory to the `data_dir`, which will contain the `iam.db` SQLite database.
- We also set a separate `keys_dir` to store cryptographic keys—these should be backed up separately. More on this topic below, under the [Security](#security) section.

### IAM DB Configs

Notice that there are a few settings under `backend.iam.db` that let you customize your SQLite IAM database:

```yaml
max_open_conns: 3
max_idle_conns: 3
write_chan_cap: 32
timeout_ms: 5000
read_cache_size_kib: 65536
writer_cache_size_kib: 16384
```

- `max_open_conns` / `max_idle_conns` – control the SQLite reader connections—how many can be open or remain idle at a time, before reads are blocked or idle connections are closed.
- `write_chan_cap` – determines the size of the buffered channel that consumes write queries—once the limit is reached, requests will block; we do not have a channel timeout yet.
- `timeout_ms` – used to timeout a SQLite connection when there are no connections available to handle the request—either `max_open_conns` is reached for readers, or the channel is full for writers.
- `read_cache_size_kib` / `writer_cache_size_kib` – SQLite cache size for readers and for the writer.

## Implementing IAM

We implement [IAM as separate service in LabStore](https://github.com/IllumiKnowLabs/labstore/blob/release/backend/v0.1.0/backend/internal/router/iam.go), and we integrate it in the S3-compatible service through a [custom middleware](https://github.com/IllumiKnowLabs/labstore/blob/release/backend/v0.1.0/backend/internal/middleware/iam.go) for which we had already created a placeholder. Storage is completely supported on SQLite, which is embedded into the server—we might need a different solution, if we later expand LabStore to support multiple nodes, which will largely depend on the interest the project generates within the community, to justify expanding into distributed systems.

Next, we cover the database schema, as well as pragmas and the strategy we used to handle connections for reading an writing. Since we're working with credentials, we also cover our security approach openly, so that it has a change to be scrutinized. Finally, we cover the business logic and HTTP requests, focusing on the data types and errors that we implemented in Go. And we close with our manual testing strategy, an area that will need some attention in the future, to make the project more accessible to external contributions.

### Database

When the server is first started, it will ensure that the database exists under `/data/metadata/iam.db` (assuming that `/data` is our `backend.storage.data_dir`).

#### Schema

Our [database schema](https://github.com/IllumiKnowLabs/labstore/blob/fd579886846c42f5bb7c464e2f09123d6df52a13/backend/internal/iam/store.go#L171) is relatively straightforward, as we can see in the <acronym title="Entity-Relationship Diagram">ERD</acronym> below:

<pre class="mermaid">
---
title: IAM SQLite Database Schema
---
erDiagram
    users {
	    TEXT user_id PK
	    TEXT name UK
	    TEXT arn UK
	    TEXT access_key
	    BLOB secret_key
    }
    groups {
		TEXT group_id PK
		TEXT name UK
		TEXT arn UK
	}
	policies {
		TEXT policy_id PK
		TEXT name UK
		TEXT arn UK
		JSON document "NOT NULL"
		DATETIME created_at "NOT NULL DEFAULT (CURRENT_TIMESTAMP)"
		DATETIME updated_at "NOT NULL DEFAULT (CURRENT_TIMESTAMP)"
	}

    users }o--o{ groups : member
    users }o--o{ policies : attaches
    groups }o--o{ policies : attaches
</pre>

The main entity tables are created as follows, each with a [unique identifier](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html#identifiers-unique-ids), unique name, and [unique ARN](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference-arns.html).

```sql
CREATE TABLE IF NOT EXISTS users (
	user_id TEXT PRIMARY KEY,
	name TEXT UNIQUE,
	arn TEXT UNIQUE,
	access_key TEXT,
	secret_key BLOB
);

CREATE TABLE IF NOT EXISTS groups (
	group_id TEXT PRIMARY KEY,
	name TEXT UNIQUE,
	arn TEXT UNIQUE
);

CREATE TABLE IF NOT EXISTS policies (
	policy_id TEXT PRIMARY KEY,
	name TEXT UNIQUE,
	arn TEXT UNIQUE,

	document JSON NOT NULL,

	created_at DATETIME NOT NULL DEFAULT (CURRENT_TIMESTAMP),
	updated_at DATETIME NOT NULL DEFAULT (CURRENT_TIMESTAMP)
);
```

For `policies`, we also store the policy `document` which is `JSON` / `TEXT`, alongside the `created_at` and `updated_at` `DATETIME` fields. Both of the `DATETIME` fields are set via defaults or through the following trigger:

```sql
CREATE TRIGGER IF NOT EXISTS policies_update_trigger
AFTER UPDATE ON policies
FOR EACH ROW
BEGIN
	UPDATE policies
	SET updated_at = CURRENT_TIMESTAMP
	WHERE policy_id = OLD.policy_id;
END;
```

Finally, as shown below, we also define three junction tables for the many-to-many relationships defining `group_users`, `user_policies`, and `group_policies`. Since we use foreign key checks, we also define those alongside cascading rules.

```sql
CREATE TABLE IF NOT EXISTS group_users (
	group_id TEXT,
	user_id TEXT,
	PRIMARY KEY (group_id, user_id),
	FOREIGN KEY(group_id)
		REFERENCES groups(group_id)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	FOREIGN KEY(user_id)
		REFERENCES users(user_id)
		ON DELETE CASCADE
		ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS user_policies (
	user_id TEXT,
	policy_id TEXT,
	PRIMARY KEY (user_id, policy_id),
	FOREIGN KEY(user_id)
		REFERENCES users(user_id)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	FOREIGN KEY(policy_id)
		REFERENCES policies(policy_id)
		ON DELETE CASCADE
		ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS group_policies (
	group_id TEXT,
	policy_id TEXT,
	PRIMARY KEY (group_id, policy_id),
	FOREIGN KEY(group_id)
		REFERENCES groups(group_id)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	FOREIGN KEY(policy_id)
		REFERENCES policies(policy_id)
		ON DELETE CASCADE
		ON UPDATE CASCADE
);
```

#### PRAGMAs

Database connections are opened with the following [pragmas](https://www.sqlite.org/pragma.html), with a slight difference in `cache_size` between the reader and writer:

```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA temp_store = MEMORY;
PRAGMA cache_size = -65536; -- 64 MiB; or 16MiB for writer
PRAGMA locking_mode = NORMAL;
PRAGMA foreign_keys = ON;
PRAGMA busy_timeout = 5000; -- 5s
```

We use `WAL` mode to enable a write-ahead log, making it possible to use multiple readers and a single writer concurrently, without blocking.

We set `synchronous` to `NORMAL`, which controls how often `fsync`. The `NORMAL` mode ensures high performance and safety for the `WAL` mode, and an IAM service is also not write-intensive, but rather read-intensive.

Temporary tables and indices will be stored in `MEMORY`, according to the `temp_store` pragma.

By default, we use 64 MiB of cache for a default pool of three readers, or 16 MiB of cache for the single writer. These can, however, be set through the config.

We connect in `NORMAL` `locking_mode`—the only other option would be `EXCLUSIVE`, but we need concurrency here.

And, finally, we enable foreign key checks, and a timeout of 5 seconds when no connection is available.

#### Connections

We had to make a few decision regarding how to handle the connection to SQLite in Go:

1. Library to handle querying (e.g., [sqlc](https://sqlc.dev/), [sqlx](https://jmoiron.github.io/sqlx/), etc.);
2. SQLite driver—C-based [mattn/go-sqlite3](https://pkg.go.dev/github.com/mattn/go-sqlite3), or pure Go [modernc.org/sqlite](https://pkg.go.dev/modernc.org/sqlite);
3. Inline SQL queries or [embedded files](https://pkg.go.dev/embed).

Regarding decision 1, `sqlc` is a Go code generator that takes SQL files as input, producing methods that we can call directly for simple CRUD, while also supporting context. Since, in general, we do not like this kind of black box approach, so we ended up going with `sqlx`, which is a SQL query executor with a few helpers to integrate with data types, also supporting context—this is relevant to ensure that, when HTTP requests are cancelled, the SQL query is also aborted.

Regarding decision 2, while the C-based driver is considered the preferred approach, we didn't want to deal with the hassle of cross-compilation issues (we'd need a C compiler to run in the target platform), so we went with the pure Go driver (this let's us compile for any platform locally, which is easier to manage; while the driver is slower, the IAM service won't be under immense load, specially given the self-hosting target audience for LabStore).

Finally, regarding decision 3, while we do appreciate the option to separate SQL in their own files, we went with inline SQL queries, since most of our queries are quite simple and small, with the exception of the schema creation SQL. In the future, we might rethink this decision, but the cost of migration is not too high—just move queries to their own SQL files and add a comment on top of a `query` string variable that points to the file:

```go
//go:embed sql/file.sql
var query string
```

#### Store

We define a [Store](https://github.com/IllumiKnowLabs/labstore/blob/fd579886846c42f5bb7c464e2f09123d6df52a13/backend/internal/iam/store.go#L171) data type, where we handle all of our IAM-related queries. For reading concurrently, we define a `Store.readDB` variable with a connection pool that defaults to only three connections, but can be configured with a higher value for systems with available resources. For writing, we use a separate strategy based on a buffered channel—`Store.writeCh`—to mitigate potencial write blocks, given we are required to use a single writer. By default the buffer can hold 32 SQL tasks, but this can be configured as well.

The reader is accessed directly via `sqlx`—e.g., `store.readDB.SelectContext`. On the other hand, the writer is accessed either through specific unexported store methods—`store.sqlExecContext` and `store.sqlNamedExecContext`—or by sending a `sqlTask` into the `store.writeCh` task channel, containing a response channel. This is implemented as follows.

First, we define a `sqlTask` data type to wrap a `sqlFn`, containing the actual `sqlx` querying code, alongside a `uuid` to identify the request, the context, usually passed from the HTTP request, and the result channel, where we'll send a `sqlTaskResult` to.

```go
type sqlFn func(ctx context.Context, db *sqlx.DB) sqlTaskResult

type sqlTask struct {
	uuid  string
	ctx   context.Context
	resCh chan<- sqlTaskResult
	fn    sqlFn
}
```

The `sqlTaskResult` data type will hold the tuple that is usually returned when running a query through `sqlx` methods:

```go
type sqlTaskResult struct {
	sqlRes sql.Result
	err    error
}
```

We also provide a constructor for `sqlTask` instances, which takes care of the UUID for us:

```go
func newSQLTask(
	ctx context.Context,
	resCh chan<- sqlTaskResult,
	fn sqlFn
) sqlTask {
	return sqlTask{
		uuid:  uuid.NewString(),
		ctx:   ctx,
		resCh: resCh,
		fn:    fn,
	}
}
```

And, finally, we construct our writer worker by calling the following function only once:

```go
func newWriterWorker(db *sqlx.DB) chan<- sqlTask {
	slog.Debug(
		"new writer worker",
		"writeChanCap", config.IAM.DB.WriteChanCap
	)

	taskCh := make(chan sqlTask, config.IAM.DB.WriteChanCap)

	go func() {
		for task := range taskCh {
			slog.Debug("sql write task", "uuid", task.uuid)
			sqlResp := task.fn(task.ctx, db)
			task.resCh <- sqlResp
		}
	}()

	return taskCh
}
```

Notice that the goroutine wraps the `for` loop, ensuring that all tasks will be received concurrently, but handled sequentially by the writer (i.e., this is merely so that we can return from the function).

Any SQL tasks will then be sent to the `taskCh`, which is available as `Store.writeCh`. For example:

```go
func (store *Store) sqlExecContext(
	ctx context.Context,
	query string,
	args ...any,
) (sql.Result, error) {
	resCh := make(chan sqlTaskResult, 1)

	store.writeCh <- newSQLTask(ctx, resCh,
		func(ctx context.Context, db *sqlx.DB) sqlTaskResult {
			res, err := db.ExecContext(ctx, query, args...)
			return sqlTaskResult{sqlRes: res, err: err}
		},
	)

	res := <-resCh

	return res.sqlRes, res.err
}
```

### Security and Encryption

We need access to the plain text secret key to compute the [SigV4](https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html) authorization header:

```go
dateKey := hmacSHA256([]byte("AWS4"+cred.secretKey), []byte(date))
```

As you can see, this will be hashed with the `date`. So, while the secret key doesn't need to be transmitted in plain text, we'll need to have access to the plain text version both on the client and server sides.

As such, in order to secure secret keys, we use symmetrical encryption based on 256-bit AES-GCM. In turn, for this to be possible, we first generate a master key that we can use for encryption. This is created on the first startup for LabStore, and stored under the `backend.storage.keys_dir`,  as defined in the config.

When migrating LabStore, make sure you backup the keys directory, and that your configs are pointing to the correct directory, otherwise a new master key will be produced, and subsequent secret keys encrypted with it. We currently provide no way to detect that a new master key, different from a previously used one, came into use, but this is possible to check with AES-GCM, and we might add it in the future for integrity insurance.

We generate a master key through the `iam.ensureMasterKey` method by calling the following functions:

```go
// Produces a key with the given byte-length
func GenerateKey(length int) ([]byte, error) {
	key := make([]byte, length)

	if _, err := rand.Read(key); err != nil {
		return nil, err
	}

	return key, nil
}

// Produces a AES-256 master key (32 bytes)
func GenerateMasterKey() ([]byte, error) {
	return GenerateKey(32)
}
```

Each secret key is then encrypted using this master key, as well as a nonce, which a unique salt-like value that is produced for each encryption operation. This is prepended to the ciphertext for the secret key and stored as a byte blob in the database.

Please notice that the IAM server is currently unprotected, so, if you deploy LabStore as is, please make sure that you put it behind an authenticated reverse proxy, protected by TLS and HTTP Auth. In the future, we'll protect the IAM service with the administrator credentials.

### Business Logic and HTTP Handlers

Our business logic is mainly concerned with interacting with the database, and caching users, groups, or policies into our internal corresponding data types. HTTP handlers will then implement calls to this business logic, but they'll build the response separately, based on their own custom data types, defined according to the AWS IAM API.

We also define our own internal error types, as well as IAM errors, since our internal errors provide additional details that are not communicated through the IAM API—only IAM errors are XML encodable. This lets us log a more detailed error message, even when the returned IAM error is a general `ServiceFailure`. While we are now aware of the error handling workflow that should be implemented, this still needs a lot of work to reach the state that we want (e.g., we need to track the request ID when logging internal errors).

Most business logic is essentially CRUD, handled similarly across the IAM service. We opted to keep the business logic and the HTTP handler in the same file, as this matches our development workflow. We still keep them logically separate though, as we might need to implement similar requests via the CLI, or switch to a different HTTP handling approach in the future (less likely).

#### CreatePolicy Example

The business logic is quite extensive, so we'll not cover it all here, but we'll provide a concrete example below, based on `CreatePolicy`, starting from the `Store` data type, at the core of the IAM service.

##### Data Types

<pre class="mermaid">
---
title: Class Diagram for the CreatePolicy IAM Action
---
classDiagram
	class Store {
		+CachedUsers : map[string]*CachedUser,
		+CachedGroups : map[string]*CachedGroup,
		+CachedPolicies : map[string]*CachedPolicy,
		+TTL : time.Duration
		-readDB : *sqlx.DB
		-writeCh : chan<- sqlTask

		+CreatePolicy(ctx context.Context, name string, doc *PolicyDocument) :&nbsp;(*Policy, error)
		+CreatePolicyHandler(w http.ResponseWriter, r *http.Request)
	}

	class CachedPolicy {
		+Policy : *Policy
		+LoadedAt : time.Time
		+NeverExpire : bool
	}

	class Policy {
		+PolicyID : string \`"db:"policy_id"\`
		+Name : string \`db:"name"\`
		+Arn : string \`db:"arn"\`
		+AttachmentCount : int
		+CreatedAt : time.Time \`db:"created_at"\`
		+UpdatedAt : time.Time \`db:"updated_at"\`
		+Document : *PolicyDocument \`db:"document"\`
	}

	class PolicyDocument {
		+Version : string
		+Statement : []Statement
	}

	class Statement {
		+Effect : Effect
		+Action : Actions
		+Resource: Resources
	}

	Store --> CachedPolicy
	CachedPolicy --> Policy
	Policy --> PolicyDocument
	PolicyDocument "1" --> "*" Statement
</pre>

For the HTTP handler, we also define the following response types, inside the `iam` package, under `policies.go`,  `policies_create.go` and `types.go`.

<pre class="mermaid">
classDiagram
	class CreatePolicyResponse {
		+XMLName : xml.Name \`xml:"https\://iam.amazonaws.com/doc/2010-05-08/ CreatePolicyResponse"\`
		+CreatePolicyResult : *CreatePolicyResult
		+ResponseMetadata : *ResponseMetadata
	}

	class CreatePolicyResult {
		+Policy : *PolicyResult
	}

	class PolicyResult {
		+XMLName : xml.Name \`xml:"Policy"\`
		+PolicyName : string
		+DefaultVersionId : string
		+PolicyId : string
		+Path : string
		+Arn : string
		+AttachmentCount : int
		+CreateDate : time.Time
		+UpdateDate : time.Time
	}

	class ResponseMetadata {
		+RequestId : string
	}

	CreatePolicyResponse --> CreatePolicyResult
	CreatePolicyResponse --> ResponseMetadata
	CreatePolicyResult --> PolicyResult
</pre>

##### Internal and IAM Errors

The HTTP handler also relies on the following errors, defined inside the `errs` package, under `iam.go`:

```go
func IAMServiceFailure() *IAMError {
	return &IAMError{
		Type:       IAMReceiverType,
		Code:       "ServiceFailure",
		Message:    "The request processing has failed because of an internal error.",
		StatusCode: http.StatusInternalServerError,
	}
}

func IAMEntityAlreadyExists(entityName string) *IAMError {
	return &IAMError{
		Type:       IAMReceiverType,
		Code:       "EntityAlreadyExists",
		Message:    fmt.Sprintf("The entity %s already exists.", entityName),
		StatusCode: http.StatusConflict,
	}
}
```

And we use a non-compliant error to handle missing query parameters (another one to improve in the future, under error handling):

```go
func HTTPMissingQueryParam(param string) error {
	return fmt.Errorf("missing query parameter: %s", param)
}
```

##### JSON Marshaling

Both `Action` and `Resource` can be a single string or an array of strings, so they have their own types, `Actions` and `Resources`, so that we can handle this:

```go
type Action string

const (
	S3ListAllMyBuckets Action = "s3:ListAllMyBuckets"
	S3CreateBucket     Action = "s3:CreateBucket"
	S3DeleteBucket     Action = "s3:DeleteBucket"
	S3ListBucket       Action = "s3:ListBucket"
	S3PutObject        Action = "s3:PutObject"
	S3GetObject        Action = "s3:GetObject"
	S3DeleteObject     Action = "s3:DeleteObject"
)

type Actions []Action

func (a *Actions) UnmarshalJSON(data []byte) error {
	var single Action
	if err := json.Unmarshal(data, &single); err == nil {
		*a = []Action{single}
		return nil
	}

	var multi []Action
	if err := json.Unmarshal(data, &multi); err != nil {
		return err
	}
	*a = multi
	return nil
}
```

Also notice that we use enum-like constants to store each supported action within our policies. These cover all of our existing S3 requests.

In order to properly store JSON in SQLite, we also needed to implement the following methods for `PolicyDocument`:

```go
func (pd *PolicyDocument) Value() (driver.Value, error) {
	return json.Marshal(pd)
}

func (pd *PolicyDocument) Scan(src any) error {
	if src == nil {
		*pd = PolicyDocument{}
		return nil
	}

	switch s := src.(type) {
	case []byte:
		return json.Unmarshal(s, pd)
	case string:
		return json.Unmarshal([]byte(s), pd)
	default:
		return fmt.Errorf("unsupported type: %T", src)
	}
}
```

Notice that `s := src.(type)` is only valid inside a `switch` statement, where the `case` statements will match the type, and the `s` variable will contain the value cast to that type.

#### IAM Middleware

IAM policy checking is then done by the IAM middleware, establishing the correct permissions for each individual S3 request.

For example, for `GetObject`, we set the permissions, under `router/s3.go` as follows:

```go
router.Handle(
	"GET /{bucket}/{key...}",
	middleware.WithIAM(
		iam.S3GetObject,
		http.HandlerFunc(object.GetObjectHandler),
	),
)
```

This is then handled by the IAM middleware under `middleware/iam.go`, which checks if the corresponding access key has the required permissions:

```go
func WithIAM(action iam.Action, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		slog.Debug("with iam", "action", action)
		if action == "" {
			return
		}

		bucket := r.PathValue("bucket")
		key := r.PathValue("key")
		accessKey := GetRequestAccessKey(r)

		if !iam.CheckPolicy(accessKey, bucket, key, iam.Action(action)) {
			errs.Handle(w, errs.S3AccessDenied())
			return
		}

		next.ServeHTTP(w, r)
	})
}
```

The `iam.CheckPolicy` function, defined in [iam/iam.go](https://github.com/IllumiKnowLabs/labstore/blob/498c651ed73ca548403452eb278679f6fa86ac52/backend/internal/iam/iam.go#L38), will match the resource given by `bucket` and `key`, as well as the requested `action`, with the policy stored in the `iam.Store`. If the access key has the required permissions, it will be allowed to continue.

### Manual Testing

For testing, we wanted to implement unit tests based on `net/http/httptest` for the REST API, as well as unit tests for the business logic `Store` methods. However, since we're working under a time constraint, to bring you this content at a decent pace, we scheduled this for `v0.2.0`.

During development, however, we relied heavily on scripted manual testing, directly based on `just` commands and `httpie` `POST` requests. Recently, we tried the official `aws` client, and it initially failed to work with the IAM endpoint, because we had used query parameters instead of form parameters. This has been fixed, and is already available on this week's [release branch](https://github.com/IllumiKnowLabs/labstore/blob/498c651ed73ca548403452eb278679f6fa86ac52/backend/internal/router/iam.go#L48).

In order to list all IAM testing commands, run:

```bash
just backend
```

And look at the `test-iam` group:

```bash
[test-iam]
test-iam-add-user-to-group
test-iam-attach-group-policy
test-iam-attach-user-policy
test-iam-create-access-key
test-iam-create-group
test-iam-create-policy
test-iam-create-user
test-iam-delete-access-key
test-iam-delete-group
test-iam-delete-policy
test-iam-delete-user
test-iam-detach-group-policy
test-iam-detach-user-policy
test-iam-get-group
test-iam-get-policy
test-iam-get-user
test-iam-group-policy
test-iam-list-access-keys
test-iam-list-attached-group-policies
test-iam-list-attached-user-policies
test-iam-remove-user-from-group
test-iam-user-policy
```

If you'd like to test the API, make sure you have `just` and `httpie` installed, and try out this command for example:

```bash
just backend::test-iam-group-policy
```

This will run several other commands, so it represents a moderately extensive testing of the IAM service:

```just
[group("test-iam")]
test-iam-group-policy: test-iam-create-user \
	test-iam-create-access-key test-iam-create-group \
	test-iam-add-user-to-group test-iam-create-policy \
	test-iam-attach-group-policy
```

We rely the bucket, user, group, and policy preset as `justfile` variables—`test-bucket`, `test_user`, `test_group`, and `test-policy`. The policy document we set for `test-policy` is the one displayed in the [Policy Document](#policy-document) section above.

## Go Tip of the Day

At some point, we were trying to understand why the `go-sqlite3` dependency was being listed under `go.sum`—this is for the C-based SQLite driver that we opted not to use, so it shouldn't be there. If you hit a similar problem, here's my workflow.

First, I checked whether `go-sqlite3` was used in any of my source files using [ripgrep](https://github.com/BurntSushi/ripgrep):

```bash
rg go-sqlite3
```

This listed the match for `go.sum` as follows:

```
go.sum
40:github.com/mattn/go-sqlite3 v1.14.22 h1:2gZY6PC6kBnID23Tichd1K+Z0oS6nE/XwU+Vz/5o4kU=
41:github.com/mattn/go-sqlite3 v1.14.22/go.mod h1:Uh1q+B4BYcTPb+yiD3kU8Ct7aC0hY9fxUwlHK0RXw+Y=
```

We then tried to understand if it was also listed in the dependency graph:

```bash
go mod graph | grep go-sqlite3
```

And this output a single match for `sqlx`:

```
github.com/jmoiron/sqlx@v1.4.0 github.com/mattn/go-sqlite3@v1.14.22
```

But the way we finally understood where this came from was through the following command:

```bash
go mod why -m github.com/mattn/go-sqlite3
```

This outputs exactly the dependencies that lead to `go-sqlite3`:

```
## github.com/mattn/go-sqlite3
github.com/IllumiKnowLabs/labstore/backend/internal/iam
github.com/jmoiron/sqlx
github.com/jmoiron/sqlx.test
github.com/mattn/go-sqlite3
```

This shows us exactly why `go-sqlite3` is included as a dependency: it is needed for testing under `sqlx.test`, which makes sense, and is unrelated to our code.
