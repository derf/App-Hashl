package App::Hashl;

use strict;
use warnings;
use autodie;
use 5.010;

use Digest::SHA qw(sha1_hex);
use Storable qw(nstore retrieve);

my $VERSION = '0.1';

=head1 NAME

App::Hashl - Partially hash files, check if files are equal etc.

=head1 SYNOPSIS

    use App::Hashl;

    my $hashl = App::Hashl->new();
    # or: App::Hashl->new_from_file($database_file);

=head1 VERSION

This manual documents App::Hashl version 0.2

=head1 DESCRIPTION

App::Hashl contains utilities to hash the first n bytes of a file, store and
recall this, check if another file is already in the database and optionally
ignore file hashes.

=head1 METHODS

=over

=item $hashl = App::Hashl->new(I<%conf>)

Returns a new B<App::Hashl> object. Accepted parameters are:

=over

=item B<read_size> => I<bytes>

How many bytes of a file to consider for the hash.  Defaults to 4 MiB (4 *
2**20 bytes).

=back

=cut

sub new {
	my ($obj, %conf) = @_;
	my $ref = {
		files => {},
		ignored => {},
	};

	$ref->{config} = \%conf;
	$ref->{config}->{read_size} //=  (2 ** 20) * 4, # 4 MiB

	return bless($ref, $obj);
}

=item $hashl = App::Hashl->new_from_file(I<$file>)

Returns the B<App::Hashl> object saved to I<file> by a prior $hashl->save
call.

=cut

sub new_from_file {
	my ($obj, $file) = @_;
	my $ref = retrieve($file);
	return bless($ref, $obj);
}

=item $hashl->si_size(I<$bytes>)

Returns I<bytes> as a human-readable SI-size, such as "1.0k", "50.7M", "2.1G".
The returned string is always six characters long.

=cut

sub si_size {
	my ($self, $bytes) = @_;
	my @post = (' ', qw(k M G T));

	while ($bytes >= 1024) {
		$bytes /= 1024;
		shift @post;
	}

	return sprintf("%6.1f%s", $bytes, $post[0]);
}

=item $hashl->hash_file(I<$file>)

Returns the SHA1 hash of the first n bytes (as configured via B<read_size>) of
I<file>

=cut

sub hash_file {
	my ($self, $file) = @_;
	my ($fh, $data);

	open($fh, '<', $file);
	binmode($fh);
	read($fh, $data, $self->{config}->{read_size});
	close($fh);

	return sha1_hex($data);
}

=item $hashl->hash_in_db(I<$hash>)

Checks if I<hash> is in the database.  If it is, returns the filename it is
associated with.  If it is ignored, returns "// ignored" (subject to change).
Otherwise, returns undef.

=cut

sub hash_in_db {
	my ($self, $hash) = @_;

	if ($self->{ignored}->{hashes}) {
		for my $ihash (@{$self->{ignored}->{hashes}}) {
			if ($hash eq $ihash) {
				return '// ignored';
			}
		}
	}

	for my $name ($self->files()) {
		my $file = $self->file($name);

		if ($file->{hash} eq $hash) {
			return $name;
		}
	}
	return undef;
}

=item $hashl->file_in_db(I<$file>)

Checks if I<file>'s hash is in the database.  For the return value, see
B<hash_in_db>.

=cut

sub file_in_db {
	my ($self, $file) = @_;

	return $self->hash_in_db($self->hash_file($file));
}

=item $hashl->read_size()

Returns the current read size.  Note that once an B<App::Hashl> object has
been created, it is not possible to change the read size.

=cut

sub read_size {
	my ($self) = @_;
	return $self->{config}->{read_size};
}

=item $hashl->file(I<$name>)

Returns a hashref describing the file. The layout is as follows:

    hash => file's hash,
    mtime => mtime as UNIX timestamp,
    size => file size in bytes,

=cut

sub file {
	my ($self, $name) = @_;
	return $self->{files}->{$name};
}

=item $hashl->delete_file(I<$name>)

Remove the file from the database

=cut

sub delete_file {
	my ($self, $name) = @_;
	delete $self->{files}->{$name};
}

=item $hashl->files()

Returns a list of all file names in the database

=cut

sub files {
	my ($self) = @_;
	return sort keys %{ $self->{files} };
}

=item $hashl->add_file(I<%data>)

Add a file to the database. Required keys in I<%data> are:

=over

=item B<file> => I<name>

relateve file name to store in the database

=item B<path> => I<path>

Full path to the file

=back

If the file already is in the database, it is only updated if both the file
size and the mtime have changed.

=cut

sub add_file {
	my ($self, %data) = @_;
	my $file = $data{file};
	my $path = $data{path};
	my ($size, $mtime) = (stat($path))[7,9];

	if ($self->file($file) and
			$self->file($file)->{mtime} == $mtime and
			$self->file($file)->{size} == $size ) {
		return;
	}

	$self->{files}->{$file} = {
		hash  => $self->hash_file($file),
		mtime => $mtime,
		size  => $size,
	};
}

=item $hashl->ignored()

Returns a list of all ignored file hashes

=cut

sub ignored {
	my ($self) = @_;
	if (exists $self->{ignored}->{hashes}) {
		return @{ $self->{ignored}->{hashes} };
	}
	else {
		return ();
	}
}

=item $hashl->ignore(I<$file>, I<$path>)

Removes I<$file> from the database and adds I<$path> to the list of ignored
file hashes.

=cut

sub ignore {
	my ($self, $file, $path) = @_;

	$self->delete_file($file);
	push(@{ $self->{ignored}->{hashes} }, $self->hash_file($path));
}

=item $hashl->save(I<$file>)

Save the B<App::Hashl> object with all data to I<$file>.  It can later be
retrieved via B<new_from_file>.

=cut

sub save {
	my ($self, $file) = @_;
	nstore($self, $file);
}

1;

__END__

=back

=head1 DEPENDENCIES

B<Digest::SHA>.

=head1 AUTHOR

Copyright (C) 2011 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

  0. You just DO WHAT THE FUCK YOU WANT TO.
