# Bagger System Spec
---------------

Bagger is a massive-scale semi-structured data store aimed at high-velocity,
high-volume data.  It is named after Bagger 293 and Bagger 288, two of the
largest land machines ever built, which are used in massive-scale coal mining
operations.  Bagger is a reference not only to the size but also the throughput
of these massive machines.

Bagger's structure is fairly simple.  There is a superstructure of tooling
and support structure including a metadata database which also handles basic
coordination regarding data ingestion.

The next important component is the schaufelrad (literally "shovel wheel" in
German, but usually translated as bucketwheel in English) which ingests large
amounts of data from Kafka into storage nodes.

Next the storage nodes hold data for a defined period of time in easily
queryable form in PostgreSQL tables.  These are then held for a retention
period, and then discarded.

The query proxy then allows user queries to search the data on the storage
nodes for relevant patterns.  This will then stream results over HTTP with
chunked encoding to frontends which can display it.

This document collects the general requirements for the system as well as the
general components.  Each component will then have a more detailed
specificatoin document of its own.

## Overall Functional Requirements

Bagger, to be competitive, must be larger and cheaper than ElasticSearch.
Initial versions are unlikely to have feature parity but are able to scale
cheaply and well into the range of tens of petabytes.  Larger clusters may
be possible with some reworking of the control flow, and scales on the cloud
are likely to be lower than those experienced on dedicated hosts.

Bagger has to be able to provide ingestion at very high rates (hundreds of
thousands or even millions of messages per second) and that data has to be
semi-structured though with some relevant structure definition.

Finally Bagger must be queryable.  It must be possible to identify records
by range of time and matching values of one form or another.  Ranges of other
values may be supported at some point too but this may require some design
work.

Initially Bagger may support a replication factor of two only, but in future
versions, the replication factor needs to be configurable, and it should be
able to be changed when creating new "generations" of the server map.

## Specification of messages coming in

Inbound messages must be in JSON format and must contain a timestamp in a
top-level but user-specifiable field.  It must also contain a number of
user-specified fields which allow the Bagger trigers to determine the
categorization of data for storage and indexing purposes.  These are called
dimension fields and Bagger will partition by them (see below).

The total known values for the dimension columns MUST be known ahead of time
and configured in the Bagger software for partitioning reasons.  Additionally
these will become the basis for index-oriented access as well.

A common set of indexed values should be provided for easier querying. As the
project develops, we will add the ability to define additional fields for each
reporting dimension value so that the indexes can be more finely tuned around
business needs.

Bagger makes no demands on the inbound data other than the fact that partition
dimension fields and timestamp field MUST be present and that they must be 
text fields.

## Schaufelrad Requirements

The Schaufelrad (or collection of Schaufel instances) MUST be able to connect
to at least 2 PostgreSQL instances (and when we support larger replication
factors, we would need to make sure that Schaufel supports this as well.

Schaufel currently has very specific requirements of the database schema which
are built into it based on the Adjust GmbH precursor to our project.  These may
eventually need to change.

Schaufel MAY be able to flatten data, providing for a flatter, more rigidly
structured table for indexed values.

## Bagger Data Node Requirements

The bagger data nodes MUST be able to store data for a defined lenth of time 
(which can be shortened if space is running out), and in a manner which allows
both efficient storage and reasonable query performance.

The data nodes MUST also be able to partition data by the partitioning values
provided in the configuration, and also by time bucket (by default, hours).

The time bucket MAY be assumed to be static during the life of the cluster.

The data storage MUST include both the JSON document as is (or at least in
a form where it can be reconstituted, though dupicate keys MAY be unsupported.

## General Query Proxy Requirements

The query proxy would accept from the front-end a set of query criteria and
generate SQL queries against all relevant Bagger data nodes from these.

Values that the query proxy MUST receive from the frontend are:

  - A value for each partition dimension except timestamp
  - A time range for the query
  - Additional index-based values to search for
  - Freeform JSON key/value combinations (equality only will be supported)

These values would come in over an HTTP request, following restful conventions
(though ReST itself is probably not applicable to this exact workload).

The query proxy would then reply by restreaming relevant records back to the
frontend as they come in. This MUST be done with HTTP chunked encoding and
the proxy must NOT wait for the total result set to arrive before sending it
to the client.

The query proxy MUST also be able to determine cluster state as needed for the
operation of the frontend and pass this information along in a restful manner.

## General Frontend Requirements

The query frintend MUST be able to determine the configuration state of the
cluster, determine partition and index columns, and display those for search.

The frontend MUST also get this information from the query proxy over a
specified web service interface.  It must then display search criteria 
and send back a request for data on the web service interface later specified.

The frontend MUST then be able to display the results received as they come in.

