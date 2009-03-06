package Monitor::Services;

use strict;

sub new {
	my $class = shift;
	bless { @_ }, $class;
}

sub gather {
	my $self = shift;
	my %args = @_;
	my %services;
	my $dbh = $args{'dbh'};
	my $cgi = $args{'cgi'};
	my $time = $cgi->param('t') || 1;
	my ($now, $then) = _get_timestamps(dbh => $dbh, delta => $time);
	my $limit = $cgi->param('c') || 10;
	my $sort_field = $cgi->param('order_by') || 'bytes';
	my $bandwidth_total = _get_bandwidth(dbh => $dbh, cgi => $cgi, then => $then, now => $now);
	my $services_info = _get_services(dbh => $dbh);
	my $protocols_info = _get_protocols(dbh => $dbh);
	for my $direction qw( src dst ) {
		my $query = "SELECT SUM(flow_octets) as bytes, ${direction}_port, protocol, agent_addr ";
		$query   .= "FROM flows ";
		$query   .= "WHERE ${direction}_port < 1024 ";
		$query   .= "AND agent_addr=? ";
		$query   .= "AND flow_timestamp >= ? AND flow_timestamp < ? ";
		$query   .= "AND (if_index_in=? OR if_index_out=?) ";
		$query   .= "GROUP BY ${direction}_port, protocol, agent_addr ";
		$query   .= "ORDER BY $sort_field desc ";
		$query   .= "LIMIT ?";
		my $sth = $dbh->prepare($query);
		$sth->bind_param(5, ($limit * 2), { TYPE => DBI::SQL_INTEGER });
		$sth->execute($cgi->param('d'), $then, $now, $cgi->param('i'), $cgi->param('i'), ($limit * 2)) || die $dbh->errstr;
		while (my $result = $sth->fetchrow_hashref) {
			$result->{'service'} = $result->{"${direction}_port"};
			$services{$result->{'service'}} = $result unless (exists $services{$result->{'service'}});
			$services{$result->{'service'}}->{'bytes_in'} = $result->{'bytes'} if ($direction eq 'dst');
			$services{$result->{'service'}}->{'bytes_out'} = $result->{'bytes'} if ($direction eq 'src');
			$services{$result->{'service'}}->{'service'} = $result->{"${direction}_port"};
			$services{$result->{'service'}}->{'service_name'} = $services_info->{$result->{"${direction}_port"}} || $result->{"${direction}_port"};
			$services{$result->{'service'}}->{'protocol_name'} = $protocols_info->{$result->{'protocol'}} || $result->{'protocol'};
			$services{$result->{'service'}}->{'if_index'} = $cgi->param('i');
		}
	}
	foreach (values %services) {
		$_->{'bytes_in'} ||= 0;
		$_->{'bytes_out'} ||= 0;
		$_->{'bytes_total'} = ($_->{'bytes_in'} + $_->{'bytes_out'});
		$_->{'bytes_utz'} = sprintf(("%d", ($_->{'bytes_total'} / $bandwidth_total->{'bytes'}) * 100));
		$_->{'bytes_utz_neg'} = (100 - $_->{'bytes_utz'});
		$_->{'bytes_utz_color'} = ($_->{'bytes_utz'} > 80) ? 'warn' : 'ok';
		$_->{'bytes_utz_color'} = ($_->{'bytes_utz'} > 90) ? 'emerg' : 'ok';
		$_->{'bytes_human'} = _convert_bytes($_->{'bytes_total'});
		$_->{'time'} = $time;
		for my $direction qw( in out ) {
			$_->{"bytes_${direction}_utz"} = ($_->{"bytes_${direction}"} == 0) ? 0 : sprintf(("%d", ($_->{"bytes_${direction}"} / $_->{'bytes_total'}) * 100));
			$_->{"bytes_${direction}_utz_neg"} = (100 - $_->{"bytes_${direction}_utz"});
			$_->{"bytes_${direction}_utz_color"} = ($_->{"bytes_${direction}_utz"} > 80) ? 'warn' : 'ok';
		}
	}
	my @services = sort { $b->{'bytes_total'} <=> $a->{'bytes_total'} } values %services;
	my @final_services = (@services > $limit) ? @services[0..($limit-1)] : @services;
	$self->{'list'} = \@final_services;
	$self->{'subtitle'} = "Services&nbsp;&nbsp;(Last $time hour/s)";
	return;
}

sub _get_bandwidth {
	my %args = @_;
	my $dbh = $args{'dbh'};
	my $cgi = $args{'cgi'};
	my $query = "SELECT SUM(flow_octets) as bytes ";
	$query   .= "FROM flows ";
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
