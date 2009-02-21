package Monitor::Hosts;

use strict;

sub new {
	my $class = shift;
	bless { @_ }, $class;
}

sub gather {
	my $self = shift;
	my %args = @_;
	my %hosts;
	my $dbh = $args{'dbh'};
	my $cgi = $args{'cgi'};
	my $time = $cgi->param('t') || 1;
	my ($now, $then) = _get_timestamps(dbh => $dbh, delta => $time);
	my $sort_field = $cgi->param('order_by') || 'bytes';
	my $prefix = $cgi->param('host_side');
	my $query = "SELECT ${prefix}_addr as addr, agent_addr, ";
	$query   .= "SUM(flow_octets) as bytes ";
	$query   .= "FROM flows_template ";
	$query   .= "WHERE agent_addr=? ";
	$query   .= "AND flow_timestamp >= ? AND flow_timestamp < ? ";
	$query   .= "AND (if_index_in=? OR if_index_out=?) ";
	$query   .= "GROUP BY ${prefix}_addr, agent_addr ";
	$query   .= "ORDER BY $sort_field desc ";
	$query   .= "LIMIT ?";
	my $sth = $dbh->prepare($query);
	$sth->bind_param(5, ($cgi->param('c') || 10), { TYPE => DBI::SQL_INTEGER });
	$sth->execute($cgi->param('d'), $then, $now, $cgi->param('i'), $cgi->param('i'), ($cgi->param('c') || 10)) || die $dbh->errstr;
	my @hosts;
	my $bandwidth_total = _get_bandwidth(dbh => $dbh, cgi => $cgi, then => $then, now => $now);
	#my $services_info = _get_services(dbh => $dbh);
	#my $protocols_info = _get_protocols(dbh => $dbh);
	while (my $result = $sth->fetchrow_hashref) {
		$result->{'bytes_human'} = _convert_bytes($result->{'bytes'});
		$result->{'bytes_utz'} = sprintf(("%d", ($result->{'bytes'} / $bandwidth_total->{'bytes'}) * 100));
		$result->{'bytes_utz_neg'} = (100 - $result->{'bytes_utz'});
		$result->{'bytes_utz_color'} = ($result->{'bytes_utz'} > 80) ? 'warn' : 'ok';
		$result->{'bytes_utz_color'} = ($result->{'bytes_utz'} > 90) ? 'emerg' : 'ok';
		$result->{'time'} = $time;
		$result->{'host_side'} = $prefix;
		$result->{'index'} = $cgi->param('i');
		push(@hosts, $result);
	}
	$self->{'list'} = \@hosts;
	if ($cgi->param('host_side') eq 'src') {
		$self->{'subtitle'} = "Sources&nbsp;&nbsp;(Last $time hour/s)";
	} else {
		$self->{'subtitle'} = "Destinations&nbsp;&nbsp;(Last $time hour/s)";
	}
	return;
}

sub _get_bandwidth {
    my %args = @_;
    my $dbh = $args{'dbh'};
    my $cgi = $args{'cgi'};
    my $query = "SELECT SUM(flow_octets) as bytes ";
    $query   .= "FROM flows_template ";
    $query   .= "WHERE agent_addr=? ";
    $query   .= "AND flow_timestamp >= ? AND flow_timestamp < ? ";
    $query   .= "AND (if_index_in=? OR if_index_out=?)";
    my $sth = $dbh->prepare($query);
    $sth->execute($cgi->param('d'), $args{'then'}, $args{'now'}, $cgi->param('i'), $cgi->param('i')) || die $dbh->errstr;
    my $result = $sth->fetchrow_hashref;
    return $result;
}

sub _get_services {
	my %args = @_;
	my $dbh = $args{'dbh'};
	my %services_merged;
	for my $table qw( default custom ) {
		my $query = "SELECT * from services_${table}";
		my $sth = $dbh->prepare($query);
		$sth->execute || die $dbh->errstr;
		while (my $result = $sth->fetchrow_hashref) {
			$services_merged{$result->{'port'}} = $result->{'name'};
		}
	}
	return \%services_merged;
}

sub _get_protocols {
	my %args = @_;
	my $dbh = $args{'dbh'};
	my %protocols_merged;
	for my $table qw( default custom ) {
		my $query = "SELECT * from protocols_${table}";
		my $sth = $dbh->prepare($query);
		$sth->execute || die $dbh->errstr;
		while (my $result = $sth->fetchrow_hashref) {
			$protocols_merged{$result->{'number'}} = $result->{'name'};
		}
	}
	return \%protocols_merged;
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
	my $bytes = shift;
	if ($bytes >= 1000000000) {
		return sprintf("%0.2f", ($bytes / 1000000000)) . " GB";
	} elsif ($bytes >= 1000000) {
		return sprintf("%0.2f", ($bytes / 1000000)) . " MB";
	} elsif ($bytes >= 1000) {
		return sprintf("%0.2f", ($bytes / 1000)) . " KB";
	} else {
		return "$bytes bytes";
	}
}


1;
