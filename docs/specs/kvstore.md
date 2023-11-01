# Bagger Cluster State Management

Bagger clusters require state synchronization regarding some critical data including indexes, partition dimensions, and servermaps.  Additionally whether storage nodes are online or offline will be handled on an advisory and administrative basis in this state management system.  This allows for orderly management of Bagger components from single points of authority, easier automation and more.  Future versions are likely to add more functionality to this system.

## Basic Architecture

The Lenkwerk database in PostgreSQL is the primary database of record for cluster state.  The cluster is expected to become eventually consistent with the cluster state recorded   Configuration tools interact with the Lenkwerk database.

### The Lenkwerk Agent

The Lenkwerk Agent listens to a logical replication stream from the Lenkwerk database and replicates these changes to a distributed key-value store which supports notifications.  From the agent's perspective, the key-value store is just that, a key-value store.  The Agent doesn't know or care what store it is.

### The Key-Value Store

The Key-Value Store stores the configuration data for the cluster in key/value format.  The format involves keyspace in a tree delimited by '/' characters and values of Lenkwerk records serialized as JSON.  This store must be capable of three basic operations:

- Read a specified key
- Write a specified key
- Watch for notifications for a range of keys. 

In theory any key-value store which is capable of doing this can be supported.  It would be possible to write drivers for anything from Redis to PostgreSQL.

## The Key/Value Store API

The Key-Value Store driver has to present four functions: kvconnect, kvread, kvwrite, and kvwatch.

### kvconnect(hashref config)

This function takes in a hashref and returns a new object of the type of the data store whose methods are kvread, kvwrite, and kvwatch.  The hashref contains arbitrary configuration information for the kvstore driver type including, for example, host and port to connect to.

### kvread(string key)

Reads the string key and returns the json value.

### kvwrite (string key, string value)

Writes the key/value combination to the database.  Returns true if success, false if failure

### kvwatch (subroutine callback)

Watches the range of keys used by Bagger and executes the callback with the arguments of (key, value) for every key changed.

## Supported Backends

### Etcd

Right now, etcd is the only backend supported.  More backends could be written fairly easily if needed.

## Backends that Could Be Written in the Future

Currently the following backends are believed to be feasible:

 - Zookeeper
 - PostgreSQL
 - Redis

## Current Limitations

Currently only one lenkwerk agent and one key-value store are supported.  In theory fanning out would not be a problem but this does have limitations on what can be done.  Some minor development would would be required to allow multiple agents and key-value stores.  This needs some discussion before such would be supported.
