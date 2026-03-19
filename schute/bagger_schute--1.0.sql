/* bagger_schute--1.0.sql */
-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION bagger_schute" to load this file. \quit

CREATE SCHEMA IF NOT EXISTS bagger_schute;
CREATE SCHEMA IF NOT EXISTS bagger_data;

-- ----
-- All objects (except for the drop zone) are created in the
-- bagger_schute schema
-- ----
SET search_path TO 'bagger_schute';


-- ----
-- base_config
--
--	Table for base configuration data like the jsonpointer to find the
--	relevant timestamp in the incoming data.
-- ----
CREATE TABLE base_config (
	key				text PRIMARY KEY,
	value			text NOT NULL
);


-- ----
-- routing_config
--
--	Table holding the partition routing configuration. This configuration
--	has a valid_from timestamp. Each new entry outdates the previous one
--	at the time it becomes valid.
-- ----
CREATE TABLE routing_config (
	id				serial PRIMARY KEY,
	config			jsonb NOT NULL,
	valid_from		timestamptz NOT NULL
);
CREATE INDEX routing_config_valid_idx ON routing_config(valid_from);


-- ----
-- index_config
--
--	Configuration of what indexes are created on data partitions. This
--	is kept separate from the routing configuration so that indexing
--	can be changed independent of that.
-- ----
CREATE TABLE index_config (
	id				serial PRIMARY KEY,
	config			jsonb NOT NULL,
	valid_from		timestamptz NOT NULL
);
CREATE INDEX index_config_valid_idx ON index_config(valid_from);


-- ----
-- data_partition_set
--
--	Tracking of valid_at timestamps for which a set of data partitions
--	currently exists.
-- ----
CREATE TABLE data_partition_set (
	id				bigserial PRIMARY KEY,
	valid_at		timestamptz NOT NULL UNIQUE
);


-- ----
-- data_partition_name
--
--	Tracking of which individual partitions in a partition_set
--	currently exist.
CREATE TABLE data_partition_name (
	partition_name	text PRIMARY KEY,
	set_id			bigint NOT NULL REFERENCES data_partition_set (id)
					ON DELETE CASCADE,
	valid_at		timestamptz NOT NULL
);
CREATE INDEX data_partition_name_valid_idx
	ON data_partition_name (valid_at);


-- ----
-- schute
--
--	Ingestion table. No data actually ever ends up in this table. 
--	The ingestion trigger BEFORE INSERT is distributing the new
--	entry into the data partitions and returns NULL.
-- ----
CREATE TABLE bagger_data.schute (
	entry	text NOT NULL
);


CREATE FUNCTION routing_config_at(ts timestamptz)
RETURNS jsonb
AS $$
-- ----
-- routing_config_at(ts timestamptz)
--
--	Support function to fetch the partition routing configuration
--	that is active at a given point in time. It also populates the
--	entry for the short versions of dimension values that are used
--	when building partition names.
-- ----
DECLARE
	result		jsonb;
	idxresult	jsonb;
	key			text;
	value		jsonb;
	svalue		text[];
	base_row	record;
BEGIN
	SET LOCAL search_path TO 'bagger_schute';

	-- ----
	-- Retrieve the config entry that is active at the requested time
	-- ----
	SELECT config INTO result
		FROM routing_config
		WHERE valid_from <= ts
		ORDER BY valid_from DESC
		LIMIT 1;
	IF NOT FOUND
	THEN
		RAISE EXCEPTION 'no valid partition routing entry found at %', ts;
	END IF;

	-- ----
	-- Add the active index_config info
	-- ----
	SELECT config INTO idxresult
		FROM index_config
		WHERE valid_from <= ts
		ORDER BY valid_from DESC
		LIMIT 1;
	IF NOT FOUND
	THEN
		RAISE EXCEPTION 'no valid index config entry found at %', ts;
	END IF;
	result = result || jsonb_build_object('indexes', idxresult);

	-- ----
	-- Add the base_config entries to the result
	-- ----
	FOR base_row IN SELECT B.key, B.value FROM base_config B
	LOOP
		result = result || jsonb_build_object(base_row.key, base_row.value);
	END LOOP;

	-- ----
	-- Add the short_values built from dimension_values
	-- ----
	result = jsonb_insert(result, ARRAY['short_values'], '{}');
	FOR key, value IN SELECT * FROM jsonb_each(result -> 'dimension_values')
	LOOP
		svalue = dimension_value_short_strings(value);
		result = jsonb_insert(result, ARRAY['short_values', key],
							  array_to_json(svalue)::jsonb);
	END LOOP;

	-- ----
	-- Return the completed configuration
	-- ----
	RETURN result;
END;
$$ LANGUAGE plpgsql;


-- ----
-- routing_map_permutation_entry
--
--	Custom data type used in building the full cross product of all
--	dimension values with their corresponding short values.
-- ----
CREATE TYPE routing_map_permutation_entry AS (
	value	text,
	svalue	text
);


CREATE FUNCTION routing_map_permutations(config jsonb,
		path routing_map_permutation_entry[] = '{}',
		dim_idx integer = 0)
RETURNS setof routing_map_permutation_entry[]
AS $$
-- ----
-- routing_map_permutations()
--
--	Internal recursive support function to build the full cross product
--	of all possible dimension values and their short versions.
-- ----
DECLARE
	dim_key		text;
	dim_values	jsonb;
	dim_svalues	jsonb;
	dim_max		integer := jsonb_array_length(config -> 'dimensions') - 1;
	sub_result	routing_map_permutation_entry[];
	entry		routing_map_permutation_entry;
	idx			int4;
	len			int4;
BEGIN
	SET LOCAL search_path TO 'bagger_schute';

	-- ----
	-- Extract the dimenssion values at this recursion level. Starting at 0
	-- the recursion level is the index in the configuration's "dimensions".
	-- ----
	dim_key = config -> 'dimensions' -> dim_idx ->> 0;
	dim_values = config -> 'dimension_values' -> dim_key;
	dim_svalues = config -> 'short_values' -> dim_key;

	-- ----
	-- Loop over the two arrays and return arrays of the map_entry data
	-- type. If we are not handling the final dimension, recurse for the
	-- next dimension.
	-- ----
	len = jsonb_array_length(dim_values);
	FOR idx IN 0 .. len - 1
	LOOP
		entry.value = dim_values ->> idx;
		entry.svalue = dim_svalues ->> idx;
		IF dim_idx < dim_max THEN
			FOR sub_result IN SELECT * FROM routing_map_permutations(
					config, path || entry, dim_idx + 1)
			LOOP
				RETURN NEXT sub_result;
			END LOOP;
		ELSE
			RETURN NEXT path || entry;
		END IF;
	END LOOP;
END;
$$ LANGUAGE plpgsql;


CREATE FUNCTION routing_map_at(ts timestamptz)
RETURNS jsonb
AS $$
-- ----
-- routing_map_at(ts timestamp)
--
--	Generates a jsonb document that maps the dimension values in dimension
--	order to the basename of the corresponding data partition without the
--	timestamp part attached yet.
-- ----
DECLARE
	config			jsonb := bagger_schute.routing_config_at(ts);
	prefix			text := config ->> 'prefix';
	delimiter		text := config ->> 'delimiter';
	path			text[];
	spath			text[];
	partmap			jsonb := '{}';
	partname		text;
	map_perm		bagger_schute.routing_map_permutation_entry[];
	map_entry		bagger_schute.routing_map_permutation_entry;
BEGIN
	SET LOCAL search_path TO 'bagger_schute';

	-- ----
	-- Loop over the result set of routing_map_permutations(). Each row is
	-- an ARRAY of our custom data type that holds the dimension value and
	-- the corresponding short version.
	-- ----
	FOR map_perm IN SELECT * FROM routing_map_permutations(config)
	LOOP
		-- ----
		-- For each row we create two text ARRAYs. One for the json path
		-- using the original dimension value, the other using the short
		-- versions.
		-- ----
		path = '{}';
		spath = '{}';
		FOREACH map_entry IN ARRAY map_perm
		LOOP
			path = path || lower(map_entry.value);
			spath = spath || map_entry.svalue;

			-- ----
			-- On the go we populate the resulting partition map with all
			-- the path elements as empty objects (if they don't exist).
			-- We need to do so because jsonb_set() does not create missing
			-- path elements.
			-- ----
			IF partmap #> path IS NULL THEN
				partmap = jsonb_set(partmap, path, '{}', true);
			END IF;
		END LOOP;

		-- ----
		-- We now have the json path for this permutation of dimension
		-- values in path. We build the basename for the partition by
		-- concatenating the prefix and all path elements with the
		-- delimiter. Finally we overwrite the element at the end of
		-- the path with the partition basename.
		-- ---
		partname = prefix || array_to_string(spath, delimiter);
		partmap = jsonb_set(partmap, path, to_jsonb(partname), false);
	END LOOP;
	return partmap;
END;
$$ LANGUAGE plpgsql;


CREATE FUNCTION dimension_value_short_strings(dim_values jsonb)
RETURNS text[]
AS $$
-- ----
-- dimension_value_short_strings(dim_values jsonb)
--
--	Internal support function to convert the possible dimension values
--	of ONE dimension into the corresponding short versions used in building
--	the partition basenames.
--
--	To build the short version we first convert the value to lower case
--	and strip it of all whitespaces. We then look for the shortes 3+
--	character substring that is unique within this dimension's values.
--	Note that this does NOT consider the possible values of other
--	dimensions since it is irrelevant for the uniqueness of the resulting
--	partition basename.
-- ----
DECLARE
	result	text[];
	vlen	integer;
	elen	integer;
	maxlen	integer := 0;
	elem1	jsonb;
	elem2	jsonb;
	val1	text;
	val2	text;
	matches	integer;
BEGIN
	SET LOCAL search_path TO 'bagger_schute';

	-- ----
	-- Loop over each element in one dimension's values
	-- ----
	FOR elem1 IN SELECT * FROM jsonb_array_elements(dim_values)
	LOOP
		-- ----
		-- Start at a substring length of 3 and check for any duplicate
		-- values at that length. Increase the substring length until
		-- we only have one match (the element itself) or we have reached
		-- the maximum length of all elements, which means we have a
		-- duplicate element (which is not allowed).
		-- ----
		vlen = 2;
		matches = 2;
		WHILE matches > 1
		LOOP
			vlen = vlen + 1;
			val1 = regexp_replace(lower(substring(elem1 ->> 0, 1, vlen)),
								  '\s+', '', 'g');
			matches = 0;
			FOR elem2 IN SELECT * FROM jsonb_array_elements(dim_values)
			LOOP
				elen = length(elem2 ->> 0);
				IF elen > maxlen THEN
					maxlen = elen;
				END IF;
				val2 = regexp_replace(lower(substring(elem2 ->> 0, 1, vlen)),
									  '\s+', '', 'g');
				IF val1 = val2 THEN
					matches = matches + 1;
				END IF;
			END LOOP;
			IF vlen > maxlen THEN
				RAISE EXCEPTION 'duplicate dimension values in %', dim_values;
			END IF;
		END LOOP;

		-- ----
		-- Add this unique element substring to the result set
		-- ----
		result = result || val1;
	END LOOP;

	-- ----
	-- Done
	-- ----
	RETURN result;
END;
$$ LANGUAGE plpgsql;


CREATE FUNCTION get_data_partitions_at(ts timestamptz)
RETURNS setof text
AS $$
-- ----
-- partitions_at(ts timestamptz)
--
--	Returns a setof text listing all the bagger data partitions that cover
--	a certain timestamp.
-- ----
DECLARE
	config			jsonb := bagger_schute.routing_config_at(ts);
	routing			jsonb := bagger_schute.routing_map_at(ts);
	delimiter		text := config ->> 'delimiter';
	ts_trunc		timestamptz;
	ts_suffix		text;
	basename		text;

BEGIN
	SET LOCAL search_path TO 'bagger_schute';

	ts_trunc = ts_trunc_to_interval(ts, config->>'rotation_interval');
	ts_suffix = delimiter || to_char(ts_trunc, config ->> 'ts_suffix_format');

	-- ----
	-- Extract the leaf SCALAR element of all partition basenames for
	-- the specified timestamp.
	-- ----
	FOR basename IN SELECT * FROM partition_basenames(routing)
	LOOP
		RETURN NEXT basename || ts_suffix;
	END LOOP;
	
	-- ----
	-- Add the general dead-letter-queue tables for exceptions
	-- ----
	RETURN NEXT config ->> 'exc_not_routable' || ts_suffix;
	RETURN NEXT config ->> 'exc_invalid_json' || ts_suffix;
END;
$$ LANGUAGE plpgsql;


CREATE FUNCTION partition_basenames(js jsonb)
RETURNS setof text
AS $$
-- ----
-- partition_basenames(js jsonb)
--
--	Internal recursive support function to produce the partitions_at() result.
-- ----
DECLARE
	key		text;
	value	jsonb;
	subval	text;
BEGIN
	SET LOCAL search_path TO 'bagger_schute';

	IF js IS JSON SCALAR
	THEN
		RETURN NEXT js #>> '{}';
	ELSE
		FOR key, value IN SELECT * FROM jsonb_each(js)
		LOOP
			FOR subval IN SELECT * FROM partition_basenames(value)
			LOOP
				RETURN NEXT subval;
			END LOOP;
		END LOOP;
	END IF;
END;
$$ LANGUAGE plpgsql;


CREATE FUNCTION data_partition_maintenance()
RETURNS void
AS $$
-- ----
-- data_partition_maintenance()
--
--	Function that is supposed to be called in a cron(8) job at an interval
--	suitable for the configured partition rotation interval. It creates
--	all data partitions needed for the configured intervals, both into
--	the past (expiration) and future (precreate).
--
--	It also drops all data partitions that are past expiration date.
-- ----
DECLARE
	rotation_intvl	text;
	handle_from		timestamptz;
	handle_until	timestamptz;
	handle_now		timestamptz;
BEGIN
	SET LOCAL search_path TO 'bagger_schute';

	raise notice 'current_timestamp %', current_timestamp;

	-- ----
	-- Calculate the time frame that we are handling.
	-- ----
	rotation_intvl = get_base_config('rotation_interval');
	handle_from  = ts_trunc_to_interval(CURRENT_TIMESTAMP -
					get_base_config('expiration_interval')::interval,
					rotation_intvl);
	handle_until = ts_trunc_to_interval(CURRENT_TIMESTAMP +
					get_base_config('precreate_interval')::interval,
					rotation_intvl);

	raise notice 'maint from % until %', handle_from, handle_until;

	-- ----
	-- Drop all expired data partitions. The tracking table
	-- data_partition_name has a cascading foreign key on
	-- data_partition_set and a trigger that will actually
	-- drop the partition table. So simply deleting all the
	-- expired sets here will do it all.
	-- ----
	DELETE FROM data_partition_set
		WHERE valid_at < handle_from;

	-- ----
	-- We now loop over all valid_at timestamp within the maintenance
	-- window and check if a partition set for that timestamp exists.
	-- If it doesn't we create all the partitions needed for that
	-- valid_at moment.
	-- ----
	handle_now = handle_from;
	WHILE handle_now <= handle_until
	LOOP
		-- TODO: we might need to create data partitions retro-actively
		-- at some point if the routing config gets changed with a
		-- valid_at timestamp that is less in the future than the
		-- current precreate_interval. But that opens a big can of
		-- worms since there could already be data in the system that
		-- had been routed according to the previous configuration and
		-- therefore may need to migrate into the new data partitions.
		IF NOT EXISTS (SELECT true FROM data_partition_set
						   WHERE valid_at = handle_now)
		THEN
			raise notice 'create data partitions at %', handle_now;
			PERFORM create_data_partitions_at(handle_now);
		ELSE
			raise notice 'data partitions at % exists', handle_now;
		END IF;

		handle_now = handle_now + rotation_intvl::interval;
	END LOOP;

	RETURN;
END;
$$ LANGUAGE plpgsql;


CREATE FUNCTION create_data_partitions_at(ts timestamptz)
RETURNS void
AS $$
-- ----
-- create_data_partitions_at(ts timestamp)
--
--	Function that creates all necessary data partitions for a specific
--	valid_at rotation interval timestamp.
-- ----
DECLARE
	config		jsonb;
	partmap		jsonb;
	nspname		text;
	relname		text;
	partname	text;
	delimiter	text;
	ts_trunc	timestamptz;
	ts_suffix	text;
	query		text;
BEGIN
	SET LOCAL search_path TO 'bagger_schute';

	-- ----
	-- Since the routing config can change at any rotation_interval we
	-- need to look it up separately for every one.
	-- ----
	config = routing_config_at(ts);
	partmap = routing_map_at(ts);
	nspname = 'bagger_data';
	delimiter = config ->> 'delimiter';
	ts_trunc = ts_trunc_to_interval(ts, config->>'rotation_interval');
	ts_suffix = delimiter || to_char(ts_trunc, config ->> 'ts_suffix_format');

	-- ----
	-- Create the data_partition_set for this timestamp
	-- ----
	IF EXISTS (SELECT true FROM data_partition_set WHERE valid_at = ts_trunc)
	THEN
		RAISE NOTICE 'data_partition_set for ''%'' already exists', ts_trunc;
		RETURN;
	ELSE
		INSERT INTO data_partition_set (valid_at)
			VALUES (ts_trunc);
	END IF;

	-- ----
	-- Create the actual data partitions based on the short values of
	-- the dimension values. Also create the configured indexes for
	-- the data partitions and record the new partition in the tracking
	-- table data_partition_name.
	-- ----
	FOR relname IN SELECT * FROM partition_basenames(partmap)
	LOOP
		partname = relname || ts_suffix;
		query = 'CREATE TABLE IF NOT EXISTS '
				|| quote_ident(nspname) || '.'
				|| quote_ident(partname)
				|| ' (entry jsonb NOT NULL);';
		EXECUTE query;

		PERFORM create_partition_indexes(nspname, partname, config);

		INSERT INTO data_partition_name (partition_name, set_id, valid_at)
			VALUES (partname,
					currval('bagger_schute.data_partition_set_id_seq'),
					ts_trunc);
	END LOOP;

	-- ----
	-- Create the exception table (dead letter queue) for not routable
	-- entries.
	-- ----
	relname = config ->> 'exc_not_routable';
	query = 'CREATE TABLE IF NOT EXISTS '
			|| quote_ident(nspname) || '.'
			|| quote_ident(relname || ts_suffix)
			|| ' (entry jsonb NOT NULL,'
			|| ' ingestion_ts timestamptz, error_msg text);';
	EXECUTE query;

	PERFORM create_partition_indexes(nspname, relname || ts_suffix, config);

	INSERT INTO data_partition_name (partition_name, set_id, valid_at)
		VALUES (relname || ts_suffix,
				currval('bagger_schute.data_partition_set_id_seq'),
				ts_trunc);

	-- ----
	-- Create the exception table for invalid jsonb entries.
	-- ----
	relname = config ->> 'exc_invalid_json';
	query = 'CREATE TABLE IF NOT EXISTS '
			|| quote_ident(nspname) || '.'
			|| quote_ident(relname || ts_suffix)
			|| ' (entry text NOT NULL,'
			|| ' ingestion_ts timestamptz, error_msg text);';
	EXECUTE query;

	INSERT INTO data_partition_name (partition_name, set_id, valid_at)
		VALUES (relname || ts_suffix,
				currval('bagger_schute.data_partition_set_id_seq'),
				ts_trunc);
END;
$$ LANGUAGE plpgsql;


CREATE FUNCTION create_partition_indexes(nspname name, partname name,
										 config jsonb)
RETURNS void
AS $$
-- ----
-- create_partition_indexes(nspname name, partname name, config jsonb)
--
--	Function that creates all configured indexes for a given data
--	partition.
--
--	TODO: This is a function where we may need some more guardrails
--	against possible SQL injection attacks.
-- ----
DECLARE
	suffix		text;
	def			jsonb;
	indexes		jsonb;
	columns		jsonb;
	coldef		jsonb;
	query		text;
	sep			text;
BEGIN
	-- ----
	-- Loop over all the configured indexes for this valid_at timestamp.
	-- ----
	indexes = jsonpointer_get_jsonb(config, '/indexes');
	FOR suffix, def IN SELECT * FROM jsonb_each(indexes) LOOP
		-- ----
		-- Start assembling the CREATE INDEX query
		-- ----
		query = 'CREATE INDEX IF NOT EXISTS '
				|| quote_ident(partname || '_' || suffix)
				|| ' ON '
				|| quote_ident(nspname) || '.'
				|| quote_ident(partname)
				|| ' USING '
				|| jsonpointer_get_text(def, '/method')
				|| ' (';

		-- ----
		-- Loop over all the column definitions for this index
		-- ----
		columns = jsonpointer_get_jsonb(def, '/columns');
		sep = '';
		FOR coldef IN SELECT * FROM jsonb_array_elements(columns) LOOP
			IF jsonpointer_get_text(coldef, '/colname') IS NOT NULL THEN
				-- ----
				-- Plain column name
				-- ----
				query = query || sep
						|| jsonpointer_get_text(coldef, '/colname');
			ELSIF jsonpointer_get_text(coldef, '/jsonpointer') IS NOT NULL THEN
				-- ----
				-- Type specific jsonpointer
				-- ----
				query = query || sep
						|| quote_ident('jsonpointer_get_'
									   || jsonpointer_get_text(coldef, '/type'))
						|| '(entry, '
						|| quote_literal(jsonpointer_get_text(coldef, '/jsonpointer'))
						|| ')';
			ELSE
				-- ----
				-- Invalid index definition
				-- ----
				RAISE EXCEPTION 'unrecognized index column definition %',
								coldef;
			END IF;
			-- TODO: Add opclass here
			sep = ', ';
		END LOOP;

		-- ----
		-- Finalize the CREATE INDEX query and execute it.
		-- ----
		query = query || ')';
		EXECUTE query;
	END LOOP;
	RETURN;
END;
$$ LANGUAGE plpgsql;


-- ----
-- ts_trunc_to_interval(ts timestamptz, step text)
--
--	Internal support function to truncate any given timestamp to the
--	closest rotation interval (in the past or exactly now) specified
--	by step.
-- ----
CREATE FUNCTION ts_trunc_to_interval(ts timestamptz, step text)
RETURNS timestamptz
AS $$
	SELECT to_timestamp(
		floor(EXTRACT(epoch FROM ts) / EXTRACT(epoch FROM step::interval))
		* EXTRACT(epoch FROM step::interval));
$$ LANGUAGE sql;


-- ----
-- get_base_config(p_key text)
--
--	Internal support function to lookup a single base config value
--	by key.
-- ----
CREATE FUNCTION get_base_config(p_key text)
RETURNS text
AS $$
	SELECT value FROM bagger_schute.base_config
		WHERE key = p_key;
$$ LANGUAGE sql;


CREATE FUNCTION schute_routing_trigger()
RETURNS trigger
AS $$
-- ----
-- schute_routing_trigger()
--
--	TODO: rewrite this in C
-- ----
DECLARE
	config		jsonb;
	partmap		jsonb;
	entry_ptr	jsonpointer;
	entry_ts	timestamptz;
	entry_trunc	text;
	dimension	jsonb;
	dim_values	text[] = '{}';
	dv text;
	partts		timestamptz;
	partname	text;
	query		text;
	new_entry	jsonb;
BEGIN
	SET LOCAL search_path TO 'bagger_schute';

	-- ----
	-- We need to get the entry_ts jsonpointer directly from base_config
	-- here because we cannot get the entire config without it.
	-- ----
	SELECT INTO entry_ptr value::jsonpointer
		FROM bagger_schute.base_config
		WHERE key = 'entry_ts';
	SELECT INTO entry_trunc value
		FROM bagger_schute.base_config
		WHERE key = 'rotation_interval';

	new_entry = NEW.entry;

	IF jsonpointer_get_text(new_entry, entry_ptr) IS NULL
	THEN
		config = routing_config_at(now());
		PERFORM schute_save_exception(new_entry, now(),
									  entry_ptr || ' not found',
									  config);
		RETURN NULL;
	END IF;
	entry_ts = jsonpointer_get_timestamptz(new_entry, entry_ptr);
	IF entry_ts IS NULL
	THEN
		config = routing_config_at(now());
		PERFORM schute_save_exception(new_entry, now(),
									  entry_ptr || ' is not a valid timestamp',
									  config);
		RETURN NULL;
	END IF;

	config = routing_config_at(entry_ts);
	partmap = routing_map_at(entry_ts);

	FOR dimension IN SELECT * FROM jsonb_array_elements(config -> 'dimensions')
	LOOP
		dv = jsonpointer_get_text(new_entry, (dimension ->> 1)::jsonpointer);
		dim_values = dim_values || array[lower(dv)];
	END LOOP;
	
	partts = ts_trunc_to_interval(entry_ts, config->>'rotation_interval');
	partname = (partmap #>> dim_values) || (config ->> 'delimiter')
			   || to_char(partts, config ->> 'ts_suffix_format');

	IF partname IS NULL
	THEN
		PERFORM schute_save_exception(new_entry, partts,
									  'invalid routing information',
									  config);
		RETURN NULL;
	END IF;

	-- TODO: Check if the target partition exists

	query = 'INSERT INTO bagger_data.' || quote_ident(partname)
			|| ' (entry) VALUES (' || quote_literal(new_entry) || ');';
	EXECUTE query;
	
	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER schute_routing_trigger
	BEFORE INSERT ON bagger_data.schute
	FOR EACH ROW EXECUTE PROCEDURE schute_routing_trigger();


CREATE FUNCTION schute_save_exception(entry jsonb, rts timestamptz,
									  message text, config jsonb)
RETURNS void
AS $$
-- ----
-- schute_save_exception(entry jsonb, rts timestamptz, message text,
--						 config jsonb)
--
--	Internal support function to save an exception into the corresponding
--	dead letter queue.
--
--	TODO: This will be replaced when the routing trigger is rewritten in C.
-- ----
DECLARE
	partts		timestamptz;
	partname	text;
	query		text;
BEGIN
	SET LOCAL search_path TO 'bagger_schute';

	-- ----
	-- If we don't have a routing timestamp (entry_ts) we use the current
	-- timestamp. Otherwise the error goes into the dead letter queue for
	-- entry_ts.
	-- ----
	IF rts IS NULL
	THEN
		partts = ts_trunc_to_interval(now(), config->>'rotation_interval');
	ELSE
		partts = ts_trunc_to_interval(rts, config->>'rotation_interval');
	END IF;
	partname = 'exc_not_routable' || (config ->> 'delimiter')
			   || to_char(partts, config ->> 'ts_suffix_format');

	query = 'INSERT INTO bagger_data.' || quote_ident(partname)
			|| '(entry, ingestion_ts, error_msg) VALUES ('
			|| quote_literal(entry) || ','
			|| quote_literal(now()) || ','
			|| quote_literal(message) || ')';
	EXECUTE query;
END;
$$ LANGUAGE plpgsql;


CREATE FUNCTION schute_drop_data_partition()
RETURNS trigger
AS $$
-- ----
-- schute_drop_data_partition()
--
--	Trigger that drops the data partition when an entry in the
--	tracking table data_partition_name is deleted.
-- ----
DECLARE
	query	text;
BEGIN
	query = 'DROP TABLE IF EXISTS '
			|| quote_ident('bagger_data') || '.'
			|| quote_ident(OLD.partition_name)
			|| ' CASCADE';
	EXECUTE query;
	raise notice 'query: %', query;
	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER schute_drop_partition_trigger
	AFTER DELETE ON bagger_schute.data_partition_name
	FOR EACH ROW EXECUTE PROCEDURE schute_drop_data_partition();
