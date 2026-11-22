#!/usr/bin/env ruby
# frozen_string_literal: true

# Tests for tools/cf-deploy.rb's change-set flow (#4730), run against a fake `aws` on PATH:
# nothing here talks to AWS.
#
#   ruby tools/test/cf_deploy_test.rb

require 'minitest/autorun'
require 'json'
require 'open3'
require 'tmpdir'
require 'fileutils'

class CFDeployTest < Minitest::Test
  ROOT   = File.expand_path('../..', __dir__)
  SCRIPT = File.join(ROOT, 'tools', 'cf-deploy.rb')
  POLICY = File.read(File.join(ROOT, 'cf', 'stack-policy.json'))

  # The fake aws: logs each call as a JSON line, and answers from files in $FAKE_AWS_DIR.
  FAKE_AWS = <<~'RUBY'
    #!/usr/bin/env ruby
    require 'json'
    dir = ENV.fetch('FAKE_AWS_DIR')
    File.open(File.join(dir, 'calls.jsonl'), 'a') { |f| f.puts(ARGV.to_json) }
    service, op = ARGV[0], ARGV[1]
    read = ->(name) { path = File.join(dir, name); File.exist?(path) ? File.read(path) : nil }
    case [service, op]
    when ['s3', 'cp'] then exit 0
    when ['cloudformation', 'describe-stacks']
      exit(read.('no_stack') ? 255 : 0)
    when ['cloudformation', 'create-change-set'] then puts '{"Id": "arn:fake"}'
    when ['cloudformation', 'wait'] then exit 0
    when ['cloudformation', 'describe-change-set']
      token = ARGV.include?('--next-token') ? ARGV[ARGV.index('--next-token') + 1] : nil
      puts(read.(token ? "changeset_#{token}.json" : 'changeset.json'))
    when ['cloudformation', 'get-stack-policy'] then puts({ 'StackPolicyBody' => read.('live_policy') }.to_json)
    when ['cloudformation', 'detect-stack-drift'] then puts '{"StackDriftDetectionId": "d-1"}'
    when ['cloudformation', 'describe-stack-drift-detection-status']
      puts '{"DetectionStatus": "DETECTION_COMPLETE", "StackDriftStatus": "DRIFTED"}'
    when ['cloudformation', 'describe-stack-resource-drifts']
      puts({ 'StackResourceDrifts' => [{ 'StackResourceDriftStatus' => 'MODIFIED', 'LogicalResourceId' => 'EverythingDB',
                                          'ResourceType' => 'AWS::RDS::DBInstance',
                                          'PropertyDifferences' => [{ 'DifferenceType' => 'NOT_EQUAL', 'PropertyPath' => '/EngineVersion' }] }] }.to_json)
    when ['cloudformation', 'delete-change-set'], ['cloudformation', 'set-stack-policy'],
         ['cloudformation', 'execute-change-set'], ['cloudformation', 'describe-stack-events']
      exit 0
    else exit 0
    end
  RUBY

  def setup
    @dir = Dir.mktmpdir('cf-deploy-test')
    bin = File.join(@dir, 'bin')
    FileUtils.mkdir_p(bin)
    File.write(File.join(bin, 'aws'), FAKE_AWS)
    File.chmod(0o755, File.join(bin, 'aws'))
    @env = { 'PATH' => "#{bin}:#{ENV.fetch('PATH')}", 'FAKE_AWS_DIR' => @dir }
    File.write(File.join(@dir, 'live_policy'), POLICY)
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def change(id, type, action: 'Modify', replacement: 'False', props: ['Tags'])
    { 'Type' => 'Resource', 'ResourceChange' => {
      'Action' => action, 'LogicalResourceId' => id, 'ResourceType' => type,
      'Replacement' => (action == 'Modify' ? replacement : nil),
      'Details' => props.map { |p| { 'Target' => { 'Attribute' => 'Properties', 'Name' => p }, 'ChangeSource' => 'DirectModification' } }
    } }
  end

  def knock_on(id, type, cause, replacement: 'False')
    { 'Type' => 'Resource', 'ResourceChange' => {
      'Action' => 'Modify', 'LogicalResourceId' => id, 'ResourceType' => type, 'Replacement' => replacement,
      'Details' => [{ 'Target' => { 'Attribute' => 'Properties', 'Name' => 'Dimensions' },
                      'ChangeSource' => 'ResourceAttribute', 'Evaluation' => 'Dynamic', 'CausingEntity' => cause }]
    } }
  end

  def changeset(*changes, status: 'CREATE_COMPLETE', reason: nil, next_token: nil)
    cs = { 'ChangeSetName' => 'deploy-1', 'Status' => status, 'Changes' => changes }
    cs['StatusReason'] = reason if reason
    cs['NextToken'] = next_token if next_token
    File.write(File.join(@dir, 'changeset.json'), cs.to_json)
  end

  def run_tool(*args, input: '')
    out, status = Open3.capture2e(@env, 'ruby', SCRIPT, *args, stdin_data: input)
    [out, status.exitstatus]
  end

  def calls
    path = File.join(@dir, 'calls.jsonl')
    File.exist?(path) ? File.readlines(path).map { |l| JSON.parse(l) } : []
  end

  def ops
    calls.select { |c| c[0] == 'cloudformation' }.map { |c| c[1] }
  end

  def test_an_ordinary_change_runs_after_yes
    changeset(change('AppALB', 'AWS::ElasticLoadBalancingV2::LoadBalancer', props: ['LoadBalancerAttributes']))
    out, code = run_tool('production', input: "yes\n")
    assert_equal 0, code, out
    assert_includes out, 'AppALB'
    assert_includes out, 'changes: LoadBalancerAttributes'
    assert_includes ops, 'execute-change-set'
    refute_includes ops, 'update-stack'
    create = calls.find { |c| c[1] == 'create-change-set' }
    assert_includes create, 'Key=app,Value=e2', 'the change set keeps the stack tag'
    refute_includes ops, 'set-stack-policy', 'the live policy already matches'
  end

  def test_anything_but_yes_leaves_the_stack_alone
    changeset(change('AppALB', 'AWS::ElasticLoadBalancingV2::LoadBalancer'))
    ["no\n", "y\n", ''].each do |input|
      File.delete(File.join(@dir, 'calls.jsonl')) if File.exist?(File.join(@dir, 'calls.jsonl'))
      out, code = run_tool('production', input: input)
      assert_equal 1, code, "input #{input.inspect}: #{out}"
      assert_includes out, 'nothing was changed'
      refute_includes ops, 'execute-change-set', "input #{input.inspect}"
      assert_includes ops, 'delete-change-set'
    end
  end

  def test_replacing_the_database_is_refused_without_asking
    changeset(change('EverythingDB', 'AWS::RDS::DBInstance', replacement: 'True', props: ['StorageEncrypted']))
    out, code = run_tool('production', input: "yes\n")
    assert_equal 1, code, out
    assert_includes out, 'REFUSED'
    assert_includes out, 'EverythingDB'
    refute_includes out, "Type 'yes'"
    refute_includes ops, 'execute-change-set'
    assert_includes ops, 'delete-change-set'
  end

  def test_removing_the_database_is_refused
    changeset(change('EverythingDB', 'AWS::RDS::DBInstance', action: 'Remove', props: []))
    out, code = run_tool('production', input: "everything2-production\n")
    assert_equal 1, code, out
    assert_includes out, 'REFUSED'
    refute_includes ops, 'execute-change-set'
  end

  def test_a_conditional_database_change_needs_the_stack_name
    cs = change('EverythingDB', 'AWS::RDS::DBInstance', replacement: 'Conditional', props: ['AutoMinorVersionUpgrade'])
    cs['ResourceChange']['Details'][0]['Target']['RequiresRecreation'] = 'Conditionally'
    changeset(cs)
    out, code = run_tool('production', input: "yes\n")
    assert_equal 1, code, out
    assert_includes out, 'AutoMinorVersionUpgrade (recreation: Conditionally)'
    assert_includes out, "can't rule out replacing it"
    refute_includes ops, 'execute-change-set'

    File.delete(File.join(@dir, 'calls.jsonl'))
    out, code = run_tool('production', input: "everything2-production\n")
    assert_equal 0, code, out
    assert_includes ops, 'execute-change-set'
  end

  def test_other_replacements_need_the_stack_name
    changeset(change('SitemapS3Bucket', 'AWS::S3::Bucket', replacement: 'True', props: ['BucketName']))
    out, code = run_tool('production', input: "yes\n")
    assert_equal 1, code, out
    assert_includes out, 'WARNING'
    refute_includes ops, 'execute-change-set'

    File.delete(File.join(@dir, 'calls.jsonl'))
    out, code = run_tool('production', input: "everything2-production\n")
    assert_equal 0, code, out
    assert_includes ops, 'execute-change-set'
  end

  def test_no_changes_executes_nothing
    changeset(status: 'FAILED', reason: "The submitted information didn't contain changes.")
    out, code = run_tool('production', input: "yes\n")
    assert_equal 0, code, out
    assert_includes out, 'No changes'
    refute_includes ops, 'execute-change-set'
  end

  def test_the_stack_policy_is_applied_before_executing_when_it_differs
    File.write(File.join(@dir, 'live_policy'), '{"Statement": []}')
    changeset(change('AppALB', 'AWS::ElasticLoadBalancingV2::LoadBalancer'))
    _, code = run_tool('production', input: "yes\n")
    assert_equal 0, code
    assert_operator ops.index('set-stack-policy'), :<, ops.index('execute-change-set')
  end

  def test_a_database_change_on_a_later_page_is_still_refused
    changeset(change('AppALB', 'AWS::ElasticLoadBalancingV2::LoadBalancer'), next_token: 'page2')
    File.write(File.join(@dir, 'changeset_page2.json'),
               { 'ChangeSetName' => 'deploy-1', 'Status' => 'CREATE_COMPLETE',
                 'Changes' => [change('EverythingDB', 'AWS::RDS::DBInstance', replacement: 'True')] }.to_json)
    out, code = run_tool('production', input: "yes\n")
    assert_equal 1, code, out
    assert_includes out, 'REFUSED'
    refute_includes ops, 'execute-change-set'
  end

  def test_the_listing_separates_direct_changes_from_knock_on_ones
    changeset(change('AppALB', 'AWS::ElasticLoadBalancingV2::LoadBalancer', props: ['LoadBalancerAttributes']),
              knock_on('App5xxAlarm', 'AWS::CloudWatch::Alarm', 'AppALB.LoadBalancerFullName'))
    out, = run_tool('diff', 'production')
    assert_match(/AppALB.*\n\s+changes: LoadBalancerAttributes/, out)
    assert_match(/App5xxAlarm.*\n\s+follows: AppALB.LoadBalancerFullName/, out)
    assert_includes out, '1 changed directly by the template'
  end

  def test_drift_lists_the_drifted_resources_and_changes_nothing
    out, code = run_tool('drift', 'production')
    assert_equal 0, code, out
    assert_includes out, 'Stack drift: DRIFTED'
    assert_includes out, 'EverythingDB'
    assert_includes out, '/EngineVersion'
    assert_empty ops & %w[create-change-set execute-change-set update-stack set-stack-policy]
  end

  def test_protect_and_unprotect
    _, code = run_tool('protect', 'production')
    assert_equal 0, code
    _, code = run_tool('unprotect')
    assert_equal 0, code
    flags = calls.select { |c| c[1] == 'update-termination-protection' }.map { |c| c[2] }
    assert_equal %w[--enable-termination-protection --no-enable-termination-protection], flags
  end

  def test_diff_previews_the_large_template_through_s3_and_changes_nothing
    changeset(change('EverythingDB', 'AWS::RDS::DBInstance', props: ['AutoMinorVersionUpgrade']))
    out, code = run_tool('diff', 'production')
    assert_equal 0, code, out
    create = calls.find { |c| c[1] == 'create-change-set' }
    assert_includes create, '--template-url', 'the production template is over the inline limit'
    assert_includes out, 'changes: AutoMinorVersionUpgrade'
    assert_includes ops, 'delete-change-set'
    refute_includes ops, 'execute-change-set'
    refute_includes ops, 'set-stack-policy'
  end
end
