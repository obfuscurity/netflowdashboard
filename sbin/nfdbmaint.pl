#!/usr/bin/perl

use strict;
use DBI;
use Getopt::Std;


# Check options
our($opt_s);
getopt('s');
my $days = $opt_s;

# Calendar days of flows to keep;  e.g. $days = 2 means today 
# and yesterday, we delete the day before yesterday
$days ||= 1;

# Database options
my $dbname = 'nfdb';
my $dbuser = 'nfdb_admin';
my $dbpass = 'nfdb_admin_pass';
my $dsn = "DBI:Pg:database=$dbname;host=127.0.0.1;port=5432";
my $dbh = DBI->connect($dsn, $dbuser, $dbpass, { RaiseError => 1, AutoCommit => 1 }) || die $DBI::errstr;

# Define our SQL queries
my $create_tables_stmt = "SELECT create_nextday_flow_partitions()";
my $rebuild_trigger_stmt = "SELECT rebuild_flows_insert_trigger()";
my $drop_tables_stmt = "SELECT drop_day_flow_partitions(?)";

# Prepare our SQL queries
my $sth_create_tables = $dbh->prepare($create_tables_stmt);
my $sth_rebuild_trigger = $dbh->prepare($rebuild_trigger_stmt);
my $sth_drop_tables = $dbh->prepare($drop_tables_stmt);

# Execute our SQL queries
$sth_create_tables->execute;
$sth_rebuild_trigger->execute;
$sth_drop_tables->execute($days);

# Close our SQL queries
$sth_create_tables->finish;
$sth_rebuild_trigger->finish;
$sth_drop_tables->finish;

$dbh->disconnect;
