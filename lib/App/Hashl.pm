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

    for my $file (@files) {
        $hashl->add_file($file, {
            hash

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

sub new_from_file {
	my ($obj, $file) = @_;
	my $ref = retrieve($file);
	return bless($ref, $obj);
}

sub si_size {
	my ($self, $bytes) = @_;
	my @post = (' ', qw(k M G T));

	while ($bytes > 1024) {
		$bytes /= 1024;
		shift @post;
	}

	return sprintf("%6.1f%s", $bytes, $post[0]);
}

sub hash_file {
	my ($self, $file) = @_;
	my ($fh, $data);

	open($fh, '<', $file);
	binmode($fh);
	read($fh, $data, $self->{config}->{read_size});
	close($fh);

	return sha1_hex($data);
}

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

sub file_in_db {
	my ($self, $file) = @_;

	return $self->hash_in_db($self->hash_file($file));
}

sub read_size {
	my ($self) = @_;
	return $self->{config}->{read_size};
}

sub file {
	my ($self, $name) = @_;
	return $self->{files}->{$name};
}

sub delete_file {
	my ($self, $name) = @_;
	delete $self->{files}->{$name};
}

sub files {
	my ($self) = @_;
	return sort keys %{ $self->{files} };
}

sub add_file {
	my ($self, %data) = @_;
	my $file = $data{file};
	my $path = $data{path};

	if ($self->file($file) and
			$self->file($file)->{mtime} == $data{mtime} and
			$self->file($file)->{size} == $data{size} ) {
		return;
	}

	$self->{files}->{$file} = {
		hash  => $self->hash_file($file),
		mtime => $data{mtime},
		size  => $data{size},
	};
}

sub ignored {
	my ($self) = @_;
	if (exists $self->{ignored}->{hashes}) {
		return @{ $self->{ignored}->{hashes} };
	}
	else {
		return ();
	}
}

sub ignore {
	my ($self, $file) = @_;

	push(@{ $self->{ignored}->{hashes} }, $file);
}

sub save {
	my ($self, $file) = @_;
	nstore($self, $file);
}

1;

__END__

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=over

=back

=head1 DEPENDENCIES

=head1 SEE ALSO

=head1 AUTHOR

Copyright (C) 2011 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

  0. You just DO WHAT THE FUCK YOU WANT TO.
