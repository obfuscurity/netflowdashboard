package Admin::Devices;

use strict;
use Data::Dumper;


sub new {
	my $class = shift;
	bless { @_ }, $class;
}

sub gather {
	my $self = shift;
	my %args = @_;
	my $dbh = $args{'dbh'};
	$self->_get_devices(dbh => $dbh);
	$self->_get_groups(dbh => $dbh);
	return;
}

sub _get_devices {
	my $self = shift;
	my %args = @_;
	my $dbh = $args{'dbh'};
	my $query = "SELECT * FROM devices ORDER BY device_addr";
	my $sth = $dbh->prepare($query);
	$sth->execute || die $dbh->errstr;
	my @data;
	while (my $result = $sth->fetchrow_hashref) {
		push(@data, $result);
	}
	$self->{'devices_list'} = \@data;
	return;
}

sub _get_groups {
	my $self = shift;
	my %args = @_;
	my $dbh = $args{'dbh'};
	my $query = "SELECT g.id, g.name, g.description, m.device_addr, d.name ";
	$query   .= "AS member_name ";
	$query   .= "FROM groups ";
	$query   .= "AS g ";
	$query   .= "LEFT OUTER JOIN groups_members ";
	$query   .= "AS m ";
	$query   .= "ON g.id=m.group_id ";
	$query   .= "LEFT OUTER JOIN devices ";
	$query   .= "AS d ";
	$query   .= "ON m.device_addr=d.device_addr ";
	$query   .= "ORDER BY g.id, m.device_addr";
	my $sth = $dbh->prepare($query);
	$sth->execute || die $dbh->errstr;
	my %data;
	while (my $result = $sth->fetchrow_hashref) {
		$data{$result->{'id'}}{'id'} = $result->{'id'};
		$data{$result->{'id'}}{'name'} = $result->{'name'};
		$data{$result->{'id'}}{'description'} = $result->{'description'};
		push(@{$data{$result->{'id'}}{'groups_members_loop'}}, {
			'id' => $result->{'id'},
			'device_addr' => $result->{'device_addr'},
			'member_name' => $result->{'member_name'} || $result->{'device_addr'},
		});
	}
	my @groups = values %data;
	$self->{'groups_list'} = \@groups;
	return;
}

sub add_device {
	my $self = shift;
	my %args = @_;
	my $dbh = $args{'dbh'};
	my $cgi = $args{'cgi'};
	my $devices = _get_devices();
	if (grep($cgi->param('a'), @{$devices->{'device_addr'}})) {
		$self->{'error'} = "Device address $cgi->param('a') already exists";
		return;
	} else {
		my $query = "INSERT INTO devices VALUES (?,?,?)";
		my $sth = $dbh->prepare($query);
		$sth->execute($cgi->param('a'), ($cgi->param('n') || 'NULL'), ($cgi->param('d') || 'NULL')) || die $dbh->errstr;
		return;
	}
}

sub modify_device {
	my $self = shift;
	my %args = @_;
	my $dbh = $args{'dbh'};
	my $cgi = $args{'cgi'};
	my $devices = _get_devices();
	unless (grep($cgi->param('a'), @{$devices->{'device_addr'}})) {
		$self->{'error'} = "Device address $cgi->param('a') not found";
		return;
	} else {
		my $query = "UPDATE devices SET name=?, description=? WHERE device_addr=?";
		my $sth = $dbh->prepare($query);
		$sth->execute(($cgi->param('n') || 'NULL'), ($cgi->param('d') || 'NULL'), $cgi->param('a')) || die $dbh->errstr;
		return;
	}
}

sub delete_device {
	my $self = shift;
	my %args = @_;
	my $dbh = $args{'dbh'};
	my $cgi = $args{'cgi'};
	my $devices = _get_devices();
	unless (grep($cgi->param('a'), @{$devices->{'device_addr'}})) {
		$self->{'error'} = "Device address $cgi->param('a') not found";
		return;
	} else {
		{
			my $query = "DELETE FROM groups_members WHERE device_addr=?";
			my $sth = $dbh->prepare($query);
			$sth->execute($cgi->param('a')) || die $dbh->errstr;
		}
		{
			my $query = "DELETE FROM devices WHERE device_addr=?";
			my $sth = $dbh->prepare($query);
			$sth->execute($cgi->param('a')) || die $dbh->errstr;
		}
		return;
	}
}

sub add_group {
	my $self = shift;
	my %args = @_;
	my $dbh = $args{'dbh'};
	my $cgi = $args{'cgi'};
	my $groups = _get_groups();
	if (grep($cgi->param('gn'), @{$groups->{'name'}})) {
		$self->{'error'} = "Group $cgi->param('gn') already exists";
		return;
	} else {
		my $query = "INSERT INTO groups (name, description) VALUES (?,?)";
		my $sth = $dbh->prepare($query);
		$sth->execute($cgi->param('gn'), ($cgi->param('gd') || 'NULL')) || die $dbh->errstr;
		return;
	}
}

sub modify_group {
	my $self = shift;
	my %args = @_;
	my $dbh = $args{'dbh'};
	my $cgi = $args{'cgi'};
	my $groups = _get_groups();
	unless (grep($cgi->param('gid'), @{$groups->{'id'}})) {
		$self->{'error'} = "Group ID $cgi->param('gid') \(\"$cgi->param('gn')\"\) not found";
		return;
	} else {
		my $query = "UPDATE groups SET name=?, description=? WHERE id=?";
		my $sth = $dbh->prepare($query);
		$sth->execute($cgi->param('gn'), ($cgi->param('gd') || 'NULL'), $cgi->param('gid')) || die $dbh->errstr;
		return;
	}
}

sub delete_group {
	my $self = shift;
	my %args = @_;
	my $dbh = $args{'dbh'};
	my $cgi = $args{'cgi'};
	my $groups = _get_groups();
	unless (grep($cgi->param('gid'), @{$groups->{'id'}})) {
		$self->{'error'} = "Group ID $cgi->param('gid') not found";
		return;
	} else {
		{
			my $query = "DELETE FROM groups_members WHERE group_id=?";
			my $sth = $dbh->prepare($query);
			$sth->execute($cgi->param('gid')) || die $dbh->errstr;
		}
		{
			my $query = "DELETE FROM groups WHERE id=?";
			my $sth = $dbh->prepare($query);
			$sth->execute($cgi->param('gid')) || die $dbh->errstr;
		}
		return;
	}
}

sub add_group_member {
	my $self = shift;
	my %args = @_;
	my $dbh = $args{'dbh'};
	my $cgi = $args{'cgi'};
	my $group_members = _get_groups_members($cgi->param('gid'));
	if (grep($cgi->param('da'), @$group_members)) {
		$self->{'error'} = "Device $cgi->param('da') already belongs to this group";
		return;
	} else {
		delete_group_member(\%args);
		my $query = "INSERT INTO groups_members (device_addr, group_id) VALUES (?,?)";
		my $sth = $dbh->prepare($query);
		$sth->execute($cgi->param('da'), $cgi->param('gid')) || die $dbh->errstr;
		return;
	}
}

sub delete_group_member {
	my $self = shift;
	my %args = @_;
	my $dbh = $args{'dbh'};
	my $cgi = $args{'cgi'};
	my $group_members = _get_groups_members($cgi->param('gid'));
	unless (grep($cgi->param('da'), @$group_members)) {
		$self->{'error'} = "Device $cgi->param('da') not a member of this group";
		return;
	} else {
		my $query = "DELETE FROM groups_members WHERE device_addr=? AND group_id=?";
		my $sth = $dbh->prepare($query);
		$sth->execute($cgi->param('da'), $cgi->param('gid')) || die $dbh->errstr;
		return;
	}
}


1;
