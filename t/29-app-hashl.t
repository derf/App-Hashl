#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use Test::More tests => 22;

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
ok($hashl->add_file(
		file => 't/in/4',
		path => 't/in/4',
		mtime => 123,
		size => 4,
	),
	'Add new file'
);
is_deeply($hashl->file('t/in/4'),
	{
		hash => $test_hash,
		size => 4,
		mtime => 123,
	},
	'hashl->file okay'
);

ok($hashl->file_in_db('t/in/4'), 'file is now in db');
ok($hashl->hash_in_db($test_hash), 'hash is in db');

ok($hashl->ignore('t/in/4'), 'ignore file');
is($hashl->file_in_db('t/in/4'), $IGNORED, 'file no longer in db');

is_deeply([$hashl->ignored()], [$test_hash], 'file is ignored');

ok($hashl->save('t/in/hashl.db'), 'save db');

undef $hashl;

$hashl = App::Hashl->new_from_file('t/in/hashl.db');
isa_ok($hashl, 'App::Hashl');
unlink('t/in/hashl.db');

is($hashl->file_in_db('t/in/4'), $IGNORED, 'file still ignored');
is_deeply([$hashl->files()], [], 'no files in db');
