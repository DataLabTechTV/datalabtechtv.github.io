---
title: "LabStore - Part 1 - Building an Object Store in Go: How Hard Can It Be?"
description: Learn how to...
date: 2025-10-28T12:00:00+0100
categories: [Software Engineering]
tags: [object-store, s3, go, video]
---

## Summary

Learn how to...

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; max-width: 100%;">
	<iframe
		src="https://www.youtube.com/embed/TBD"
		frameborder="0"
		allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
		referrerpolicy="strict-origin-when-cross-origin"
		allowfullscreen
		style="position: absolute; top: 0; left: 0; width: 100%; height: 100%;">
	></iframe>
</div>

## MinIO - The End of a Chapter

MinIO has grown to be loved by the community as the *de facto* open source solution for on-premise S3 object storage. Unfortunately, more recently they decided to follow a different direction, pushing all their OSS efforts into the background, which has resulted in widely spread negative feedback within the community.

First, they [removed critical features from their UI](https://www.reddit.com/r/selfhosted/comments/1kva3pw/avoid_minio_developers_introduce_trojan_horse/), which led users like me to keep running older Docker image versions, and others, like the user on [this Reddit post](https://www.reddit.com/r/selfhosted/comments/1nf5tam/critical_features_vanished_from_minio_ce_so_i/), to create an alternative UI that brings back removed features. Unfortunately, the most likely outcome here is that those features will also be removed from the community edition backend in the near future, so this might not be a viable solution for the open source or self-hosting communities.

Some users also decided to [create a fork](https://www.reddit.com/r/hackernews/comments/1oebo00/openmaxio_is_a_communitymaintained_fork_of_minio/). This is what's great about open source—it will remain open as long as someone maintains it. Unfortunately, there are also a few challenges here, regarding trust and fragmentation. First of all, it's likely that multiple forks will appear. Not counting the ones done for archival, personal use, or testing, some of them will also be quickly abandoned. Until we know that there are serious devs behind a fork, and that users are adopting that fork, it will be hard to make a decision. The likely scenario here is that users will simply adopt another alternative for S3 object storage, completely dropping any MinIO-related distribution.

But it gets worse... Recently, MinIO decided that their community edition (CE) would be a [source only](https://www.reddit.com/r/minio/comments/1oez7ui/minio_is_sourceonly_now/) distribution, scrapping their [prebuilt binaries](https://www.reddit.com/r/selfhosted/comments/1ocggb6/minio_moving_to_a_source_only_distribution/) along with their [Docker image](https://www.reddit.com/r/devops/comments/1ocoacj/minio_did_a_ragpull_on_their_docker_images/) builds. While it looks like they are keeping older images, they will not be building any new binaries or images for MinIO CE.

Regarding Docker images, users have been discussing the issue [here](https://www.reddit.com/r/sysadmin/comments/1ohqomq/minio_stopped_publishing_free_docker_images_which/) and [here](https://www.reddit.com/r/selfhosted/comments/1ocggb6/minio_moving_to_a_source_only_distribution/), highlighting that, while the community can build their own binaries or images, these might easily be compromised, which is a major breach in trust.

But it gets even worse... On top of moving to a source only distribution, they are also [ceasing further development](https://github.com/minio/minio/issues/21647#issuecomment-3439134621) apart from bug fixes or security patches—the community has made notice that MinIO is no longer in [active development](https://www.reddit.com/r/programming/comments/1of8ak4/minio_community_is_not_actively_being_developed/).

It looks like they are turning their focus away from their original product, and into their newer MinIO AIStor solution, developed on a separate codebase, and offering only a commercial license. I wonder if this strategy will work for them, after losing so much karma with the community. Users are calling it a [bait and switch](https://www.reddit.com/r/minio/comments/1l85s47/what_a_shame_minio_bait_and_switch_leaves/), while progressively [looking for alternatives](https://www.reddit.com/r/grafana/comments/1ohfiph/current_state_of_minio/).

Of course it will be hard to get an alternative for the new features that AIStor will bring, as this competes directly with [Amazon S3 Tables](https://aws.amazon.com/s3/features/tables/), offering AI/ML lifecycle data management features, along with features to simplify the management of open table formats, like [Iceberg](https://iceberg.apache.org/), [Hudi](https://iceberg.apache.org/), or [Delta Lake](https://delta.io/), that support data lakehouses—no DuckLake though 😟.

In all honesty, direction wise, this is all great! It makes sense. I just don't understand the decision to essentially kill the open source solution. It could easily have been planned to fit their recent goals, and, with little effort, avoid compromising the positive standing they cultivated with the community.

Regardless, if you're using MinIO, this is the time to make a decision. Either switch to AWS S3 directly, opt to pay for a commercial license, or switch to another alternative. And there are a few, like [Garage](https://garagehq.deuxfleurs.fr/), [SeaweedFS](https://github.com/seaweedfs/seaweedfs), [RustFS](https://github.com/rustfs/rustfs), or even [Ceph](https://ceph.com/) with the [RADOS gateway](https://docs.ceph.com/en/reef/radosgw/). In a future video, we'll test and benchmark these alternatives.

## Implementing an S3 Object Store

How hard can it be, right? Is it complicated? Not really. Can it get complex? Definitely. SigV4 is extensive and, since it's all hashes, the slightest mistake will produce the wrong signature—and this is hard to debug, as it's mostly manually checking the code. On top of that, the API is also deceptively simple, with each request making extensive use of HTTP headers, each requiring individual attention.

Beyond the AWS S3 API, we also need to take a look at IAM, establishing an approach to manage our users, groups, policies, etc. This is not a part of S3, but a requirement for it to work properly. It's easy to implement a root user and work from there, but it's harder if you want proper identity and access management (IAM). We don't have a full plan for this yet, but we'll likely reproduce AWS IAM's requests as well.

So, what's the fastest path to an <abbr title="Minimum Viable Product">MVP</abbr>? We need to categorize requests, prioritize them, and, for each one, decide on the minimum headers and response elements to make it work. At this stage, we won't be fully compliant with the API, but, to be clear, no one is. Compliance is fractional—each open source object store will provide a table with the list of supported requests, while completeness details per request won't be provided.

Let's then plan, based on the following resources:

- AWS Signature Version 4
	- https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html
	- https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-streaming.html
- AWS Simple Storage Service (S3) - API Reference
	- https://docs.aws.amazon.com/AmazonS3/latest/API/API_Operations_Amazon_Simple_Storage_Service.html
- AWS Identity and Access Management - API Reference
	- https://docs.aws.amazon.com/IAM/latest/APIReference/API_Operations.html

### 🟥 P0 – Critical

These are the absolute minimal actions required for an object store to do its job. Each request should take an `Authorization` header with the corresponding SigV4 hash. Here, if it's just a toy project, you can simply ignore that header and accept all requests regardless, but, if you're serious about it, like we are, then implementing SigV4 should be top priority as well.

So also consider SigV4 to be 🟥 P0 – Critical.

Don't worry about the details on SigV4 now, as I'll write a blog post dedicated to this next week, alongside the customary YouTube video.

So, top priority should be for bucket and object CRUD, as we can see below. For each S3 Action, we show the method, path, and a basic description below. Each action links to the official documentation as well.

#### Buckets

| S3 Action                                                                               | Method | Path                    | Description                 |
| --------------------------------------------------------------------------------------- | ------ | ----------------------- | --------------------------- |
| [ListBuckets](https://docs.aws.amazon.com/AmazonS3/latest/API/API_ListBuckets.html)     | GET    | `/`                     | List all buckets            |
| [CreateBucket](https://docs.aws.amazon.com/AmazonS3/latest/API/API_CreateBucket.html)   | PUT    | `/{bucket}`             | Create bucket               |
| [DeleteBucket](https://docs.aws.amazon.com/AmazonS3/latest/API/API_DeleteBucket.html)   | DELETE | `/{bucket}`             | Delete bucket               |
| [ListObjects](https://docs.aws.amazon.com/AmazonS3/latest/API/API_ListObjects.html)     | GET    | `/{bucket}`             | List objects in bucket      |
| [ListObjectsV2](https://docs.aws.amazon.com/AmazonS3/latest/API/API_ListObjectsV2.html) | GET    | `/{bucket}?list-type=2` | List objects in bucket (V2) |
| [HeadBucket](https://docs.aws.amazon.com/AmazonS3/latest/API/API_HeadBucket.html)       | HEAD   | `/{bucket}`             | Check bucket existence      |

#### Objects

| S3 Action                                                                             | Method | Path                                    | Description        |
| ------------------------------------------------------------------------------------- | ------ | --------------------------------------- | ------------------ |
| [PutObject](https://docs.aws.amazon.com/AmazonS3/latest/API/API_PutObject.html)       | PUT    | `/{bucket}/{key}`                       | Upload an object   |
| [GetObject](https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetObject.html)       | GET    | `/{bucket}/{key}`                       | Download an object |
| [HeadObject](https://docs.aws.amazon.com/AmazonS3/latest/API/API_HeadObject.html)     | HEAD   | `/{bucket}/{key}`                       | Get metadata       |
| [DeleteObject](https://docs.aws.amazon.com/AmazonS3/latest/API/API_DeleteObject.html) | DELETE | `/{bucket}/{key}`                       | Delete an object   |
| [CopyObject](https://docs.aws.amazon.com/AmazonS3/latest/API/API_CopyObject.html)     | PUT    | `/{bucket}/{key}?x-amz-copy-source=...` | Copy object        |

### 🟧 P1 – High

Once we get our object store doing basic authenticated bucket and object CRUD, we'll then focus on implementing multipart uploads, so we can upload large objects using multiple parallel requests, and then implementing IAM, covering bucket ACL and policy configuration, as well as the actual API to manage users, groups, policies, etc.

In the following sections, we cover the requests that we found to be the most relevant for each item.

#### Objects: Multipart Uploads

| S3 Action                                                                                                   | Method | Path                                           | Description                    |
| ----------------------------------------------------------------------------------------------------------- | ------ | ---------------------------------------------- | ------------------------------ |
| [ListMultipartUploads](https://docs.aws.amazon.com/AmazonS3/latest/API/API_ListMultipartUploads.html)       | GET    | `/{bucket}?uploads`                            | List ongoing multipart uploads |
| [CreateMultipartUpload](https://docs.aws.amazon.com/AmazonS3/latest/API/API_CreateMultipartUpload.html)     | POST   | `/{bucket}/{key}?uploads`                      | Initiate upload                |
| [UploadPart](https://docs.aws.amazon.com/AmazonS3/latest/API/API_UploadPart.html)                           | PUT    | `/{bucket}/{key}?partNumber={n}&uploadId={id}` | Upload part                    |
| [ListParts](https://docs.aws.amazon.com/AmazonS3/latest/API/API_ListParts.html)                             | GET    | `/{bucket}?uploadId={id}`                      | List parts                     |
| [CompleteMultipartUpload](https://docs.aws.amazon.com/AmazonS3/latest/API/API_CompleteMultipartUpload.html) | POST   | `/{bucket}/{key}?uploadId={id}`                | Complete upload                |
| [AbortMultipartUpload](https://docs.aws.amazon.com/AmazonS3/latest/API/API_AbortMultipartUpload.html)       | DELETE | `/{bucket}/{key}?uploadId={id}`                | Abort upload                   |

#### Buckets: Configuration

| S3 Action                                                                                                                                                                                                                                                                                     | Method         | Path                     | Description                   |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | ------------------------ | ----------------------------- |
| [GetBucketAcl](https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetBucketAcl.html) / [PutBucketAcl](https://docs.aws.amazon.com/AmazonS3/latest/API/API_PutBucketAcl.html)                                                                                                                 | GET/PUT        | `/{bucket}?acl`          | User/group permissions        |
| [GetBucketPolicy](https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetBucketPolicy.html) / [PutBucketPolicy](https://docs.aws.amazon.com/AmazonS3/latest/API/API_PutBucketPolicy.html) / [DeleteBucketPolicy](https://docs.aws.amazon.com/AmazonS3/latest/API/API_DeleteBucketPolicy.html) | GET/PUT/DELETE | `/{bucket}?policy`       | IAM-style JSON policy         |
| [GetBucketPolicyStatus](https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetBucketPolicyStatus.html)                                                                                                                                                                                       | GET            | `/{bucket}?policyStatus` | Check if the bucket is public |

#### IAM: Identity and Access Management

| IAM Action                                                                                            | Method | Path                          | Description                                                  |
| ----------------------------------------------------------------------------------------------------- | ------ | ----------------------------- | ------------------------------------------------------------ |
| [CreateUser](https://docs.aws.amazon.com/IAM/latest/APIReference/API_CreateUser.html)                 | POST   | `/?Action=CreateUser`         | Create user (no password / can't login)                      |
| [CreateLoginProfile](https://docs.aws.amazon.com/IAM/latest/APIReference/API_CreateLoginProfile.html) | POST   | `/?Action=CreateLoginProfile` | Set password for user (can login)                            |
| [CreateAccessKey](https://docs.aws.amazon.com/IAM/latest/APIReference/API_CreateAccessKey.html)       | POST   | `/?Action=CreateAccessKey`    | Create user access key (API only auth / can't use for login) |
| [ListUsers](https://docs.aws.amazon.com/IAM/latest/APIReference/API_ListUsers.html)                   | POST   | `/?Action=ListUsers`          | List users for a path prefix                                 |
| [GetUser](https://docs.aws.amazon.com/IAM/latest/APIReference/API_GetUser.html)                       | POST   | `/?Action=GetUser`            | Get user by name                                             |
| [DeleteUser](https://docs.aws.amazon.com/IAM/latest/APIReference/API_DeleteUser.html)                 | POST   | `/?Action=DeleteUser`         | Delete user by username                                      |
| [CreateGroup](https://docs.aws.amazon.com/IAM/latest/APIReference/API_CreateGroup.html)               | POST   | `/?Action=CreateGroup`        | Create group                                                 |
| [AddUserToGroup](https://docs.aws.amazon.com/IAM/latest/APIReference/API_AddUserToGroup.html)         | POST   | `/?Action=AddUserToGroup`     | Add user to group using names                                |
| [ListGroups](https://docs.aws.amazon.com/IAM/latest/APIReference/API_ListGroups.html)                 | POST   | `/?Action=ListGroups`         | List groups for a path prefix                                |
| [ListGroupsForUser](https://docs.aws.amazon.com/IAM/latest/APIReference/API_ListGroupsForUser.html)   | POST   | `/?Action=ListGroupsForUser`  | List groups for a given user                                 |
| [DeleteGroup](https://docs.aws.amazon.com/IAM/latest/APIReference/API_DeleteGroup.html)               | POST   | `/?Action=DeleteGroup`        | Delete group by name                                         |

### 🟨 P2 and 🟩 P3

Lower priority requests will include actions covering:

- Bucket versioning, encryption, object locking, and CORS.
- Bucket configurations covering lifecycle, replication, logging, notification, metrics, etc.
- Other object-related actions, like copying parts from existing objects during multipart uploads, tagging, setting retention policies, etc.
- Other IAM-related actions, like attaching global policies to users or groups, etc.

## Backend Programming Language

Long story short, the backend will be written in Go. As this is my first time coding in Go, I'll document a lot of what I learned over the past two weeks, and share it with you. First, I'll go through the decision making process that led me to pick Go over Rust—and no, there is no clear "winner", just a best option for my use case. Then, I'll cover several basic language features that are fundamental knowledge if you're starting to code in Go right now. Hopefully, this works a good primer to get you started in Go as well.

### Why Go?

When selecting the language to code the backend, it was between Go and Rust. To be honest, I looked at Go's syntax and it felt downright weird.

```go
if err := f(); err != nil {
	// ...
}

var map[string]int m
var y int

x := 10
y = 20
```

Two statements in the `if` condition? Why are map types declared this way? Are there two assignment operators? What?!

Rust felt complex, but not weird, at least to me. And, on the other hand, we all know how efficient tools coded in Rust can be—`uv`, `just`, `ripgrep`, `bat`, `fd`, `exa`, and the list goes one. So, at first, I was leaning towards Rust.

Why did I end up picking Go then? And do I regret it? No regrets here! Let me tell you why.

First, about the syntax, the weirdness goes away quite fast. Go is consistent. It's also minimalistic, and it flows quite well as you type.

The two statements in the `if` condition are just like the ones in a `for` loop: initialization and condition. Neat, right?

Regarding map declaration, because Go didn't implement generics originally, this is how to "return type" for maps is declared, and this is consistently followed for functions as well: `func GetMapItem(...) int`. Again, consistency!

Why the two assignment operators? Notice that `y` was declared, but `x` wasn't. When we use `:=`, we're declaring on assignment, and the compiler will determine the correct variable type at that stage. Conversely, you use `=` when you're assigning an existing variable. This keeps the code readable and minimalistic.

Also, while I won't cover these below, goroutines and channels are a native feature of the language, approaching concurrency in a beautiful way. Watch [Concurrency is not Parallelism by Rob Pike](https://youtu.be/oV9rvDllKEg) for a few cool examples!

The video above was recommended by the community on a Reddit post somewhere. I also had separate discussions on other topics, like `net/http` versus other web frameworks, so thanks for that! As a first impression, the community seems nice and helpful—there are a few tech savvy and professional members around as well. This is fundamental for the success of a language—Python is a good example of this.

Finally, let's talk tooling. Compilation time is the fastest I've ever seen. I can compile and run my whole backend faster than I can print the help message for [datalab](https://github.com/DataLabTechTV/datalab)'s `dlctl` command, which is written in Python! WAT! There is `go fmt` to format my code. I can install system commands directly using `go install`, add project dependencies using `go get`, or cleanup unused dependencies by using `go mod tidy`. These dependencies are all listed under [pkg.go.dev](https://pkg.go.dev/)—at least I haven't found any that aren't yet—with documentation available straight in Go's main domain.

What would have I lost by going the Rust route? More time learning the language, debugging the code, or interpreting compiler errors, more time waiting for the compiler to run, more time installing dependencies and reading their docs, etc. In essence, I would have traded development time for performance. There is a reason the compiler is so strict in Rust. It's doing so much upfront! And there is not garbage collector in Rust, but we have one in Go. However, development is not all about how efficient your code is, but also about how easily you can find coders for your language, how fast you can iterate over your code, and how fast you can deliver a working product.

The beauty of it all is that you can later refactor the slowest parts of your Go code to run in Rust, if you really can't squeeze any more performance out of Go. I'd say that most projects can't go wrong with Go. On the other hand, I'd consider carefully when to use Rust.

### Understanding the Basics

There are so many lessons or tutorials teaching Go, so I won't do that. Instead I'll cover a few of the basic language features by giving my impression on them. I want to capture more of how they feel, rather than delve deep into details. So I'll compare a bit with other languages I've used in the past, or cover details that usually don't come up that much, like function suffixes or other conventions.

#### Composable Types and Interfaces

Let's begin with the basics: composition!

You can define composed types as follows:

```go
type Response struct {
	statusCode int
	Message    string
}

type ErrorResponse struct {
	Response
	ErrorCode int
}

type UserSession struct {
	UserID string
	Token  string
}

type LoginSuccessResponse struct {
	Response
	Data UserSession
}
```

And it's similar for interfaces:

```go
type Responder interface {
	Body() string
	Log()
}

type ErrorResponder interface {
	Responder
}

type DataResponder interface {
	Responder
	Data() any
}
```

With these interface declarations, we can implement `Body()` and `Log()` globally, and also a specific `Log()` method for `ErrorResponder`, so that it logs using `ERROR` rather than `INFO`, while also including the `ErrorCode` in the log message.

If you're coming from Scala, this is a bit like traits, but without the need for `extends... with...`, which provides a weaker consistency syntax. If you're coming from Python, this is like multiple-inheritance—using mixins—but without initialization dilemmas:

- Do I use `super().__init__(**kwargs)`?
- Or just break composability and call `MixinA.__init__(arg1, kwarg1=...)`?

If you're coming from TypeScript, this is like the `&` operator for type composition, although for multiple-inheritance of methods it can get harder in TypeScript, as there's no native support there.

#### "Private" and "Public" Identifiers

In Go, identifier case matters. We use `camelCase` identifiers for private/unexported variables—accessible from inside the package—and `PascalCase` for public/exported variables—accessible from anywhere. Notice that unexported/exported is the preferred naming. There are really no private or public identifiers in Go.

In the example from the previous section, we kept `statusCode` as unexported, since it will be used to set the HTTP status code, but it won't be included in the response body, which brings us to he next section...

#### Serialization / Marshalling / Encoding

In Go, standard encoders, like `encoding/json`, `encoding/xml`, or `encoding/gob`, don't export `camelCase` variables—and, by the way, `gob` is to Go what `pickle` is to Python.

Another useful feature that Go provides is annotations besides `struct` fields. These are called tags. They are often used by encoding libraries to set the field's output name, default value, or exclusion rules.

Here's an example, where `UserID` will be encoded as `id` in the corresponding JSON object, and `Token`, despite being an exported field, will be excluded from encoding:

```json
type UserSession struct {
	UserID string `json:"id"`
	Token  string `json:"-"`
}
```

The encoding process will look something like this:

```go
session := UserSession{
	UserID: "034597ff-f083-41b0-aa6b-2cd1fea83a5d",
	Token: "5521f71d5ee3150fbba9ecbbfee7517feadffd65784f8f257a92bca6d56bf41b"
}
data, _ := json.Marshal(session)
fmt.Println(string(data))  // {"id": "034597ff-f083-41b0-aa6b-2cd1fea83a5d"}
```

Notice that, when calling `json.Marshal`, we discarded the second element of the return value, but we shouldn't have—this returns an error, which we should handle explicitly, but more on that below.

#### Enum-Like Constants

Another interesting feature in Go is `iota`, which we can use to produce enum-like constants with sequential integer values. It is recommended that these constants are typed explicitly.

Here's an example for an enum starting from 1:

```go
type Status int

const (
        _ = iota
        Starting Status
        Running
        Failed
        Success
)
```

Notice we assign `iota` to `_`, so we discard the initial value, which is zero. We could have used arithmetic as well:

```go
const Starting Status = iota + 1
```

If a function then takes an argument with type `Status`, we know it will refer to one of these constants:

```go
func StatusDescription(Status s) string {
	switch s {
	case Starting:
		return "Process is starting..."
	case Running:
		return "Process is running..."
	case Failed:
		return "Error: process has failed!"
	case Success:
		return "Success: process completed without errors."
	default
		return "[INVALID STATUS]"
	}
}
```

But, unlike enums in other languages, it can still take regular integers as arguments:

```go
StatusDescription(Starting)  // Process is starting...
StatusDescription(1000)      // [INVALID STATUS]
```

#### Defining Receiver Methods for Types

Using the previous example, we could have defined the description function as follows:

```go
func (s Status) Description() string {
	switch s {
	case Starting:
		return "Process is starting..."
	case Running:
		return "Process is running..."
	case Failed:
		return "Error: process has failed!"
	case Success:
		return "Success: process completed without errors."
	default:
		return "[INVALID STATUS]"
	}
}
```

Adding `(s Status)` before the function name turns it into a receiver method on `Status`—it's kinda like `self` on Python, but you can give it a custom name, and it works with pointers as well.

This way, we would call it as:

```go
Starting.Description()          // Process is starting...
Status(1000).Description()      // [INVALID STATUS]
```

#### Error Handling

No exceptions, only errors... Or panic! Ideally, you handle your errors, but sometimes you might want to print a message and exit immediately. You can do that by with:

```go
panic("Oh no!")
log.Fatal("Oh no! But logged.")
```

Of course handling the error is better—and don't just ignore it either. Here are a few insights into errors in Go:

- Messages should be lower case, for composability (i.e., combining error messages).
	- `errors.New` produces a basic error from a message
- You can use your own custom error types, as long as you implement the `error` interface, which is native to Go.
	- `errors.Is` checks for a custom error type.
	- `errors.As` casts and error into a custom error type.
	- There's no need for `errors.Is` when using `errors.As`, since it returns `false` when it doesn't match.
- Combining error messages is called wrapping and can be done with `fmt.Errorf` and `%w`.
- Even if there is `panic`, it can still be intercepted with `recover` when needed.

For example, we currently define the following custom error type for LabStore:

```go
type S3Error struct {
        XMLName    xml.Name `xml:"Error"`
        Code       string
        Message    string
        RequestId  string
        HostId     string
        StatusCode int `xml:"-"`
}

func (e *S3Error) Error() string {
        return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

err := &S3Error{
	Code:       "NotImplemented",
	Message:    "Operation not implemented",
	StatusCode: http.StatusNotImplemented,
}
```

We can wrap it as follows:

```go
fmt.Println(fmt.Errorf("server error: %w", err))
```

And handle it among other regular or custom errors as follows:

```go
func HandleError(w http.ResponseWriter, err error) {
	logrus.Errorf("Server error: %s", err)

	var s3Error *S3Error

	if errors.As(err, &s3Error) {
		WriteXML(w, s3Error.StatusCode, s3Error)
	} else {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}
```

If one of the libraries you use calls `panic`, but you want to handle it rather than exiting:

```go
func PanicRequest() {
	panic("oh no!")
}

func HandlePanic() {
	if err := recover(); err != nil {
		log.Printf("Panic recovered: %s", err)
	}
}

func PanicDemo() {
	defer HandlePanic()
	PanicRequest()
	fmt.Println("NOT PRINTED")
}

func main() {
	PanicDemo()
	fmt.Println("PRINTED")
}
```

When `panic` occurs inside `PanicDemo()`, the function will still return immediately, triggering `HandlePanic()`, which will `recover` from panic, log the error, and resume the program cleanly. This means that, any lines after `PanicDemo()` on `main()` will still run. This is useful for instance when you're building your own HTTP service and need to make sure a request that produces panic will never shutdown the whole server.

#### Printing and Logging Conventions

When using libraries that print messages, be it `fmt` or `logrus`, there are a few common suffixes (or lack thereof) that are used.

Here are a few examples based on `fmt` and `logrus`:

- No suffix — `fmt.Print`, `fmt.Sprint`, `logrus.Info`, `logrus.Debug`
	- Concatenates all arguments, **without spaces**, using `%v` to produce the string representation.
- `ln` suffix — `fmt.Println`, `fmt.Sprintln`, `logrus.Infoln`, `logrus.Debugln`
	- Concatenates all arguments, **separated by spaces**, using `%v` to produce the string representation.
- `f` suffix — `fmt.Printf`, `fmt.Sprintf`, `logrus.Infof`, `logrus.Debugf`
	- Takes a format string (e.g., `"Error: %v"`) and as many additional arguments as format verbs (one for `%v`, in this example).
- `Fn` suffix — `logrus.InfoFn`, `logrus.DebugFn`
	- Not a Go convent. This one is mostly specific to `logrus`, so that a helper function can be used to log more complex workflows by returning an array of string.

#### HTTP Requests with `net/http`

This one was hard on me. I started building LabStore with `net/http`, but, as I was feeling that routing was a bit too painful, I decided to search for a better alternative. And what better way to do so than to look for a good benchmark? The old scientific method—experimentation!

So I found this [2022 benchmark](https://github.com/smallnest/go-web-framework-benchmark), where [Fiber](https://gofiber.io/) was the clear all-around winner. It was able to handle 28% more requests per second than `net/http`, while allocating 87.5% less memory, for 5000 concurrent requests. It really stood ou on that benchmark! Since it was based on a different library called [fasthttp](https://github.com/valyala/fasthttp), and not `net/http`, like most of the other frameworks, it was settled, I was going to migrate to `fiber`.

Before taking a few days break, did the migration, and it was working fine. Then, as I was resting, I was browsing the [r/golang](https://www.reddit.com/r/golang/) subreddit and found a post of someone trying to find a popular web framework to use. The most upvoted comment suggested using `net/http`, so I decided to add up to the discussion and talk about `fiber`, as I had just successfully done the migration a couple of days back. This led to a long discussion, culminating in an upset stomach, because I felt I had made a mistake by jumping the gun on migrating out of `net/http`.

Even though `fiber` had better numbers on benchmarks, my main reason to switch was because I needed a router, which I thought needed to be a third-party library, like [httprouter](https://pkg.go.dev/github.com/julienschmidt/httprouter), but I quickly realized that `net/http` has its own router, called `http.ServeMux`. Now, I avoid premature optimizations, after many lessons learned in the past. More often than not, the best optimizations are done by refactoring your own code for performance. Of course the libraries you use and the language your software is written with matter, but not as much as your implementation.

That was enough to convince me I had wasted my time migrating, but not enough to convince me I was not better of with `fiber`—after all, it was more efficient. Still, annoyed at my mistake, I decided to look for more up-to-date benchmarks. After all, 3 years had passed and a lot could have changed. So I found a [2024 benchmark](https://medium.com/deno-the-complete-reference/go-gin-vs-fiber-vs-echo-how-much-performance-difference-is-really-there-for-a-real-world-use-1ed29d6a3e4d) where they compared Fiber with Gin and Echo, both of which only slightly less efficiently than `net/http`, as they add features on top of it. While Fiber was still the winner in this benchmark, this time the numbers showed a smaller improvement of 5-6% in requests per second and of 14-24% less allocated memory.

So, being Fiber still the winner, albeit by a lower margin on the 2024 benchmark, why did I go back to `net/http`? It all came down to RFC compliance. Since we're building an object store, which relies heavily on correctness to compute its authorization header based on SigV4, we couldn't risk that a non-compliant `fasthttp` implementation broke our backend. Furthermore, by staying with `net/http` we are able to tap into the ecosystem for other interoperable libraries, if we so require. And any optimizations to `net/http` in future versions of Go will also reflect in improved performance for our code. On Reddit, someone claimed to handle 100k requests per second with `net/http`, so I see no reason to be worried about my choice.

I ended up migrating back to `net/http`, using `http.ServeMux` as my router, and it worked fine. Bucket and object routes, however, required URL normalization by trimming the last slash. For example, to ensure both of these routes work:

```go
mux.Handle("GET /{bucket}", middleware.WithIAM(iam.ListBucket, http.HandlerFunc(bucket.ListObjectsHandler)))

mux.Handle("GET /{bucket}/{key...}", middleware.WithIAM(iam.GetObject, http.HandlerFunc(object.GetObjectHandler)))
```

Without the following middleware, only the second route would be matched, as `{key...}` can match an empty path:

```go
func NormalizeMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			r.URL.Path = strings.TrimRight(r.URL.Path, "/")
		}
		next.ServeHTTP(w, r)
	})
}
```

We'll likely need to update this with a more elaborate logic in the future, as query parameters come into play, but for now it works. And, of course, we can always replace `http.ServeMux` with a better multiplexer, and we have a wide list to pick from, since we are now working within the ecosystem.

If you're interested in learning more about `net/http`, I suggest you take a look at the following video by Dreams of Code on YouTube: [The standard library now has all you need for advanced routing in Go.](https://www.youtube.com/watch?v=H7tbjKFSg58). This helped me get started quite easily.

## The LabStore Project

Introducing LabStore, the fully open source, S3-compatible object store, built for engineers who value freedom and flexibility. Our goal is to give back to the community the freedom that others took away—multiple users, groups, and access keys, as well as the ability to set policies, manage versioning, object locking, etc.

Long term, we also aim to provide a service that runs on lower-end hardware, so that self-hosters can enjoy running LabStore on their limited memory NAS or Raspberry Pi, or so that devs don't waste local resources while building on top of an object store.

LabStore is for hobbyists and for prototyping, and it's also a learning experiment for us, its developers, but there's room to adapt and evolve, as the community sees fit, and opportunity arises. If it makes sense do do more, we'll do more.

It's still too early to tell what LabStore will become, as it's not even cooking in the oven yet—the dough is still being prepared. Once it's fully baked, we will see! 😎

For now, let's take a look at the first steps we've taken to make this work.

### Project Management on GitHub

Since it's not just me working on this project, I've setup a GitHub Org as neutral territory, where I can collab with a friend who will be working on a web frontend for LabStore. The org is called [IllumiKnowLabs](https://github.com/IllumiKnowLabs), where you can find the repo for [LabStore](https://github.com/IllumiKnowLabs/labstore). It's perhaps too soon to open issues, but feel free to do so—just keep in mind it won't be a priority at this time.

If you're curious, we're using GitHub Projects and a Kanban board to manage our issues and workflow. We keep separate release branches for backend and web frontend, with PRs to `main` requiring peer approval.

### Monorepo Structure

We do all work in a monorepo that the whole project shares. We provide a `Makefile` for basic building tasks, and a `justfile` is being prepared to help with other tasks as well.

Here's an overview of the target project structure:

```
labstore/
├── backend/
├── web/
├── cli/
├── shared/
├── infra/
├── docs/
├── bin/
├── Makefile
├── justfile
├── LICENSE
├── CONTRIBUTING.md
└── README.md
```

- `backend/` – Go project with the backend web services
- `web/` – Svelte web frontend that will eventually integrate with the backend
- `cli/` – entry-point command line tool to manage the whole application
- `shared/` – common resources, like assets, specs, etc. (no packages here)
- `infra/` – CI/CD or infrastructure configurations (we're currently using it to run an external S3 object store for web frontend testing)
- `docs/` – markdown documentation (mostly used to support development)
- `bin/` – user-facing binaries or scripts (currently just holds the backend binary, `labstore-server`)
- `Makefile` – build and run backend and frontend
- `justfile` – entry point to other project-specific `justfile` (e.g., `just backend` or `just infra`)
- `LICENSE` – Apache License 2.0 (for community freedom and developer protection)
- `CONTRIBUTING.md` – overall project contributing rules (working document)
- `README.md` – empty so far (will contain instructions on how to deploy, run and use LabStore)

### Manual Testing and Benchmarking

So far, we haven't implemented any tests or benchmarks in Go, although I'd love to do that, and it will be a requirement for opening the project to external contributions as well.

We're relying on manual testing so far—it is what it is, time and resources are limited. We're using [warp](https://github.com/minio/warp), by MinIO, to test performance, which also helped us debug SigV4, and we're using [mc](https://github.com/minio/mc), [rclone](https://rclone.org/s3/), and [s5cmd](https://github.com/peak/s5cmd) to implement basic CLI testing commands using `just` (so far, we only test file copying).

### Final Remarks

And this is it, the beginning of IllumiKnowLabs and LabStore. We hope this will be ground-zero for many learning projects and collaborations, and for some cool tools in the spirit of open source! Drop us a line on our [discussion forum](https://github.com/IllumiKnowLabs/labstore/discussions) for LabStore, if you have something to share, or use the regular [DataLabTechTV](https://datalabtechtv.com/) social channels, and I'll make sure to convey any message to the team.
