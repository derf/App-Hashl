#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use Test::More tests => 28;

use_ok('App::Hashl');

my $IGNORED = '// ignored';

my $hashl = App::Hashl->new();
isa_ok($hashl, 'App::Hashl');

is($hashl->read_size(), (2 ** 20) * 4, 'default read size');

$hashl = App::Hashl->new(read_size => 512);

is($hashl->read_size(), 512, 'Custom read size set');

is($hashl->si_size(1023), '1023.0 ', 'si_size 1023 = 1023');
is($hashl->si_size(1024), '   1.0k', 'si_size 1024 = 1k');
is($hashl->si_size(2048), '   2.0k', 'si_size 2048 = 2k');


is($hashl->hash_in_db('123'), undef, 'hash not in db');
is($hashl->file_in_db('t/in/4'), undef, 'file not in db');
is_deeply([$hashl->files()], [], 'no files in empty db');
is_deeply([$hashl->ignored()], [], 'no ignored files in empty db');

my $test_hash = $hashl->hash_file('t/in/4');
my ($test_size, $test_mtime) = (stat('t/in/4'))[7,9];
ok($hashl->add_file(
		file => 't/in/4',
		path => 't/in/4',
	),
	'Add new file'
);
is_deeply($hashl->file('t/in/4'),
	{
		hash => $test_hash,
		size => $test_size,
		mtime => $test_mtime,
	},
	'hashl->file okay'
);

ok($hashl->file_in_db('t/in/4'), 'file is now in db');
ok($hashl->hash_in_db($test_hash), 'hash is in db');

ok($hashl->add_file(
		file => 't/in/1k',
		path => 't/in/1k',
	),
	'Add another file'
);
is_deeply([$hashl->files()], [qw[t/in/1k t/in/4]], 'Both files in list');
ok($hashl->file_in_db('t/in/1k'), 'file in db');
ok($hashl->file_in_db('t/in/4'), 'other file in db');

ok($hashl->ignore('t/in/4', 't/in/4'), 'ignore file');
is($hashl->file_in_db('t/in/4'), $IGNORED, 'file no longer in db');

is_deeply([$hashl->ignored()], [$test_hash], 'file is ignored');

ok($hashl->ignore('t/in/1k', 't/in/1k'), 'ignore other file as well');
is($hashl->file_in_db('t/in/1k'), $IGNORED, 'file ignored');

ok($hashl->save('t/in/hashl.db'), 'save db');

undef $hashl;

$hashl = App::Hashl->new_from_file('t/in/hashl.db');
isa_ok($hashl, 'App::Hashl');
unlink('t/in/hashl.db');

is($hashl->file_in_db('t/in/4'), $IGNORED, 'file still ignored');
is_deeply([$hashl->files()], [], 'no files in db');
