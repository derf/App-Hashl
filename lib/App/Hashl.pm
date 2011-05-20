package App::Hashl;

use strict;
use warnings;
use 5.010;

use Digest::SHA qw(sha1_hex);
use Storable qw(nstore retrieve);

our $VERSION = '0.1';

sub new {
	my ( $obj, %conf ) = @_;

	my $ref = {
		files   => {},
		ignored => {},
	};

	$ref->{config} = \%conf;
	$ref->{config}->{read_size} //= ( 2**20 ) * 4;    # 4 MiB

	return bless( $ref, $obj );
}

sub new_from_file {
	my ( $obj, $file ) = @_;

	my $ref = retrieve($file);

	return bless( $ref, $obj );
}

sub si_size {
	my ( $self, $bytes ) = @_;
	my @post = ( q{ }, qw(k M G T) );

	while ( $bytes >= 1024 ) {
		$bytes /= 1024;
		shift @post;
	}

	return sprintf( '%6.1f%s', $bytes, $post[0] );
}

sub hash_file {
	my ( $self, $file ) = @_;
	my $data;

	#<<< perltidy has problems indenting 'or die' with tabs

	open( my $fh, '<', $file )
		or die("Can't open ${file} for reading: $!\n");
	binmode($fh)
		or die("Can't set binmode on ${file}: $!\n");
	read( $fh, $data, $self->{config}->{read_size} )
		or die("Can't read ${file}: $!\n");
	close($fh)
		or die("Can't close ${file}: $!\n");

	#>>>
	return sha1_hex($data);
}

sub hash_in_db {
	my ( $self, $hash ) = @_;

	if ( $self->{ignored}->{$hash} ) {
		return '// ignored';
	}

	for my $name ( $self->files() ) {
		my $file = $self->file($name);

		if ( $file->{hash} eq $hash ) {
			return $name;
		}
	}
	return;
}

sub file_in_db {
	my ( $self, $file ) = @_;

	return $self->hash_in_db( $self->hash_file($file) );
}

sub read_size {
	my ($self) = @_;

	return $self->{config}->{read_size};
}

sub file {
	my ( $self, $name ) = @_;

	return $self->{files}->{$name};
}

sub delete_file {
	my ( $self, $name ) = @_;

	delete $self->{files}->{$name};

	return 1;
}

sub files {
	my ($self) = @_;

	return keys %{ $self->{files} };
}

sub add_file {
	my ( $self, %data ) = @_;
	my $file = $data{file};
	my $path = $data{path};
	my ( $size, $mtime ) = ( stat($path) )[ 7, 9 ];

	if (    $self->file($file)
		and $self->file($file)->{mtime} == $mtime
		and $self->file($file)->{size} == $size )
	{
		return;
	}

	my $hash = $self->hash_file($path);

	if ( $self->{ignored}->{$hash} ) {
		return;
	}

	$self->{files}->{$file} = {
		hash  => $hash,
		mtime => $mtime,
		size  => $size,
	};

	return 1;
}

sub ignored {
	my ($self) = @_;

	if ( exists $self->{ignored} ) {
		return keys %{ $self->{ignored} };
	}

	return ();
}

sub ignore {
	my ( $self, $file, $path ) = @_;

	$self->delete_file($file);
	$self->{ignored}->{ $self->hash_file($path) } = 1;

	return 1;
}

sub save {
	my ( $self, $file ) = @_;

	return nstore( $self, $file );
}

1;

__END__

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

=item $hashl = App::Hashl->new_from_file(I<$file>)

Returns the B<App::Hashl> object saved to I<file> by a prior $hashl->save
call.

=item $hashl->si_size(I<$bytes>)

Returns I<bytes> as a human-readable SI-size, such as "1.0k", "50.7M", "2.1G".
The returned string is always six characters long.

=item $hashl->hash_file(I<$file>)

Returns the SHA1 hash of the first few bytes (as configured via B<read_size>) of
I<file>.  Dies if I<file> cannot be read.

=item $hashl->hash_in_db(I<$hash>)

Checks if I<hash> is in the database.  If it is, returns the filename it is
associated with.  If it is ignored, returns "// ignored" (subject to change).
Otherwise, returns false.

=item $hashl->file_in_db(I<$file>)

Checks if I<file>'s hash is in the database.  For the return value, see
B<hash_in_db>.

=item $hashl->read_size()

Returns the current read size.  Note that once an B<App::Hashl> object has
been created, it is not possible to change the read size.

=item $hashl->file(I<$name>)

Returns a hashref describing the file. The layout is as follows:

    hash => file's hash,
    mtime => mtime as UNIX timestamp,
    size => file size in bytes

If I<name> does not exist in the database, returns undef.

=item $hashl->delete_file(I<$name>)

Remove the file from the database.

=item $hashl->files()

Returns a list of all file names in the database.

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

Returns true if the file was actually added to the database, false if it is
ignored or already present (and up-to-date).

=item $hashl->ignored()

Returns a list of all ignored file hashes.

=item $hashl->ignore(I<$file>, I<$path>)

Removes I<$file> from the database and adds I<$path> to the list of ignored
file hashes.

=item $hashl->save(I<$file>)

Save the B<App::Hashl> object with all data to I<$file>.  It can later be
retrieved via B<new_from_file>.

=back

=head1 DIAGNOSTICS

FIXME

=head1 DEPENDENCIES

Digest::SHA(3pm);

=head1 BUGS AND LIMITATIONS

There is no B<unignore> method yet.

=head1 AUTHOR

Copyright (C) 2011 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

  0. You just DO WHAT THE FUCK YOU WANT TO.
