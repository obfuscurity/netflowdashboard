package Monitor::FlowDetail;

use strict;

sub new {
	my $class = shift;
	bless { @_ }, $class;
}

sub gather {
	my $self = shift;
	my %args = @_;
	my $dbh = $args{'dbh'};
	my $cgi = $args{'cgi'};
	my @flowdetails;
	my $query = "SELECT * ";
	$query   .= "FROM flows_template ";
	$query   .= "WHERE src_addr=? ";
	$query   .= "AND src_port=? ";
	$query   .= "AND dst_addr=? ";
	$query   .= "AND dst_port=?";
	my $sth = $dbh->prepare($query);
	$sth->execute($cgi->param('sa'), $cgi->param('sp'), $cgi->param('da'), $cgi->param('dp')) || die $dbh->errstr;
	while (my $result = $sth->fetchrow_hashref) {
		push(@flowdetails, $result);
	}
	$self->{'list'} = \@flowdetails;
	$self->{'subtitle'} = "Flow Detail";
	return;
}


1;
