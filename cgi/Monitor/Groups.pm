package Monitor::Groups;

use strict;

sub new {
	my $class = shift;
	bless { @_ }, $class;
}

sub gather {
	my $self = shift;
	my %args = @_;
	my %groups;
	my $dbh = $args{'dbh'};
	my $cgi = $args{'cgi'};
	my $query = "SELECT * from groups";
	my $sth = $dbh->prepare($query);
	$sth->execute || $dbh->errstr;
	while (my $result = $sth->fetchrow_hashref) {
		$result->{'time'} = $cgi->param('t') || 1;
		push(@{$self->{'list'}}, $result);
	}
	return;
}


1;
