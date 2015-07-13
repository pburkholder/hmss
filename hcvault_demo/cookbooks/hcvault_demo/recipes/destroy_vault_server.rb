require 'chef/provisioning/aws_driver'

example='converge'

with_driver 'aws::us-east-1' do
  if example == 'autoscale'

    aws_auto_scaling_group 'peterb-vault-server' do
      desired_capacity 0
      min_size 1
      max_size 2
      launch_configuration 'peterb-vault-server'
      availability_zones ['us-east-1c']
    end
  else
    machine 'peterb-vault-server' do
      action :destroy
    end
  end # if autoscale
end
