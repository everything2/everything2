#!/usr/bin/env ruby
#
# test-db-auth.rb — launch a one-off Fargate task (the deployed e2app image) that
# connects to the production RDS as a given DB user, using the app's exact
# DBD::mysql connection path (mysql_ssl=1 + mysql_get_server_pubkey=1) and the
# app's real secret password. Confirms an auth-plugin migration (e.g. everyuser2
# on caching_sha2_password, #4211) works end-to-end BEFORE flipping the live app
# config — no production.json deploy, zero risk to the running site.
#
# Usage:
#   ops/test-db-auth.rb               # tests 'everyuser2' (default)
#   ops/test-db-auth.rb --user NAME   # tests an arbitrary user
#
# Result is the container exit code: 0 = AUTH OK, non-zero = AUTH FAIL. The full
# message ("AUTH OK: connected as <user>@...") is in the e2cron-family CloudWatch
# log group.

require 'aws-sdk-ecs'
require 'aws-sdk-ec2'
require 'getoptlong'

ec2client = Aws::EC2::Client.new(region: 'us-west-2')
ecsclient = Aws::ECS::Client.new(region: 'us-west-2')

db_user = 'everyuser2'
opts = GetoptLong.new(['--user', '-u', GetoptLong::REQUIRED_ARGUMENT])
opts.each do |opt, arg|
  db_user = arg if opt == '--user'
end

# Same VPC placement the other one-off runners use (cron-runner.rb / nodepack-refresh.rb)
subnet_placement = nil
security_group = nil
ec2client.describe_subnets.subnets.each do |subnet|
  subnet.tags.each do |tag|
    if tag.key.eql? 'aws:cloudformation:logical-id' and tag.value.eql? 'AppVPCSubnet1'
      subnet_placement = subnet.subnet_id
    end
  end
end
ec2client.describe_security_groups.security_groups.each do |sg|
  security_group = sg.group_id if sg.group_name.eql? 'E2-App-Webhead-Security-Group'
end

if subnet_placement.nil?
  puts "Couldn't find subnet for placement of task"
  exit 1
end
if security_group.nil?
  puts "Couldn't find security group for placement of task"
  exit 1
end

# Inline Perl: load the REAL app config (so the host comes from E2_DBSERV and the
# password from the real database_password_secret), then connect as $db_user with
# the app's exact DSN flags. The username is overridden to the test user; the
# password is whatever the app would use (the shared secret). Exit 0/1 = pass/fail.
perl = <<~'PERL'
  use strict; use warnings;
  use lib '/var/everything/ecore';
  use Everything::Configuration;
  use DBI;
  my $u = shift || 'everyuser2';
  my $c = Everything::Configuration->new();
  my $host = $c->everything_dbserv;
  my $dsn = 'DBI:mysql:database=' . $c->database
          . ';host=' . $host
          . ';port=' . $c->everything_dbport
          . ';mysql_ssl=1;mysql_get_server_pubkey=1';
  print "Testing DBD::mysql auth as '$u' against $host (app DSN: TLS + server pubkey)...\n";
  my $dbh = DBI->connect($dsn, $u, $c->everypass, { RaiseError => 0, PrintError => 1 });
  if (!$dbh) { print "AUTH FAIL for '$u': $DBI::errstr\n"; exit 1; }
  my ($who) = $dbh->selectrow_array('SELECT CURRENT_USER()');
  print "AUTH OK: connected as $who via the app DBD::mysql / caching_sha2 path\n";
  $dbh->disconnect;
  exit 0;
PERL

puts "Launching one-off Fargate task (e2cron-family, deployed image) to test DB auth as '#{db_user}'..."
puts "This does NOT change the live app config — it only opens a connection and exits."

result = ecsclient.run_task(
  cluster: 'E2-App-ECS-Cluster',
  task_definition: 'e2cron-family',
  overrides: { container_overrides: [{ name: 'e2app', command: ['/usr/bin/perl', '-e', perl, db_user] }] },
  network_configuration: { awsvpc_configuration: { subnets: [subnet_placement], security_groups: [security_group], assign_public_ip: 'ENABLED' } },
  capacity_provider_strategy: [{ capacity_provider: 'FARGATE', weight: 1 }]
)

task_arn = result.tasks[0].task_arn
puts "Watching task: #{task_arn}"

last_status = nil
loop do
  sleep 3
  task = ecsclient.describe_tasks(cluster: 'E2-App-ECS-Cluster', tasks: [task_arn]).tasks[0]
  break if task.nil?
  if task.last_status != last_status
    last_status = task.last_status
    puts "  status: #{last_status}"
  end
  next unless last_status == 'STOPPED'

  container = task.containers[0]
  code = container.exit_code
  reason = task.stopped_reason || container.reason
  puts ""
  if code == 0
    puts "RESULT: PASS — '#{db_user}' authenticated via the app's DBD::mysql/caching_sha2 path."
    puts "(full message in the e2cron-family CloudWatch log group)"
    exit 0
  else
    puts "RESULT: FAIL — exit code #{code.inspect}#{reason ? " (#{reason})" : ''}."
    puts "Check the e2cron-family CloudWatch log group for the AUTH FAIL line before flipping config."
    exit 1
  end
end
