#!/usr/bin/perl

use strict;
use POSIX;
use Flowd;
use DBI;
use Getopt::Std;


# Catch SIGINT
$SIG{'INT'} = sub { tidy_up(); };

# Check options
our($opt_D);
getopts('D');
my $debug = $opt_D;

# Flowd options
my $flowd_bin = '/usr/local/sbin/flowd';
my $flowd_pidfile = '/var/run/flowd.pid';
my $flowd_socket = '/tmp/flowpipe';

# Database options
my $dbname = 'nfdb';
my $dbuser = 'nfdb_user';
my $dbpass = 'nfdb_pass';
my $dsn = "DBI:Pg:database=$dbname;host=127.0.0.1;port=5432";
my $dbh = DBI->connect($dsn, $dbuser, $dbpass, { PrintError => 0, RaiseError => 1, AutoCommit => 1 }) || die $DBI::errstr;
my $oid_error = 0;

# Define our SQL queries
my $flow_insert = "INSERT INTO flows_template VALUES (?,now(),?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
my $flow_update = "UPDATE flows_template SET flow_octets = flow_octets + ?, flow_packets = flow_packets + ? WHERE (src_addr IN (?,?) AND dst_addr IN (?,?)) AND (src_port IN (?,?) AND dst_port IN (?,?)) AND flow_start=? AND flow_finish=? AND agent_addr=?";

# Prepare our SQL queries
my $sth_flow_insert = $dbh->prepare($flow_insert);
my $sth_flow_update = $dbh->prepare($flow_update);

# Open our NetFlow collector
start_flowd();
my $flowd = Flowd->new($flowd_socket);
read_flows();
tidy_up();


# Subfunctions
sub read_flows {
	while (my $result = $flowd->read_flow) {
	
		if ($debug) {
			print "$result->{src_addr}\:$result->{src_port} ";
			print "=> $result->{dst_addr}\:$result->{dst_port}, ";
			print "$result->{flow_packets} packets ";
		}
	
		my $rows = insert_new_flow($result);
	}
	return;
}

sub insert_new_flow {
	my $flow = shift;
	eval {
		$sth_flow_insert->execute(
			$flow->{protocol},
			$flow->{time_nanosec},
			$flow->{recv_sec},
			$flow->{sys_uptime_ms},
			$flow->{src_addr},
			$flow->{src_mask},
			$flow->{src_port},
			$flow->{src_addr_af},
			$flow->{src_as},
			$flow->{dst_addr},
			$flow->{dst_mask},
			$flow->{dst_port},
			$flow->{dst_addr_af},
			$flow->{dst_as},
			$flow->{gateway_addr},
			$flow->{gateway_addr_af},
			$flow->{agent_addr},
			$flow->{agent_addr_af},
			$flow->{if_index_in},
			$flow->{if_index_out},
			$flow->{flow_start},
			$flow->{flow_finish},
			$flow->{flow_octets},
			$flow->{flow_packets},
			$flow->{tcp_flags},
			$flow->{tos},
			$flow->{crc},
			$flow->{fields},
			$flow->{netflow_version},
			$flow->{engine_id},
			$flow->{engine_type},
		);
	};

	if ($@) {
		update_existing_flow($flow);
	} else {
		print "row INSERTED\n" if $debug;
	}

	return;
}

sub update_existing_flow {
	my $flow = shift;
	eval {
		$sth_flow_update->execute(
			$flow->{flow_octets},
			$flow->{flow_packets},
			$flow->{src_addr},
			$flow->{dst_addr},
			$flow->{src_addr},
			$flow->{dst_addr},
			$flow->{src_port},
			$flow->{dst_port},
			$flow->{src_port},
			$flow->{dst_port},
			$flow->{flow_start},
			$flow->{flow_finish},
			$flow->{agent_addr},
		) || die $dbh->errstr;
	};

	if ($@) {
		$oid_error++;
		die $@ if ($oid_error >= 5);
		sleep(1);
		update_existing_flow($flow);
	}

	print "row UPDATED\n" if $debug;
	return;
}

sub start_flowd {
	unlink $flowd_socket;
	mkfifo($flowd_socket, 0644);
	my $status = system("$flowd_bin");
	if ($? == -1) {
		unlink $flowd_socket;
		die "Unable to start flowd: $!\n";
	} elsif ($? & 127) {
		printf("Child died with signal %d, %s coredump\n",
			($? & 1277), ($? & 128) ? 'with' : 'without');
		unlink $flowd_socket;
		die "Unable to start flowd: $!\n";
	}
	return;
}

sub tidy_up {
	$SIG{'INT'} = sub { print STDERR "Finishing up, please be patient...\n"; };
	print STDERR "\n$0 exiting\n\n" if $debug;
	system("kill `cat $flowd_pidfile` 2>/dev/null");
	read_flows();
	$flowd->finish if $flowd;
	$sth_flow_insert->finish if $sth_flow_insert;
	$sth_flow_update->finish if $sth_flow_update;
	$dbh->disconnect if $dbh;
	unlink $flowd_socket;
	exit;
}


