#!/usr/bin/env perl

use strict;
use warnings;
use Module::Build;

my $build = Module::Build->new(
	build_requires => {
		'Test::More' => 0,
		'Test::Compile' => 0,
		'Test::Pod' => 0,
	},
	dist_name => 'hashl',
	dist_version_from => 'bin/hashl',
	license => 'unrestricted',
	requires => {
		'perl' => '5.10.0',
		'autodie' => 0,
		'Digest::SHA' => 0,
		'File::Copy' => 0,
		'File::Find' => 0,
		'Getopt::Long' => 0,
		'IO::Handle' => 0,
		'Storable' => 0,
		'Time::Progress' => 0,
	},
	script_files => 'bin/',
);
$build->create_build_script();
