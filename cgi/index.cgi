#!/usr/bin/perl -w

use strict;
no warnings qw(redefine);
use Monitor::Devices;
use Monitor::Groups;
use Monitor::Services;
use Monitor::TopServiceHosts;
use Monitor::Connections;
use Monitor::Hosts;
use Monitor::TopHosts;
use Monitor::FlowDetail;
use Monitor::Graph;

my $dbname = 'nfdb';
my $dbuser = 'nfdb_user';
my $dbpass = 'nfdb_pass';
my $dbport = '3306';
my $dsn = "DBI:Pg:database=$dbname;host=127.0.0.1;port=5432";

my $dbh = DBI->connect($dsn, $dbuser, $dbpass, { PrintError => 1, AutoCommit => 1 });
my $cgi = CGI->new;

my $index;

if ($cgi->http('HTTP_X_REQUESTED_WITH') eq 'XMLHttpRequest' && $cgi->param('v')) {
	$index = 'tabs';
} elsif ($cgi->http('HTTP_X_REQUESTED_WITH') eq 'XMLHttpRequest') {
	$index = 'ajax';
} else {
	$index = 'index';
}
my $template = HTML::Template->new(filename => "Templates/${index}.tmpl", die_on_bad_params => 0);

SWITCH: {
	if ($cgi->user_agent('safari')) { $template->param(safari => 1); last SWITCH; };
	if ($cgi->user_agent('msie')) { $template->param(msie => 1); last SWITCH; };
	$template->param(a_working_browser => 1);
}

# Gather early, used often
my $device_obj = Monitor::Devices->new;
$device_obj->gather(dbh => $dbh, cgi => $cgi);
my $agents = $device_obj->get_devices(dbh => $dbh);
my $groups_obj = Monitor::Groups->new;
$groups_obj->gather(dbh => $dbh, cgi => $cgi);

# "Controller" (yeah right)
if ($cgi->param('v')) {
	if ($cgi->param('v') eq 'traffic') {
		my $traffic_obj = Monitor::Traffic->new;
		$traffic_obj->gather(dbh => $dbh, cgi => $cgi);
		print "Content-Type: text/html\n\n", $template->output;
	} elsif ($cgi->param('v') eq 'adjtime') {
		my $url = $cgi->referer;
		if ($url =~ /(.*t\=)(\d+)(.*)/) {
			$url = $1 . $cgi->param('nt') . $3;
		} elsif ($url =~ /(.*t\=)(.*)/) {
			$url = $1 . $cgi->param('nt') . $2;
		} else {
			$url = $url . '&t=' . $cgi->param('nt');
		}
		print $cgi->redirect($url);
	} elsif ($cgi->param('v') eq 'services') {
		unless (($cgi->param('d') =~ /\w+/) && ($cgi->param('i') =~ /\d+/)) {
			default_view();
		} elsif ($cgi->param('p') =~ /\d+/) {
			my $topservicehosts_obj = Monitor::TopServiceHosts->new;
			$topservicehosts_obj->gather(dbh => $dbh, cgi => $cgi);
			my $graph_src_obj = Monitor::Graph->new;
			$graph_src_obj->gather(
				label => 'src_addr',
				value => 'bytes_utz',
				suffix => 'src',
				data => $topservicehosts_obj->{'list'},
				options => { label => 'Sources - % of Traffic' },
			);
			my $graph_dst_obj = Monitor::Graph->new;
			$graph_dst_obj->gather(
				label => 'dst_addr',
				value => 'bytes_utz',
				suffix => 'dst',
				data => $topservicehosts_obj->{'list'},
				options => { label => 'Destinations - % of Traffic' },
			);
			$template->param(connections => 'true');
			$template->param(connections_loop => $topservicehosts_obj->{'list'});
			$template->param(groups_loop => $groups_obj->{'list'}) if ($groups_obj->{'list'});
			$template->param(graph_left => $graph_src_obj->{'filename'});
			$template->param(graph_left_legend_loop => $graph_src_obj->{'legend'});
			$template->param(graph_right => $graph_dst_obj->{'filename'});
			$template->param(graph_right_legend_loop => $graph_src_obj->{'legend'});
			$template->param(subtitle => $topservicehosts_obj->{'subtitle'});
			$template->param(time => ($cgi->param('t') || 1));
			$template->param(agent => $agents->{$cgi->param('d')}->{'name'});
			#$template->param(dump => Dumper($topservicehosts_obj));
			print "Content-Type: text/html\n\n", $template->output;
		} else {
			my $services_obj = Monitor::Services->new;
			$services_obj->gather(dbh => $dbh, cgi => $cgi);
			my $graph_service_obj = Monitor::Graph->new;
			$graph_service_obj->gather(
				label => 'service_name',
				value => 'bytes_utz',
				suffix => 'svc',
				data => $services_obj->{'list'},
				options => { label => 'Services - % of Traffic' },
			);
			my $graph_protocol_obj = Monitor::Graph->new;
			$graph_protocol_obj->gather(
				label => 'protocol_name',
				value => 'bytes_utz',
				suffix => 'proto',
				data => $services_obj->{'list'},
				options => { label => 'Protocols - % of Traffic' },
			);
			$template->param(services => 'true');
			$template->param(services_loop => $services_obj->{'list'});
			$template->param(groups_loop => $groups_obj->{'list'}) if ($groups_obj->{'list'});
			$template->param(graph_left => $graph_service_obj->{'filename'});
			$template->param(graph_left_legend_loop => $graph_service_obj->{'legend'});
			$template->param(graph_right => $graph_protocol_obj->{'filename'});
			$template->param(graph_right_legend_loop => $graph_protocol_obj->{'legend'});
			$template->param(subtitle => $services_obj->{'subtitle'});
			$template->param(time => ($cgi->param('t') || 1));
			$template->param(agent => $agents->{$cgi->param('d')}->{'name'});
			#$template->param(dump => Dumper($services_obj));
			print "Content-Type: text/html\n\n", $template->output;
		}
	} elsif ($cgi->param('v') eq 'hosts') {
		unless (($cgi->param('host_side') =~ /src|dst/) && ($cgi->param('d') =~ /\w+/) && ($cgi->param('i') =~ /\d+/)) {
			default_view();
		} elsif ($cgi->param('h') =~ /\w+/) {
			my $tophosts_obj = Monitor::TopHosts->new;
			$tophosts_obj->gather(dbh => $dbh, cgi => $cgi);
			$template->param(connections => 'true');
			$template->param(connections_loop => $tophosts_obj->{'list'});
			$template->param(groups_loop => $groups_obj->{'list'}) if ($groups_obj->{'list'});
			$template->param(subtitle => $tophosts_obj->{'subtitle'});
			$template->param(time => ($cgi->param('t') || 1));
			$template->param(agent => $agents->{$cgi->param('d')}->{'name'});
			#$template->param(dump => Dumper($tophosts_obj->{'list'}));
			print "Content-Type: text/html\n\n", $template->output;
		} else {
			my $hosts_obj = Monitor::Hosts->new;
			$hosts_obj->gather(dbh => $dbh, cgi => $cgi);
			my $graph_obj = Monitor::Graph->new;
			$graph_obj->gather(
				label => 'addr',
				value => 'bytes_utz',
				data => $hosts_obj->{'list'},
				options => { label => '% of Total Traffic' },
			);
			$template->param(hosts => 'true');
			$template->param(hosts_loop => $hosts_obj->{'list'});
			$template->param(groups_loop => $groups_obj->{'list'}) if ($groups_obj->{'list'});
			$template->param(graph => $graph_obj->{'filename'});
			$template->param(graph_legend_loop => $graph_obj->{'legend'});
			$template->param(subtitle => $hosts_obj->{'subtitle'});
			$template->param(time => ($cgi->param('t') || 1));
			$template->param(agent => $agents->{$cgi->param('d')}->{'name'});
			print "Content-Type: text/html\n\n", $template->output;
		}
	} elsif ($cgi->param('v') eq 'connections') {
		unless (($cgi->param('d') =~ /\w+/) && ($cgi->param('i') =~ /\d+/)) {
			default_view();
		} else {
			my $connections_obj = Monitor::Connections->new;
			$connections_obj->gather(dbh => $dbh, cgi => $cgi);
			my $graph_sources_obj = Monitor::Graph->new;
			my $graph_destinations_obj = Monitor::Graph->new;
			$graph_sources_obj->gather(
				label => 'src_addr',
				value => 'bytes_utz',
				suffix => 'src',
				data => $connections_obj->{'list'},
				options => { label => 'Sources - % of Traffic' },
			);
			$graph_destinations_obj->gather(
				label => 'dst_addr',
				value => 'bytes_utz',
				suffix => 'dst',
				data => $connections_obj->{'list'},
				options => { label => 'Destinations - % of Traffic' },
			);
			$template->param(connections => 'true');
			$template->param(connections_loop => $connections_obj->{'list'});
			$template->param(groups_loop => $groups_obj->{'list'}) if ($groups_obj->{'list'});
			$template->param(graph_left => $graph_sources_obj->{'filename'});
			$template->param(graph_left_legend_loop => $graph_sources_obj->{'legend'});
			$template->param(graph_right => $graph_destinations_obj->{'filename'});
			$template->param(graph_right_legend_loop => $graph_destinations_obj->{'legend'});
			$template->param(subtitle => $connections_obj->{'subtitle'});
			$template->param(time => ($cgi->param('t') || 1));
			$template->param(agent => $agents->{$cgi->param('d')}->{'name'});
			#$template->param(dump => Dumper($connections_obj));
			print "Content-Type: text/html\n\n", $template->output;
		}
	} elsif ($cgi->param('v') eq 'flowdetail') {
		unless (($cgi->param('sa') =~ /\w+/) && ($cgi->param('sp') =~ /\w+/) 
			&& ($cgi->param('da') =~ /\w+/) && ($cgi->param('dp') =~ /\w+/)) {
			default_view();
		} else {
			my $flowdetail_obj = Monitor::FlowDetail->new;
			$flowdetail_obj->gather(dbh => $dbh, cgi => $cgi);
			$template->param(flowdetail => 'true');
			$template->param($flowdetail_obj);
			if (($cgi->param('f') =~ /\d+/) && ($flowdetail_obj->{'list'}->[$cgi->param('f')])) {
				$template->param($flowdetail_obj->{'list'}->[($cgi->param('f') - 1)]);
			} else {
				$template->param($flowdetail_obj->{'list'}->[0]);
			}
			# Pager output
			if (@{$flowdetail_obj->{'list'}} == 1) {
				# array length of 1
				# no pager output
			} elsif (!$cgi->param('f') || $cgi->param('f') == 1) {
				# first page, array length > 1
				$template->param(pager => 'true');
				$template->param(page_current => 1);
				$template->param(page_plus => 2);
				$template->param(page_last => ($#{$flowdetail_obj->{'list'}} + 1));
			} elsif ($#{$flowdetail_obj->{'list'}} == ($cgi->param('f') - 1)) {
				# last page, array length > 1
				$template->param(pager => 'true');
				$template->param(page_first => 1);
				$template->param(page_minus => ($cgi->param('f') - 1));
				$template->param(page_current => $cgi->param('f'));
			} else {
				# all other cases
				$template->param(pager => 'true');
				$template->param(page_first => 1);
				$template->param(page_minus => ($cgi->param('f') - 1));
				$template->param(page_current => $cgi->param('f'));
				$template->param(page_plus => ($cgi->param('f') + 1));
				$template->param(page_last => ($#{$flowdetail_obj->{'list'}} + 1));
			}
			$template->param(groups_loop => $groups_obj->{'list'}) if ($groups_obj->{'list'});
			#$template->param(dump => Dumper($flowdetail_obj));
			print "Content-Type: text/html\n\n", $template->output;
		}
	} else {
		default_view();
	}
} else {
	default_view();
}

sub default_view {
	$template->param(default => 'true');
	$template->param(devices_loop => $device_obj->{'list'});
	$template->param(groups_loop => $groups_obj->{'list'}) if ($groups_obj->{'list'});
	$template->param(subtitle => $device_obj->{'subtitle'});
	$template->param(time => ($cgi->param('t') || 1));
	#$template->param(dump => Dumper($device_obj));
	print "Content-Type: text/html\n\n", $template->output;

	Monitor::Graph->cleanup_old_pngs;
}


