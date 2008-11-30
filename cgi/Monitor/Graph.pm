package Monitor::Graph;

use strict;
use File::Find;

my @colors = qw( 6ac443 5361cb b84d47 c8c635 f8869a 3f7c45 a677b7 80a8d2 b3986d ef8d3e );
my @color_rgb = map { '#' . $_ } @colors;
my $prefix = 'piechart';
my $imagedir = 'images/tmp';

sub new {
	my $class = shift;
	bless { @_ }, $class;
}

sub gather {
	my $self = shift;
	my %args = @_;
	my $graph = GD::Graph::pie->new(($args{'height'} || 250), ($args{'width'} || 225));
	$graph->set_label_font('verdanab.ttf', 10);
	$graph->set( dclrs => [ @color_rgb ] );
	$graph->set_text_clr( 'white' );
	$graph->set( textclr => 'white', labelclr => '#477979' );
	$graph->set( t_margin => 20, b_margin => 20, l_margin => 0, r_margin => 20 );
	$graph->set( start_angle => 45 );
	$graph->set( %{$args{'options'}} ) || die $graph->error;
	my %hash;
	my $data;
	my $other = 100;
	for my $row (@{$args{'data'}}) {
		if ($row->{$args{'value'}} > 0) {
			$hash{$row->{$args{'label'}}} += $row->{$args{'value'}};
			$other -= $row->{$args{'value'}};
		}
	}
	$hash{'other'} = $other;
	my @sorted_keys = sort { $hash{$b} <=> $hash{$a} } keys %hash;
	push(@{$data->[1]}, $hash{$_}) foreach @sorted_keys;
	push(@{$data->[0]}, '') foreach @sorted_keys;
	#push(@{$data->[0]}, @sorted_keys);
	my $gd = $graph->plot($data) || die $graph->error;
	my $timestamp = time;
	my $name = "$imagedir/${prefix}-${timestamp}$args{'suffix'}.png";
	open(IMG, ">$name") || die "Can't open image for writing: $!";
	binmode(IMG);
	print IMG $gd->png;
	close(IMG);
	$self->{'filename'} = $name;
	$self->{'legend'} = _get_legend(\@sorted_keys);
	return;
}

sub _get_legend {
	my $labels = shift;
	my $i=0;
	my $j=0;
	my @legends;
	while ($i < @$labels) {
		my %legend = (
			label => $labels->[$i],
			color => $color_rgb[$j],
		);
		push(@legends, \%legend);
		$i++;
		$j++;
		$j = ($j > $#color_rgb) ? 0 : $j;
	}
	return \@legends;
}

sub cleanup_old_pngs {
	find({ wanted => 
		sub {
			if (/${prefix}-.*.png/) {
				my $filedate = (stat($_))[9];
				my $now = time;
				if ((($now - $filedate) / (60 * 60 * 24)) > 1) {
					my $filename = "../../${imagedir}/$_";
					unlink($filename) || die "$filename not found: $!";
					print STDERR "DEBUG: deleting $filename\n";
				}
			}
		}
	}, $imagedir);
}

1;
