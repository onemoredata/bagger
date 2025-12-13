# Bagger Schute

`Schute` is the *intake* of `Bagger`, consisting of the partition
management and data routing functionality.


## Requirements

At this point (prototyping and proof of concept) `Schute` requires the
separate [jsonpointer](https://github.com/wieck/jsonpointer) extension.

**Note:** When the routing trigger gets implemented in C
the `jsonpointer` functionality will likely be incorporated in `Schute`
for efficient access to internals.


## Installation

Make sure the `pg_config` utility of the system's PostgreSQL inmstallation
is in `$PATH`.

Buid the binaries
```
cd schute
make
```

Install the binaries
```
sudo PATH=$PATH make install
```

**Note:** sudo is needed because when PostgreSQL is installed from
RPMs the binaries are installed as root. This means installing and
extension requires root privileges. If your system was installed
differently (like you did an unprivileged user installation of
PostgreSQL, then you will know what else to do to install an
extension in your environment.


## Configuration

The `Schute` extension creates two schemas,

* `bagger_schute` containing all configuration data and functions and
* `bagger_data` in which the partition management maintains all data tables.

### Example Configuration

```
CREATE EXTENSION jsonpointer;
CREATE EXTENSION bagger_schute;

INSERT INTO bagger_schute.base_config VALUES
    ('entry_ts', '/logged'),
    ('expiration_interval', '3 hours'),
    ('precreate_interval', '1 hour'),
    ('rotation_interval', '10 min'),
    ('ts_suffix_format', 'YYYYMMDD_HH24MI');

INSERT INTO bagger_schute.routing_config (config, valid_from) VALUES (
    '{"dimensions": [
        ["endpoint", "/endpoint"],
        ["stage", "/stage"]
      ],
      "dimension_values": {
        "endpoint": ["installs", "clicks", "impressions"],
        "stage": ["request", "callback"]
      },
      "indexes": [
      ],
      "prefix": "bd_",
      "delimiter": "_",
      "exc_not_routable": "exc_not_routable",
      "exc_invalid_json": "exc_invalid_json"
     }',
    'epoch'
    );

SELECT bagger_schute.data_partition_maintenance();
```

### Table `bagger_schute.base_config`

| Key  | Description |
| :--- | :--- |
| `entry_ts` | *jsonpath* to the entry timestamp used in partition routing |
| `expiration_interval` | Time after which data partitions expire and get dropped |
| `precreate_interval` | Time for which partitions will be created into the future |
| `rotation_interval` | Time interval covered by each set of partitions |
| `ts_suffi_format` | Format of the timestamp used in partition names (as documented for the `to_char()` function) |

### Table `bagger_schute.routing_config`

This table contains the configuration for dimensions and the possible values
in them. The primary `config` column contains all the configuration data.
The `valid_from` column defines as of when the row is active. There is no
`valid_until` datum as `valid_from` implicitly defines that for the previous
entry.

The `config` jsonb attribute contains the following keys:

| Key  | Description |
| :--- | :--- |
| `dimensions` | A list of 2-element lists consisting of `[ "DIMNAME", "JSONPOINTER" ]`<br>`DIMNAME` is a symbolic name for the dimension, `JSONPOINTER` is the path to the value in the entry data |
| `dimension_values` | A json object with a key for each `DIMNAME` containing a list of all possible dimension values |
| `indexes` | **TODO:** A list of all secondary indexes for data partitions |
| `prefix` | String literal used as a name prefix for all data partitions |
| `delimiter` | String literal used in the partition name between abbreviated dimension values |
| `exc_not_routable` | Special table name for entries that cannot be routed for reasons like lacking dimension attributes, an invalid `entry_ts` or a missing target partition |
| `exc_invalid_json` | Special table name for entries that cannot converted to PostgreSQL's jsonb data type |

### Data Partition Naming

**TODO:** Copy comment from function `dimension_value_short_strings()`

## Automatic Partition Management

To automatically pre-create and drop expired data partitions, 
the function `bagger_schute.data_partition_maintenance()` should
be called at least once per `bagger_schute.base_config.rotation_interval`.
