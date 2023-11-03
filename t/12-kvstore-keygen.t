use Test2::V0 -target => { inst => 'Bagger::Storage::Instance',
                           smap => 'Bagger::Storage::Servermap',
                           jtyp => 'Bagger::Type::JSON',
                           dtyp => 'Bagger::Type::DateTime',
                           dim  => 'Bagger::Storage::Dimension',
                           idx  => 'Bagger::Storage::Index',
                           fld  => 'Bagger::Storage::Index::Field'};
use Bagger::Agent::Storage::Mapper qw(kval_key pg_object key_to_relname);
use strict;
use warnings;
plan 20;

is(pg_object('/Servermap'), smap(), 'Servermap object determined');
is(pg_object('/PostgresInstance/host1/5432'), inst(), 'PG Instance key read');
is(pg_object('/Message'), undef, 'Non-existent key returns undef');
is(pg_object('/Dimension/1'), dim(), 'Dimension key found');
is(pg_object('/Index/1/1'), fld(), 'Index Field Found');
is(pg_object('/Index/1'), idx(), 'Index found');

# Relname from key
is(key_to_relname('/PostgresInstance/host1/5432'), 'postgres_instance');
is(key_to_relname('/Servermap'), 'servermap');
is(key_to_relname('/Dimension/1'), 'dimension');
is(key_to_relname('/Index/1/1'), 'index_field');
is(key_to_relname('/Index/1'), 'index');

# Table types
is(kval_key('postgres_instance', {host => 'host1', port => '5432'}),
        '/PostgresInstance/host1/5432',
        'kval_key for postgres_instance record');

is(kval_key('servermap', {id => 1}), '/Servermap',
       'kval_key for servermap record');

is(kval_key('dimension', {id => 1}), '/Dimension/1',
       'kval_key for dimension record');

is(kval_key('index', {id => 1}), '/Index/1',
       'kval_key for index record');

is(kval_key('index_field', {id => 1, index_id => 2}), '/Index/2/1',
        'kval_key for index_field record');

## Object types
is(kval_key(inst()->new(host => 'host1', port => 5432, 
                     username => 'foo', status => 0)), 
             '/PostgresInstance/host1/5432',
             'Got correct key for Postgres Instance');

is(kval_key(fld()->new(ordinality => 1, id => 1, 
            index_id => 1, expression =>'foo()',
            valid_from => dtyp()->inf_past,
            valid_until=> dtyp()->inf_future)),
    '/Index/1/1', 'Index Field Key Correct');

is(kval_key(idx()->new(id => 1, indexname => 'i', access_method => 'gin',
            valid_from => dtyp()->inf_past,
            valid_until=> dtyp()->inf_future)),
    '/Index/1', 'Index Key Correct');

is(kval_key(smap()->new(id => 1, server_map => jtyp()->new({ version => 1 }))),
        '/Servermap',
        'Server Map Key Found');

