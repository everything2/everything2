require 'aws-sdk'

class E2
  class Awsclient
    def iam
      Aws::IAM::Client.new
    end

    def ec2
      Aws::EC2::Client.new
    end

    def opsworks
      Aws::OpsWorks::Client.new
    end

    def elb
      Aws::ElasticLoadBalancingV2::Client.new
    end

    def rds
      Aws::RDS::Client.new
    end

    def acm
      Aws::ACM::Client.new
    end

    def r53
      Aws::Route53::Client.new
    end
  end
end
