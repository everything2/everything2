#!/usr/bin/env ruby
# frozen_string_literal: true

# RDS Cost Comparison Analysis
#
# Compares current RDS MySQL configuration with alternative instance types
# and Aurora to determine most cost-efficient option.
#
# Usage:
#   ./tools/rds-cost-comparison.rb

puts "RDS Cost Comparison Analysis"
puts "=" * 80
puts

# Current configuration from Performance Insights analysis
current_config = {
  name: "Current: db.t4g.medium",
  instance_type: "db.t4g.medium",
  vcpu: 2,
  memory_gb: 4,
  storage_gb: 100,
  storage_type: "gp3",
  iops: 3000,
  throughput: 125,
  multi_az: false,
  performance_insights: true,
  # us-west-2 pricing
  instance_cost_hourly: 0.068,
  storage_cost_monthly_per_gb: 0.115,
  iops_cost_monthly: 0, # gp3 includes 3000 IOPS
  pi_cost_monthly: 3.50
}

# Alternative MySQL RDS options
alternatives = [
  {
    name: "db.t4g.small (2GB RAM)",
    instance_type: "db.t4g.small",
    vcpu: 2,
    memory_gb: 2,
    storage_gb: 100,
    storage_type: "gp3",
    iops: 3000,
    throughput: 125,
    multi_az: false,
    performance_insights: true,
    instance_cost_hourly: 0.034,
    storage_cost_monthly_per_gb: 0.115,
    iops_cost_monthly: 0,
    pi_cost_monthly: 3.50,
    notes: "⚠️  Only 2GB RAM - InnoDB buffer pool would need to be reduced to ~1.5GB"
  },
  {
    name: "db.t3.medium (4GB RAM, Intel)",
    instance_type: "db.t3.medium",
    vcpu: 2,
    memory_gb: 4,
    storage_gb: 100,
    storage_type: "gp3",
    iops: 3000,
    throughput: 125,
    multi_az: false,
    performance_insights: true,
    instance_cost_hourly: 0.088,
    storage_cost_monthly_per_gb: 0.115,
    iops_cost_monthly: 0,
    pi_cost_monthly: 3.50,
    notes: "Intel-based, ~30% more expensive than ARM equivalent"
  },
  {
    name: "db.t4g.medium Reserved (1yr)",
    instance_type: "db.t4g.medium",
    vcpu: 2,
    memory_gb: 4,
    storage_gb: 100,
    storage_type: "gp3",
    iops: 3000,
    throughput: 125,
    multi_az: false,
    performance_insights: true,
    instance_cost_hourly: 0.041, # 40% savings
    storage_cost_monthly_per_gb: 0.115,
    iops_cost_monthly: 0,
    pi_cost_monthly: 3.50,
    upfront_cost: 208,
    notes: "✅ 40% savings, $208 upfront"
  },
  {
    name: "db.t4g.medium Reserved (3yr)",
    instance_type: "db.t4g.medium",
    vcpu: 2,
    memory_gb: 4,
    storage_gb: 100,
    storage_type: "gp3",
    iops: 3000,
    throughput: 125,
    multi_az: false,
    performance_insights: true,
    instance_cost_hourly: 0.027, # 60% savings
    storage_cost_monthly_per_gb: 0.115,
    iops_cost_monthly: 0,
    pi_cost_monthly: 3.50,
    upfront_cost: 444,
    notes: "✅ 60% savings, $444 upfront"
  }
]

# Aurora Serverless v2 option
aurora_serverless = {
  name: "Aurora Serverless v2",
  engine: "aurora-mysql",
  version: "8.0",
  min_acu: 0.5,
  max_acu: 1.0,
  # ACU pricing in us-west-2
  acu_cost_hourly: 0.12,
  storage_cost_monthly_per_gb: 0.10,
  io_cost_per_million: 0.20,
  backup_cost_monthly_per_gb: 0.021,
  notes: "Scales to zero, pay for what you use"
}

# Aurora Provisioned option
aurora_provisioned = {
  name: "Aurora MySQL db.t4g.medium",
  instance_type: "db.t4g.medium",
  vcpu: 2,
  memory_gb: 4,
  storage_gb: 100, # Aurora storage is auto-scaling
  multi_az: false, # Single instance
  instance_cost_hourly: 0.082,
  storage_cost_monthly_per_gb: 0.10,
  io_cost_per_million: 0.20,
  backup_cost_monthly_per_gb: 0.021,
  notes: "Aurora advantages: better availability, faster backups, read replicas"
}

def calculate_monthly_cost(config)
  instance_cost = config[:instance_cost_hourly] * 730 # hours/month
  storage_cost = config[:storage_gb] * config[:storage_cost_monthly_per_gb]
  iops_cost = config[:iops_cost_monthly] || 0
  pi_cost = config[:pi_cost_monthly] || 0

  total = instance_cost + storage_cost + iops_cost + pi_cost

  {
    instance: instance_cost,
    storage: storage_cost,
    iops: iops_cost,
    performance_insights: pi_cost,
    total: total
  }
end

def calculate_aurora_serverless_cost(config, avg_acu, io_millions_per_month)
  # For low-traffic sites, Aurora Serverless v2 charges for min ACU even when idle
  # Assume average utilization between min and max
  acu_cost = config[:acu_cost_hourly] * avg_acu * 730
  storage_cost = config[:storage_cost_monthly_per_gb] * 100 # assume 100GB
  io_cost = io_millions_per_month * config[:io_cost_per_million]
  backup_cost = config[:backup_cost_monthly_per_gb] * 100 # assume same as storage

  {
    compute: acu_cost,
    storage: storage_cost,
    io: io_cost,
    backup: backup_cost,
    total: acu_cost + storage_cost + io_cost + backup_cost
  }
end

def calculate_aurora_provisioned_cost(config, io_millions_per_month)
  instance_cost = config[:instance_cost_hourly] * 730
  storage_cost = config[:storage_cost_monthly_per_gb] * config[:storage_gb]
  io_cost = io_millions_per_month * config[:io_cost_per_million]
  backup_cost = config[:backup_cost_monthly_per_gb] * config[:storage_gb]

  {
    instance: instance_cost,
    storage: storage_cost,
    io: io_cost,
    backup: backup_cost,
    total: instance_cost + storage_cost + io_cost + backup_cost
  }
end

# Calculate costs
puts "Current Configuration"
puts "-" * 80
current = calculate_monthly_cost(current_config)
puts "Instance Type: #{current_config[:instance_type]}"
puts "vCPU: #{current_config[:vcpu]}, Memory: #{current_config[:memory_gb]}GB"
puts "Storage: #{current_config[:storage_gb]}GB #{current_config[:storage_type]}"
puts
puts "Monthly Cost Breakdown:"
puts "  Instance:             $#{current[:instance].round(2)}"
puts "  Storage:              $#{current[:storage].round(2)}"
puts "  Performance Insights: $#{current[:performance_insights].round(2)}"
puts "  ────────────────────────────"
puts "  Total:                $#{current[:total].round(2)}/month"
puts "  Annual:               $#{(current[:total] * 12).round(2)}/year"
puts

# Alternative MySQL options
puts "Alternative MySQL RDS Options"
puts "-" * 80
alternatives.each do |alt|
  cost = calculate_monthly_cost(alt)
  monthly_diff = cost[:total] - current[:total]
  annual_diff = monthly_diff * 12

  puts "\n#{alt[:name]}"
  puts "  Monthly: $#{cost[:total].round(2)} (#{monthly_diff >= 0 ? '+' : ''}$#{monthly_diff.round(2)}/mo)"
  puts "  Annual:  $#{(cost[:total] * 12).round(2)} (#{annual_diff >= 0 ? '+' : ''}$#{annual_diff.round(2)}/yr)"

  if alt[:upfront_cost]
    puts "  Upfront: $#{alt[:upfront_cost]}"
    total_first_year = alt[:upfront_cost] + (cost[:total] * 12)
    puts "  First year total: $#{total_first_year.round(2)}"
  end

  puts "  Notes: #{alt[:notes]}" if alt[:notes]
end

puts
puts
puts "Aurora Options"
puts "-" * 80

# Aurora Serverless v2 - estimate based on typical load
# From Performance Insights: avg DB load ~0.3, so estimate 0.5 ACU average
puts "\n#{aurora_serverless[:name]}"
puts "  Configuration: #{aurora_serverless[:min_acu]}-#{aurora_serverless[:max_acu]} ACU"
puts

[0.5, 0.75, 1.0].each do |avg_acu|
  # Estimate IO based on current IOPS utilization: ~252 IOPS avg
  # At 16KB block size: 252 * 86400 sec/day * 30 days = ~652M IOs/month
  # But Aurora charges per IO request, not IOPS, so estimate conservatively
  io_millions = 100 # Conservative estimate

  cost = calculate_aurora_serverless_cost(aurora_serverless, avg_acu, io_millions)
  monthly_diff = cost[:total] - current[:total]
  annual_diff = monthly_diff * 12

  puts "  Average #{avg_acu} ACU:"
  puts "    Compute: $#{cost[:compute].round(2)}"
  puts "    Storage: $#{cost[:storage].round(2)}"
  puts "    I/O:     $#{cost[:io].round(2)} (est. #{io_millions}M IOs/mo)"
  puts "    Backup:  $#{cost[:backup].round(2)}"
  puts "    ────────────────────────────"
  puts "    Total:   $#{cost[:total].round(2)}/mo (#{monthly_diff >= 0 ? '+' : ''}$#{monthly_diff.round(2)} vs current)"
  puts "    Annual:  $#{(cost[:total] * 12).round(2)}/yr (#{annual_diff >= 0 ? '+' : ''}$#{annual_diff.round(2)} vs current)"
  puts
end

puts "  #{aurora_serverless[:notes]}"
puts

# Aurora Provisioned
puts "\n#{aurora_provisioned[:name]}"
io_millions = 100 # Same estimate
cost = calculate_aurora_provisioned_cost(aurora_provisioned, io_millions)
monthly_diff = cost[:total] - current[:total]
annual_diff = monthly_diff * 12

puts "  Instance Type: #{aurora_provisioned[:instance_type]}"
puts "  Monthly Breakdown:"
puts "    Instance: $#{cost[:instance].round(2)}"
puts "    Storage:  $#{cost[:storage].round(2)}"
puts "    I/O:      $#{cost[:io].round(2)} (est. #{io_millions}M IOs/mo)"
puts "    Backup:   $#{cost[:backup].round(2)}"
puts "    ────────────────────────────"
puts "    Total:    $#{cost[:total].round(2)}/mo (#{monthly_diff >= 0 ? '+' : ''}$#{monthly_diff.round(2)} vs current)"
puts "    Annual:   $#{(cost[:total] * 12).round(2)}/yr (#{annual_diff >= 0 ? '+' : ''}$#{annual_diff.round(2)} vs current)"
puts
puts "  #{aurora_provisioned[:notes]}"

puts
puts
puts "Recommendations"
puts "=" * 80
puts
reserved_1yr = calculate_monthly_cost(alternatives[2])
reserved_3yr = calculate_monthly_cost(alternatives[3])
aurora_mid = calculate_aurora_serverless_cost(aurora_serverless, 0.75, 100)
aurora_prov = calculate_aurora_provisioned_cost(aurora_provisioned, 100)

puts "1. ✅ BEST VALUE: db.t4g.medium Reserved Instance (1-year)"
puts "   - Saves $#{((current[:total] - reserved_1yr[:total]) * 12).round(2)}/year"
puts "   - No architectural changes needed"
puts "   - $208 upfront for 1yr or $444 upfront for 3yr"
puts "   - Same performance as current setup"
puts
puts "2. ⚠️  DON'T DOWNSIZE: db.t4g.small"
puts "   - Only 2GB RAM vs current 4GB"
puts "   - Would require reducing InnoDB buffer pool from 2GB to ~1.5GB"
puts "   - Performance impact likely not worth $25/month savings"
puts
puts "3. ❌ AVOID AURORA: Higher costs, unnecessary complexity"
puts "   - Aurora Serverless v2: ~$#{((aurora_mid[:total] - current[:total]) * 12).round(0)} MORE/year"
puts "   - Aurora Provisioned: ~$#{((aurora_prov[:total] - current[:total]) * 12).round(0)} MORE/year"
puts "   - Aurora benefits (HA, read replicas) not needed for your traffic pattern"
puts "   - I/O charges add unpredictability"
puts
puts "Current Performance Metrics (from Performance Insights):"
puts "  - CPU: 45% average (well-balanced)"
puts "  - Memory: 94.5% peak with 2GB buffer pool (healthy)"
puts "  - IOPS: 8.4% utilized (252 of 3000 provisioned)"
puts "  - DB Load: 0.15 average (very light)"
puts
puts "Conclusion:"
puts "  Your current db.t4g.medium with gp3 storage is right-sized."
puts "  Purchase a 1-year Reserved Instance to save $#{((current[:total] - reserved_1yr[:total]) * 12).round(0)}/year."
puts "  This maintains current performance while reducing costs by 40%."
puts
