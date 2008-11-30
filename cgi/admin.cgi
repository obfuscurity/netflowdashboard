#!/usr/bin/perl -w

use strict;
no warnings qw(redefine);
use Admin::Devices;

my $dbname = 'netmon';
my $dbuser = 'netmon_user';
my $dbpass = 'N3tm0n_U53r';
my $dsn = "DBI:mysql:database=$dbname";

my $dbh = DBI->connect($dsn, $dbuser, $dbpass, { PrintError => 1, AutoCommit => 1 });
my $cgi = CGI->new;
my $template = HTML::Template->new(filename => 'Templates/admin.tmpl', die_on_bad_params => 0);

#if ($cgi->param('v')) {
#	if ($cgi->param('v') eq 'traffic') {
#		my $traffic_obj = Monitor::Traffic->new;
#		$traffic_obj->gather(dbh => $dbh, cgi => $cgi);
#		print "Content-Type: text/html\n\n", $template->output;
#	} elsif ($cgi->param('v') eq 'flowdetail') {
#		unless (($cgi->param('sa') =~ /\w+/) && ($cgi->param('sp') =~ /\w+/) 
#			&& ($cgi->param('da') =~ /\w+/) && ($cgi->param('dp') =~ /\w+/)) {
#			default_view();
#		} else {
#			my $flowdetail_obj = Monitor::FlowDetail->new;
#			$flowdetail_obj->gather(dbh => $dbh, cgi => $cgi);
#			$template->param(flowdetail => 'true');
#			$template->param($flowdetail_obj);
#			print "Content-Type: text/html\n\n", $template->output;
#		}
#	} else {
#		default_view();
#	}
#} else {
	default_view();
#}

sub default_view {
	my $admin_obj = Admin::Devices->new;
	$admin_obj->gather(dbh => $dbh);
	$template->param(default => 'true');
	$template->param(devices_loop => $admin_obj->{'devices_list'});
	$template->param(groups_loop => $admin_obj->{'groups_list'});
	#$template->param(dump => Dumper($admin_obj));
	print "Content-Type: text/html\n\n", $template->output;
}


