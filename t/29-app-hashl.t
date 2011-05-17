#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use Test::More tests => 13;

use_ok('App::Hashl');

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

ok($hashl->ignore('hash123'), 'ignore hash');
is_deeply([$hashl->ignored()], ['hash123'], 'ignore hash');
