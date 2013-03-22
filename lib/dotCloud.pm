package dotCloud;
BEGIN {
  $dotCloud::AUTHORITY = 'cpan:GETTY';
}
{
  $dotCloud::VERSION = '0.001';
}
# ABSTRACT: A small wrapper around the dotcloud management tool

use Moo;
use Cwd;
use File::chdir;
use YAML;
use namespace::autoclean;
use IPC::Open3;

has dotcloud_command => (
	is => 'ro',
	builder => sub { 'dotcloud' },
);

has dir => (
	is => 'ro',
	predicate => 'has_dir',
);

has application => (
	is => 'ro',
	predicate => 'has_application',
);

sub BUILDARGS {
	my ( $class, @args ) = @_;

	unshift @args, "dir",
		if @args % 2 == 1;

	unshift @args, dir => getcwd(),
		if @args == 0;

	return { @args };
}

sub run {
	my ( $self, @args ) = @_;
	local $CWD = $self->dir if $self->has_dir;
	local $| = 1;
	my $pid = IPC::Open3::open3(my ($in, $out, $err), $self->dotcloud_command, @args);
	my $data;
	while (defined(my $line = <$out>)) {
		$data .= $line;
	}
	waitpid($pid, 0);
	my $status = ($? >> 8);
	if ($status) {
		print $data."\n\n";
		die "Error on execute, status $status";
	}
	return $data;
}

sub info {
	my ( $self, $service ) = @_;
	my $return = $self->run('info',$service ? ($service) : ());
	return $return unless $service;
	my %secs;
	my $cur_section;
	for (split("\n",$return)) {
		if ($_ =~ m/==(={0,1}) (.*)/) {
			my $level = $1;
			my @parts = split(/\./,$2);
			$cur_section = $1 ? $parts[1] : "_";
		} else {
			die "Unexpected output, no == section" unless defined $cur_section;
			push @{$secs{$cur_section}}, $_;
		}
	}
	for (keys %secs) {
		$secs{$_} = Load(join("\n",@{$secs{$_}})."\n");
	}
	my %return = %{delete $secs{_}};
	$return{instances_count} = $return{instances};
	$return{instances} = \%secs;
	return \%return;
}

1;


__END__
=pod

=head1 NAME

dotCloud - A small wrapper around the dotcloud management tool

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  use dotCloud;

  my $dc = dotCloud->new;
  my $data = $dc->info('db');
  print $data->{config}->{mysql_password};

=encoding utf8

=head1 SUPPORT

Repository

  http://github.com/Getty/p5-dotcloud
  Pull request and additional contributors are welcome

Issue Tracker

  http://github.com/Getty/p5-dotcloud/issues

=head1 AUTHOR

Torsten Raudssus <torsten@raudss.us>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

