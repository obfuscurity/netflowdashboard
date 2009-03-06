package Monitor::Devices;

use strict;

sub new {
	my $class = shift;
	bless { @_ }, $class;
}

sub gather {
	my $self = shift;
	my %args = @_;
	my %devices;
	my $dbh = $args{'dbh'};
	my $cgi = $args{'cgi'};
	my $time = $cgi->param('t') || 2;
	my ($now, $then) = _get_timestamps(dbh => $dbh, delta => $time);
	my $device_info = _get_devices_info(dbh => $dbh);
	my $device_addrs = _get_groups_members(dbh => $dbh, group_id => $cgi->param('g')) if ($cgi->param('g'));
	for my $if qw( in out ) {
		my $query = "SELECT DISTINCT if_index_${if}, agent_addr, ";
		$query   .= "SUM(flow_packets) as packets, ";
		$query   .= "SUM(flow_octets) as bytes ";
		$query   .= "FROM flows ";
		$query   .= "WHERE flow_timestamp >= ? AND flow_timestamp < ? ";
		$query   .= "AND agent_addr in (\'" . join("\', \'", @{$device_addrs}) . "\') " if ($cgi->param('g'));
		$query   .= "GROUP BY agent_addr, if_index_${if}";
		my $sth = $dbh->prepare($query);
		$sth->execute($then, $now);
		while (my $result = $sth->fetchrow_hashref) {
			$devices{$result->{'agent_addr'}}->{$result->{"if_index_${if}"}}->{'agent_addr'} = $result->{'agent_addr'};
			$devices{$result->{'agent_addr'}}->{$result->{"if_index_${if}"}}->{'index'} = $result->{"if_index_${if}"};
			$devices{$result->{'agent_addr'}}->{$result->{"if_index_${if}"}}->{"${if}_bps_human"} = _convert_bytes(bytes => $result->{'bytes'}, time => $time, human => 1)->{'bps_human'};
			$devices{$result->{'agent_addr'}}->{$result->{"if_index_${if}"}}->{"${if}_bps"} = _convert_bytes(bytes => $result->{'bytes'}, time => $time)->{'bps'};
			$devices{$result->{'agent_addr'}}->{'packets'} += $result->{'packets'};
		}
	}
	my @devices;
	for my $device (keys %devices) {
		my %data;
		my $interface_info = _get_interfaces_info(dbh => $dbh, device_addr => $device);
		my $sparklines = _get_sparklines(dbh => $dbh, time => $time, device_addr => $device);
		$data{'agent_addr'} = $device;
		$data{'hostname'} = $device_info->{$device}->{'name'} || $device;
		$data{'packets'} = $devices{$device}->{'packets'};
		$data{'sparklines'} = $sparklines;
		delete $devices{$device}->{'packets'};
		for my $interface (values %{$devices{$device}}) {
			for my $if qw (in out) {
				$interface->{"${if}_bps_human"} ||= '0 bps';
				$interface->{"${if}_bps"} ||= '0';
				$interface->{"${if}_utz"} = ($interface_info->{$device}->{'speed'}) ? sprintf("%d", (($interface->{"${if}_bps"} / $interface_info->{$device}->{'speed'})) * 100) : '0';
				$interface->{"${if}_utz_neg"} = (100 - $interface->{"${if}_utz"});
				$interface->{"${if}_utz_color"} = ($interface->{"${if}_utz"} > 80) ? 'warn' : 'ok';
				$interface->{"${if}_utz_color"} = ($interface->{"${if}_utz"} > 90) ? 'warn' : 'ok';
				$interface->{'time'} = $time;
			}
		}
		push(@{$data{'interfaces'}}, values %{$devices{$device}});
		push(@devices, \%data);
		@{$_->{'interfaces'}} = sort { $a->{'index'} <=> $b->{'index'} } @{$_->{'interfaces'}} for @devices;
	}
	my %tmphsh;
	@tmphsh{map {$_->{'agent_addr'}} @devices} = ();
	my @undef = grep {not exists $tmphsh{$_}} @{$device_addrs};
	foreach (@undef) {
		push(@devices, {
			agent_addr => $_,
			hostname => $_,
			packets => 0,
			interfaces => [{
				index => 0,
				in_bps => 0,
				in_bps_human => '0 bytes',
				in_utz => 0,
				in_utz_neg => 100,
				out_bps => 0,
				out_bps_human => '0 bytes',
				out_utz => 0,
				out_utz_neg => 100,
			}]
		});
	}
	$self->{'list'} = \@devices;
	$self->{'subtitle'} = "Router List&nbsp;&nbsp;(Last $time hour/s)";
	return;
}

sub get_devices {
	my $self = shift;
	my %args = @_;
	my $dbh = $args{'dbh'};
	my $result = _get_devices_info(dbh => $dbh);
	return $result;
}

sub _get_devices_info {
	my %args = @_;
	my $dbh = $args{'dbh'};
	my $query = "SELECT * from devices";
	my $sth = $dbh->prepare($query);
	$sth->execute;
	my $result = $sth->fetchall_hashref('device_addr');
	return $result;
}

sub _get_interfaces_info {
	my %args = @_;
	my $dbh = $args{'dbh'};
	my $query = "SELECT * from interfaces";
	my $sth = $dbh->prepare($query);
	$sth->execute;
	my $result = $sth->fetchall_hashref('device_addr');
	return $result;
}

sub _get_sparklines {
	my %args = @_;
	my $dbh = $args{'dbh'};
	my $time = $args{'time'};
	my $query = "SELECT date_trunc('H', flow_timestamp) + (floor(extract('minute' FROM flow_timestamp) / (? * 5)) * (? * 5)) * '1 minute'::interval AS time, floor((sum(flow_octets) * 8) / 1000000 / ( ? * 300)) AS mbps FROM flows WHERE agent_addr=? AND flow_timestamp > current_timestamp - ? * '1 hour'::interval GROUP BY time ORDER BY time ASC";
	my $sth = $dbh->prepare($query);
	$sth->execute($time, $time, $time, $args{'device_addr'}, $time);
	my @data;
	while (my $result = $sth->fetchrow_hashref) {
		push(@data, $result->{mbps});
	}
	my $sparklines = join(',', @data) if (@data);
	return $sparklines;
}

sub _get_groups_members {
	my %args = @_;
	my $dbh = $args{'dbh'};
	my $query = "SELECT device_addr from groups_members WHERE group_id=?";
	my $sth = $dbh->prepare($query);
	$sth->execute($args{'group_id'});
	my @data;
	while (my $result = $sth->fetchrow_hashref) {
		push(@data, $result->{'device_addr'});
	}
	return \@data;
}

sub _get_timestamps {
	my %args = @_;
	my $dbh = $args{'dbh'};
	my $query = "SELECT now() - ? * interval '1 hours' AS time";
	my $sth = $dbh->prepare($query);
	$sth->execute(0);
	my $now = $sth->fetchrow_hashref->{time};
	$sth->execute($args{'delta'});
	my $then = $sth->fetchrow_hashref->{time};
	return ($now, $then);
}

sub _convert_bytes {
	my %args = @_;
	my $result;
	$result->{'bps'} = sprintf("%0.2f", ($args{'bytes'} * 8 / 60 / ($args{'time'} * 60)));
	if ($args{'human'}) {
		if ($result->{'bps'} >= 1000000000) {
			$result->{'bps_human'} = sprintf("%0.2f", ($result->{'bps'} / 1000000000)) . " Gbps";
		} elsif ($result->{'bps'} >= 1000000) {
			$result->{'bps_human'} = sprintf("%0.2f", ($result->{'bps'} / 1000000)) . " Mbps";
		} elsif ($result->{'bps'} >= 1000) {
			$result->{'bps_human'} = sprintf("%0.2f", ($result->{'bps'} / 1000)) . " Kbps";
		} else {
			$result->{'bps_human'} = $result->{'bps'} . " bps";
		}
	}
	return $result;
}


1;
