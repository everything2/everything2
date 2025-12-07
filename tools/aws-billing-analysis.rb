#!/usr/bin/env ruby
# frozen_string_literal: true

# AWS Billing Analysis Tool
# Retrieves last month's billing data and analyzes potential CloudFront savings
#
# Usage:
#   ./tools/aws-billing-analysis.rb
#   ./tools/aws-billing-analysis.rb --detailed
#   ./tools/aws-billing-analysis.rb --months 3
#
# Requirements:
#   - AWS CLI configured with appropriate permissions
#   - ce:GetCostAndUsage permission

require 'json'
require 'date'
require 'optparse'

class AWSBillingAnalysis
  # CloudFront savings assumptions based on 95% guest traffic
  GUEST_TRAFFIC_PERCENTAGE = 0.95
  CACHE_HIT_RATE_ESTIMATE = 0.80  # 80% cache hit rate for guest pages

  # Estimated reduction factors with CloudFront
  SAVINGS_FACTORS = {
    'Amazon Elastic Container Service' => 0.75,  # 75% reduction in Fargate compute
    'EC2 - Other' => 0.70,                       # 70% reduction in ALB processing
    'AWS WAF' => 0.60,                           # 60% reduction - WAF at edge more efficient
    'Data Transfer' => 0.50                      # 50% reduction - CloudFront cheaper egress
  }.freeze

  # CloudFront pricing estimates (per GB, us-east-1)
  CLOUDFRONT_PRICE_PER_GB = 0.085
  CLOUDFRONT_REQUESTS_PER_10K = 0.0075

  def initialize(options = {})
    @detailed = options[:detailed] || false
    @months = options[:months] || 1
    @output = []
  end

  def run
    log_header

    # Get billing data
    costs = fetch_costs
    return unless costs

    # Analyze current costs
    analyze_current_costs(costs)

    # Project CloudFront savings
    project_cloudfront_savings(costs)

    # Print summary
    print_output
  end

  private

  def log_header
    @output << "=" * 70
    @output << "AWS Billing Analysis - Everything2"
    @output << "Generated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    @output << "=" * 70
    @output << ""
  end

  def fetch_costs
    # Calculate date range for last month(s)
    end_date = Date.today.prev_day(Date.today.day)  # Last day of previous month
    start_date = end_date.prev_month(@months - 1)
    start_date = Date.new(start_date.year, start_date.month, 1)
    end_date = Date.new(end_date.year, end_date.month + 1, 1)  # First of current month

    @output << "Fetching costs from #{start_date} to #{end_date.prev_day}..."
    @output << ""

    # Query AWS Cost Explorer
    cmd = build_cost_explorer_command(start_date, end_date)

    result = `#{cmd} 2>&1`
    unless $?.success?
      @output << "Error fetching AWS costs:"
      @output << result
      return nil
    end

    begin
      JSON.parse(result)
    rescue JSON::ParserError => e
      @output << "Error parsing AWS response: #{e.message}"
      @output << result
      nil
    end
  end

  def build_cost_explorer_command(start_date, end_date)
    filter = {
      "TimePeriod" => {
        "Start" => start_date.to_s,
        "End" => end_date.to_s
      },
      "Granularity" => "MONTHLY",
      "Metrics" => ["UnblendedCost", "UsageQuantity"],
      "GroupBy" => [
        { "Type" => "DIMENSION", "Key" => "SERVICE" }
      ]
    }

    # Build AWS CLI command
    <<~CMD.gsub("\n", ' ')
      aws ce get-cost-and-usage
      --time-period Start=#{start_date},End=#{end_date}
      --granularity MONTHLY
      --metrics "UnblendedCost" "UsageQuantity"
      --group-by Type=DIMENSION,Key=SERVICE
      --output json
    CMD
  end

  def analyze_current_costs(costs)
    @output << "CURRENT AWS COSTS"
    @output << "-" * 50

    @service_costs = {}
    total_cost = 0.0

    costs['ResultsByTime'].each do |period|
      period_start = period['TimePeriod']['Start']
      period_end = period['TimePeriod']['End']

      @output << ""
      @output << "Period: #{period_start} to #{period_end}"
      @output << ""

      period['Groups'].each do |group|
        service = group['Keys'][0]
        cost = group['Metrics']['UnblendedCost']['Amount'].to_f

        next if cost < 0.01  # Skip negligible costs

        @service_costs[service] ||= 0.0
        @service_costs[service] += cost
        total_cost += cost

        if @detailed || cost >= 1.0
          @output << "  #{service.ljust(45)} $#{format('%.2f', cost)}"
        end
      end
    end

    @output << ""
    @output << "  #{'TOTAL'.ljust(45)} $#{format('%.2f', total_cost)}"
    @output << ""
    @total_cost = total_cost
  end

  def project_cloudfront_savings(costs)
    @output << ""
    @output << "CLOUDFRONT SAVINGS ANALYSIS"
    @output << "-" * 50
    @output << ""
    @output << "Assumptions:"
    @output << "  - Guest traffic: #{(GUEST_TRAFFIC_PERCENTAGE * 100).to_i}%"
    @output << "  - Estimated cache hit rate: #{(CACHE_HIT_RATE_ESTIMATE * 100).to_i}%"
    @output << "  - Effective traffic reduction: #{((GUEST_TRAFFIC_PERCENTAGE * CACHE_HIT_RATE_ESTIMATE) * 100).to_i}%"
    @output << ""

    # Calculate savings per service
    total_savings = 0.0
    cloudfront_cost_estimate = 0.0

    @output << "Projected Savings by Service:"
    @output << ""

    # Sort services by cost
    @service_costs.sort_by { |_, cost| -cost }.each do |service, cost|
      savings_factor = find_savings_factor(service)

      if savings_factor > 0
        savings = cost * savings_factor * GUEST_TRAFFIC_PERCENTAGE * CACHE_HIT_RATE_ESTIMATE
        total_savings += savings

        @output << "  #{service.ljust(40)}"
        @output << "    Current: $#{format('%.2f', cost)}"
        @output << "    Reduction factor: #{(savings_factor * 100).to_i}%"
        @output << "    Estimated savings: $#{format('%.2f', savings)}"
        @output << ""
      end
    end

    # Estimate CloudFront costs
    @output << ""
    @output << "CLOUDFRONT COST ESTIMATE"
    @output << "-" * 50
    @output << ""

    # Get data transfer cost if available
    data_transfer_cost = @service_costs.select { |k, _| k.include?('Transfer') || k.include?('CloudFront') }
                                       .values.sum

    if data_transfer_cost > 0
      # Rough estimate: CloudFront is ~20% cheaper than direct data transfer
      cloudfront_data_cost = data_transfer_cost * 0.85
      cloudfront_request_cost = data_transfer_cost * 0.15  # Estimate request costs
      cloudfront_cost_estimate = cloudfront_data_cost + cloudfront_request_cost
    else
      # Fallback estimate based on typical traffic patterns
      # Assume 100GB/month transfer for a site like E2
      cloudfront_cost_estimate = 100 * CLOUDFRONT_PRICE_PER_GB
    end

    @output << "  Estimated CloudFront cost: $#{format('%.2f', cloudfront_cost_estimate)}/month"
    @output << ""

    # Net savings
    net_savings = total_savings - cloudfront_cost_estimate

    @output << ""
    @output << "=" * 50
    @output << "SUMMARY"
    @output << "=" * 50
    @output << ""
    @output << "  Current monthly cost:       $#{format('%.2f', @total_cost / @months)}"
    @output << "  Gross savings potential:    $#{format('%.2f', total_savings / @months)}"
    @output << "  CloudFront cost:            $#{format('%.2f', cloudfront_cost_estimate)}"
    @output << "  Net monthly savings:        $#{format('%.2f', net_savings / @months)}"
    @output << ""

    if net_savings > 0
      savings_percent = (net_savings / @total_cost) * 100
      @output << "  Projected savings: #{format('%.1f', savings_percent)}%"
      @output << ""
      @output << "  Annual savings potential: $#{format('%.2f', net_savings * 12 / @months)}"
    else
      @output << "  Note: CloudFront may not provide cost savings at current traffic levels."
      @output << "  However, it provides performance benefits (lower latency, DDoS protection)."
    end

    @output << ""
    @output << "RECOMMENDATIONS"
    @output << "-" * 50
    @output << ""

    if net_savings > 50
      @output << "  [RECOMMENDED] CloudFront implementation would provide significant savings."
      @output << ""
      @output << "  Implementation steps:"
      @output << "    1. Create CloudFront distribution pointing to ALB"
      @output << "    2. Configure cache behaviors:"
      @output << "       - Default: Cache for guests (no session cookie)"
      @output << "       - Bypass cache for logged-in users (has session cookie)"
      @output << "    3. Move WAF to CloudFront (CLOUDFRONT scope in us-east-1)"
      @output << "    4. Update DNS to point to CloudFront"
      @output << ""
    elsif net_savings > 0
      @output << "  [CONSIDER] Modest savings available. Evaluate performance benefits."
    else
      @output << "  [OPTIONAL] Cost savings minimal, but latency improvements possible."
    end
  end

  def find_savings_factor(service)
    SAVINGS_FACTORS.each do |pattern, factor|
      return factor if service.include?(pattern) || service.downcase.include?(pattern.downcase)
    end

    # Additional patterns
    return 0.70 if service.include?('Fargate') || service.include?('ECS')
    return 0.60 if service.include?('Load Balancing') || service.include?('ELB')
    return 0.50 if service.include?('NAT Gateway')

    0.0
  end

  def print_output
    puts @output.join("\n")
  end
end

# Parse command line options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on("-d", "--detailed", "Show detailed breakdown of all services") do
    options[:detailed] = true
  end

  opts.on("-m", "--months N", Integer, "Number of months to analyze (default: 1)") do |n|
    options[:months] = n
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end.parse!

# Run analysis
analyzer = AWSBillingAnalysis.new(options)
analyzer.run
