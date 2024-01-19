# Query Proxy Specification

The query proxy component provides the primary method for retrieving stored
semi-structured data from Bagger.  This spec is intended to be implementation-
agnostic and therefore provide a basis for future versions and technical 
discussions.

## Version

1.0

## Role of Query Proxy in Bagger

The query proxy provides a critical component for accessing data on the Bagger 
data nodes.  Clients, including the frontend, will interact with supporting
infrastructure to get information needed to form queries.  These endpoints can
also be proxied by common components, such as nginx.  However the query proxy
itself only addresses data queries for bagger itself.

## Query Proxy Endpoints

### Authentication

The query proxy itself will respect JWT-based authentication from external 
providers.  This can be an external provider like Auth0 or Okta, or an internal
provider that can be enabled in the PostgREST support subsystem.

The user specified in the JWT will be used to look up per-user configuration
when this is implemented.  Such will be transparent to the query proxy itself.

V1 is unlikely to implement any such per-user configuration.

### Bagger Queries

The /api/v1.0/query end point provides the query  and returns a result which 
will be sent using `Transfer-Encoding: chunked` as the result sets may be very 
large.

The result document for v1 is very simple: an array of documents with no 
metadata attached.  Future versions may add metadata and change the output
format accordingly which is a major reason the api endpoint is versioned.

## Query Proxy API

In version 1.0, the query will expect only a GET operation with arguments in
the query string itself.  The query string itself must be submitted as a UTF-8
string with URL encoding where appropriate.

A range operator of .. is supported in values, and individual values which
contain double quotes or that operator must be double quoted, with any internal
double quotes being doubled.  If multiple discrete values are accepted, the
query parameter can be specified multiple times.

### Example

GET /api/v1.0/query?time=2024-01-01T03:02:00..2024-01-01T05:02:00&service=myapp&service=callbacks&customerid=123&payload=%22%22%22foo%22..%22bar..%22

This selects:

 - items from 2024-01-01T03:02:00 to 2024-01-01T05:02:00
 - Of the myapp and callback services
 - For customer 123
 - With payload field values running from `"foo` to `bar..`

## In process errors

If errors occur after streaming has started, these MUST be passed along to the
client.  These will be passed along as a JSON document with the following
fields:

 - Error: true
 - SQLSTATE: The SQL State of the connection or a specified application state
 - Message:  The error message as returned by the database or application

## Configuration

The query proxy will accept the following configuration values in Lenkwerk:

 - `connections_per_request` Int, number of data db connections to use/request
 - `disable_seq_scan` Bool, If set and true, check plans and return errors
 - `require_time` Bool, if set and true, require queries to provide time ranges

