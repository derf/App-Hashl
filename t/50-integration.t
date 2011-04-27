#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use autodie;

use Cwd;
use Test::Command tests => 6;

my $hashl = '../../bin/hashl';

my $EMPTY = q{};
my $usage = <<'EOF';
Usage: ../../bin/hashl [options] <update|list|info|...> [args]
See 'perldoc -F ../../bin/hashl' (or 'man hashl' if it is properly installed)
EOF

chdir('t/in');

for my $cmd ("$hashl", "$hashl copy") {
	my $tc = Test::Command->new(cmd => $cmd);

	$tc->exit_isnt_num(0);
	$tc->stdout_is_eq($EMPTY);
	$tc->stderr_is_eq($usage);
}
