---
title: "LabStore - Part 2 - Building an Object Store in Go: Authenticating with SigV4"
description: Let's learn all about the inner workings of SigV4, used in S3-compatible object stores, to authenticate requests.
date: 2025-11-25T12:00:00+0100
categories: [Software Engineering]
tags: [s3, go, object-store, aws, sigv4, authentication, video]
---

## Summary

Let's learn all about the inner workings of AWS Signature Version 4 (SigV4), used in Amazon Simple Storage Service (AWS S3), or any S3-compatible object store, to authenticate requests. We'll learn all about signature verification for standard single chunk requests, as well as for streaming multiple chunk requests.

Follow this series with IllumiKnow Labs, and let's see where this journey takes us. Hopefully you'll learn a lot along the way!

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

## Implementing SigV4

We're going to discuss how to implement AWS Signature Version 4, used in Amazon Simple Storage Service (AWS S3), or any S3-compatible object store, to authenticate requests. This takes a secret key—either associated with an access key or based on a user password—along with request-specific elements, using them to compute a chain of "signed hashes" that will produce the final signature. This process is called [HMAC](https://en.wikipedia.org/wiki/HMAC) (Hash-based Message Authentication Code) and, for SigV4, we use SHA256 to compute the hashes. The final signature should match the one computed and sent by the client in the `Authorization` header.

Each request to an S3-compatible object store is signed using SigV4 and, for `PUT /{bucket}/{key...}` requests, where uploads are streamed in multiple chunks, each chunk is also signed in a particular way—it's almost like a blockchain, where a chunk is signed based on the previous chunk. It first computes the seed signature using the standard SigV4 algorithm, signing the first chunk with that seed as the previous signature. The process is then repeated for the following chunks, always using the previous chunk's signature as a part of the hash. Streaming always ends with a signed empty chunk (i.e., zero-size).

Below we introduce the specification, linking to the official documentation—which is all that you really need to implement SigV4—and we'll discuss our Go-based implementation, as a part of [LabStore](https://github.com/IllumiKnowLabs/labstore).

## The Spec

First of all, remember to trust the spec! See the docs for the standard single chunk SigV4 algorithm [here](https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html) and for the streaming multiple chunks SigV4 extension [here](https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-streaming.html).

While debugging, you'll need to check most of your code manually, looking at values used to compute the hash, either via logging or breakpoints, because the output is either a match or not. There's a high dependency on code reading here and, as far as I know, this is the only way to debug this—if you have any additional tips, please do share on [Discord](https://discord.gg/6xpe827ANZ).

Make sure you have canonicalized everything correctly, that there are no missing or additional spaces or new lines that shouldn't be there—true story, took me a while to find and fix an extra `\n`—or that the credentials you're using are correct and were properly set or loaded during server initialization. I have tested this using [mc](https://github.com/minio/mc), [rclone](https://rclone.org/s3/) and [s5cmd](https://github.com/peak/s5cmd), and they all respect the spec as expected, so, if you find an issue, it's most likely on your side.

### Single Chunk

#### Canonical Request

A canonical request will look like this:

```
<METHOD>\n
<PATH>\n
<QUERY_STRING>\n
<HEADERS>\n
<SIGNED_HEADERS>\n
<BODY_SHA256>
```

- `METHOD` (HTTP Verb) – HTTP method (GET, PUT, POST, etc.)
- `PATH` (Canonical URI) – URL encoded path (i.e. split by `/` and URL encoded)
- `QUERY_STRING` (Canonical Query String) – Single line with query parameters, with URL encoded keys and values, following the same order as the original request
- `HEADERS` (Canonical Headers) – lowercase header name and trimmed value, separated by `:`, no spaces, and ending on a `\n`.
- `SIGNED_HEADERS` (Signed Headers) – list of header names used in signing, separated by `;`
-  `BODY_HASH` (Hashed Payload) – SHA256 hex string for the body content—notice that there is no `\n` here—or `UNSIGNED-PAYLOAD` or `STREAMING-AWS4-HMAC-SHA256-PAYLOAD`

For example:

```
PUT
/bucket/my/path/filename%282%29.txt
key1=value1&key2=value2
x-amz-content-sha256:STREAMING-AWS4-HMAC-SHA256-PAYLOAD
x-amz-date:20251119T103929Z
x-amz-decoded-content-length:10485760

host;x-amz-content-sha256;x-amz-date;x-amz-decoded-content-length
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

#### StringToSign

We then build a string to sign, containing a few request headers and the canonical request:

```
AWS4-HMAC-SHA256\n
<ISO8601_TIMESTAMP>\n
<SCOPE>\n
<CANONICAL_REQUEST_SHA256>
```

- `"AWS4-HMAC-SHA256"` – used to specify the HMAC hashing algorithm (SHA256)
- `ISO8601_TIMESTAMP` – timestamp from the original request—here, you might validate the timestamp to make sure that it matches up to the day, hour or minute, but we don't (we simply reuse the one from the request)
- `SCOPE` – date, region and service identifier string in the format `<YYMMDD>/<REGION>/<SERVICE>/aws4_request`
- `CANONICAL_REQUEST_SHA256` – SHA256 hex string for the canonical request string—notice that there is no `\n` here

For example:

```
AWS4-HMAC-SHA256
20251119T103928Z
20251118/eu-west-1/s3/aws4_request
7c7b924298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

#### Signature

The final signature is the calculated using HMAC-SHA256 based on:

- Secret key
- Scope date (`YYMMDD`)
- Scope region (e.g., `eu-west-1`)
- Scope service (usually `s3`)
- Scope request type (`aws4_request`)
- String to sign (`STRING_TO_SIGN`)

Directly from the docs, this is how the chain of hashes is computed using `HMAC-SHA256(key, value)`:

```
DateKey = HMAC-SHA256("AWS4<SECRET_KEY>", "<SCOPE_DATE>")
DateRegionKey = HMAC-SHA256(DateKey, "<SCOPE_REGION>")
DateRegionServiceKey = HMAC-SHA256(DateRegionKey, "<SCOPE_SERVICE>")
SigningKey = HMAC-SHA256(DateRegionServiceKey, "aws4_request")
Signature = HMAC-SHA256(SigningKey, "<STRING_TO_SIGN>")
```

Notice that our `SigningKey` derives from the secret key and scope. We use it to sign the previously computed `STRING_TO_SIGN`, as described on the previous section.

And that's it. Most requests only need to implement this signature method. Once you're done recomputing the signature, you simply compare it with the one provided by the client and let the request through if both the received and recomputed signatures match.

### Multiple Chunks

When we stream objects in multiple chunks, namely during upload requests like `PUT /{bucket}/{key...}`, we sign the request using the standard single chunk SigV4 algorithm we described in the previous section, but then we need to sign each individual request, chaining the signatures over sequential chunks.

Most of the code used to implement the single chunk version can be reused here, with the exception of the string to sign, which is specific to chunks. A streaming request will be identified by a special payload hash `STREAMING-AWS4-HMAC-SHA256-PAYLOAD` (also set as the value for header `x-amz-content-sha256`).

We begin by computing the standard SigV4 signature as usual, and when `STREAMING-AWS4-HMAC-SHA256-PAYLOAD` is encountered, the body must be processed differently (i.e., signing or validating the signature for each chunk, depending on whether we're doing this client-side or server-side, respectively). We implement this server-side, in Go, as a custom body reader.

Each chunk has a header with the hex value of bytes to read, along with a signature. Here's an example from the docs for a chunk of size 0x10000 bytes (65536 bytes):

```
10000;chunk-signature=ad80c730a21e5b8d04586a2213dd63b9a0e99e0e2307b0ade35a65485a288648
<65536-bytes>
```

#### StringToSign

Each chunk's string to sign will be built as:

```
AWS4-HMAC-SHA256-PAYLOAD\n
<ISO8601_TIMESTAMP>\n
<SCOPE>\n
<PREVIOUS_SIGNATURE>\n
<EMPTY_STRING_SHA256>\n
<CHUNK_DATA_SHA256>
```

- `"AWS4-HMAC-SHA256-PAYLOAD"` – used to specify the HMAC hashing algorithm (SHA256) for a chunk (notice the `PAYLOAD` suffix)
- `ISO8601_TIMESTAMP` – timestamp from the original request—here, you might validate the timestamp to make sure that it matches up to the day, hour or minute, but we don't (we simply reuse the one from the request)
- `SCOPE` – date, region and service identifier string in the format `<YYMMDD>/<REGION>/<SERVICE>/aws4_request`
- `PREVIOUS_SIGNATURE` – signature for the previous chunk, or the seed signature from the standard SigV4 signature (first one computed, like for any other request)
- `EMPTY_STRING_SHA256` – SHA256 for an empty string (don't ask me why)
- `CHUNK_DATA_SHA256` – SHA256 for the chunk data—notice that there is no `\n` here

For example:

For example:

```txt
AWS4-HMAC-SHA256-PAYLOAD
20251119T103928Z
20251118/eu-west-1/s3/aws4_request
3f256085d50823c4971f2aaa1be1816e9fa5c948352bbbbc81762dd0f84cc237
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
6480a50b3148fb7b68bf1c3bfdf616a507cf44cf536cdda6e47f0b4c5cb22876
```

Client-side, don't forget to add a zero-size chunk to mark the end of the stream. Likewise, server-side, we must look for a chunk header with size zero, so that we know the stream is over.

Apart from parsing the chunks as individual units and having to build a custom string to sign, we can still use the same computation approach as described in the <a href="#signature">Signature</a> section of the standard single chunk approach.

## Class Diagrams

Having described the inner-workings of SigV4, we now detail our particular implementation using on Go and its `net/http` standard library.

We first provide class diagrams that cover the most relevant package-level functions for `auth`, as well as the types, receiver methods, and functions created to implement SigV4 for single chunk and multiple chunk scenarios. We close with a sequence diagram illustrating the whole procedure.

### Package-Level Functions

<pre class="mermaid">
---
title: AWS Signature Version 4 (SigV4) – Package-Level Functions (auth/*.go)
---
classDiagram
	class auth {
		+VerifySigV4(r *http.Request) :&nbsp;(*sigV4Result, error)
		+NewSigV4ChunkedReader(r *http.Request, res *sigV4Result) *sigV4ChunkedReader
		-newSigV4Request(r *http.Request) :&nbsp;(*sigV4Request, error)
		-newSigV4Authorization(authorization string) :&nbsp;(*sigV4Authorization, error)
		-newSigV4Credential(credential string) :&nbsp;(*sigV4Credential, error)
		-computeSignature(cred *SigV4Credential, stringToSign string) :&nbsp;(string, error)
	}
</pre>

We implement signature verification as a `net/http` middleware ([middleware.AuthMiddleware](https://github.com/IllumiKnowLabs/labstore/blob/75eb50e0b0cbb7477e09ee3a895774b9aaf0cc48/backend/internal/middleware/auth.go)). Each request to the server will go through this middleware, which calls `VerifySigV4`—this is the standard SigV4 algorithm.

Upon entry on `VerifySigV4`, the `http.Request` will be parsed using `newSigV4Request`—this will call `newSigV4Authorization`, which in turn will call `newSigV4Credential`. Other functions will also be called internally to build the `canonicalURI`, the `canonicalQueryString`, and the `canonicalHeaders`. Other fields will be loaded from HTTP headers—the `timestamp` from `X-Amz-Date`, and the `payloadHash` from `X-Amz-Content-SHA256`.

This will produce a `sigV4Request` instance, from which we will run the verification process.

Check out [auth/auth.go](https://github.com/IllumiKnowLabs/labstore/blob/75eb50e0b0cbb7477e09ee3a895774b9aaf0cc48/backend/internal/auth/auth.go) for more details.

### Single Chunk Signature Types

<pre class="mermaid">
---
title: AWS Signature Version 4 (SigV4) – Single Chunk (auth/signature.go)
---
classDiagram
	class sigV4Request {
		-method : string
		-canonicalURI : string
		-canonicalQueryString : string
		-canonicalHeaders : map[string]string
		-authorization : *sigV4Authorization
		-timestamp : string
		-payloadHash : string

		-validatePayloadHash(r *http.Request) error
		-validateSignature() :&nbsp;(*SigV4Result, error)
		-buildCanonicalRequest() string
		-buildStringToSign() string
	}

	class sigV4Authorization {
		-credential : *sigV4Credential
		-signedHeaders : []string
		-signature : string
	}

	class sigV4Credential {
		+AccessKey : string
		-secretKey : string
		-scope : string
	}

	class sigV4Result {
		+Credential : *sigV4Credential
		+Signature : string
		+Timestamp : string
		+IsStreaming : bool
	}

	sigV4Request --> sigV4Authorization
	sigV4Authorization --> sigV4Credential
	sigV4Result --> sigV4Credential
</pre>

Here you can see the types produced by the constructors in the previous section. The only one missing is `sigV4Result`, which is produced by `sigV4Request.validateSignature()`.

Before validating the signature, we also validate the payload hash using `sigV4Request.validatePayloadHash()`, which works as an early fail for invalid payload hashes. However, this is not a part of SigV4, and it will likely be removed in the future to improve performance—this is not required, since overall validation already includes the payload hash anyway.

The remaining methods on `sigV4Request` are called from `validateSignature`, `buildStringToSign` directly, and `buildCanonicalRequest` from `buildStringToSign`.

The parsed `sigV4Credential` instance is also returned on the `sigV4Result`, as it is used to set the active access key on the request context. The `sigV4Result` instance is also used to check for an upcoming stream with multiple chunks and passed to the `sigV4ChunkedReader`, which is described below.

Check out [auth/signature.go](https://github.com/IllumiKnowLabs/labstore/blob/75eb50e0b0cbb7477e09ee3a895774b9aaf0cc48/backend/internal/auth/signature.go) for more details.

### Multiple Chunks Signature Types

<pre class="mermaid">
---
title: AWS Signature Version 4 (SigV4) – Multiple Chunks (auth/streaming.go)
---
classDiagram
	class sigV4ChunkedReader {
		-body : io.ReadCloser
		-prevSig : string
		-credential : *SigV4Credential
		-timestamp : string
		-reader: *bufio.Reader
		-header: *SigV4ChunkHeader
		-data: []byte

		+Read(buf []byte) :&nbsp;(int, error)
		+Close() error
		-readChunkHeader() error
		-readChunkData() error
		-readTrailingCRLF() error
		-verifyChunkSigV4() error
		-buildChunkStringToSign() string
	}

	class sigV4ChunkHeader {
		-size : int
		-signature : string
	}

	note for sigV4Credential "From auth/signature.go – returned
		after calculating the seed signature."
	class sigV4Credential {
		+AccessKey : string
		-secretKey : string
		-scope : string
	}

	sigV4ChunkedReader --> sigV4ChunkHeader
	sigV4ChunkedReader --> sigV4Credential
</pre>

Whenever the standard SigV4 algorithm returns a `sigV4Result` instance with `IsStreaming` set to `true`, we replace the body of the `r *http.Request`—`r.Body`—with a `sigV4ChunkedReader`, which implements the `io.ReadCloser` interface, just like `r.Body`. This implements a custom `Read()` method that iterates over individual chunks, verifying their signature, and returning the pure bytes for the object being streamed (usually uploaded).

This means that `Read()` will `readChunkHeader()`, which contains the hexadecimal size of the chunk data, as well as the signature to validate. Then we `readChunkData()` and `readTrailingCRLF()`, calling `verifyChunkSigV4()` to validate the signature. The previous signature (`prevSig`) will be set for the next chunk—for the first chunk, this is set to the standard SigV4 signature, also called seed signature. Once the chunk header returns a size zero, we know the stream has ended and we terminate the the reading process by returning the number of bytes read and a `nil` error.

Notice that the `Read()` method also needs to handle partial reads, for when the `buf []byte` parameter is smaller than the chunk body.

Check out [auth/streaming.go](https://github.com/IllumiKnowLabs/labstore/blob/75eb50e0b0cbb7477e09ee3a895774b9aaf0cc48/backend/internal/auth/streaming.go) for more details.

## Sequence Diagram

The sequence diagram below serves to illustrate the process we described in the previous sections. We refrain from including too much detail, and focus on the top-level logic. Inspect the source code linked across the previous sections for further detail.

This should, however, provide enough detail to make it clear how the SigV4 end-to-end verification process works. The example below is for a `PUT` request, this way covering both the standard algorithm for single chunks, and the streaming algorithm for multiple chunks.

<div class="of-narrow">
<pre class="mermaid">
---
title: AWS Signature Version 4 (SigV4) – PutObject
---
sequenceDiagram
	autonumber
	actor Client
	Client->>router/router.go: PUT /{bucket}/{keys...}
	router/router.go->>middleware/auth.go: r *http.Request
	critical Standard SigV4
		middleware/auth.go->>auth/signature.go: auth.VerifySigV4(r)
		auth/signature.go->>auth/signature.go: req ← newSigV4Request(r)
		auth/signature.go->>auth/signature.go: req.validatePayloadHash()
		auth/signature.go->>auth/signature.go: res ← req.validateSignature()
		auth/signature.go->>middleware/auth.go: res *sigV4Result
	option res.IsStreaming
		middleware/auth.go->>auth/streaming.go: auth.NewSigV4ChunkedReader(r, res)
		auth/streaming.go->>middleware/auth.go: r.Body ← *auth.sigV4ChunkReader
	option No errors
		middleware/auth.go->>middleware/auth.go: Add access key to request context
	end
	middleware/auth.go->>router/router.go: Next handler
	router/router.go->>Client: Response
</pre>
</div>

We begin from the client (CLI, web, etc.). The request is handled by our `http.ServeMux` router and sent to our `middleware.AuthMiddleware`. This calls the `auth` package, which handles verification, either returning an error along the way or calling the next handler across the middleware chain, until the client receives a response—this response can obviously be the result of an `http.Error` call.

And that's how you implement SigV4 in Go! :-)
