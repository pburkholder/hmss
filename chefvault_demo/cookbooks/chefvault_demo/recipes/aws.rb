require 'chef/provisioning/aws_driver'

example='autoscale'

with_driver 'aws::us-east-1' do
  if example == 'autoscale'
    aws_launch_configuration 'peterb-cv-client' do
      image 'ami-dc5e75b4'  # Trusty
      instance_type 't2.micro'
      options({
        security_groups: ['sg-2ee7694b'],
        key_pair: 'pburkholder-one',
      })
    end

    aws_auto_scaling_group 'peterb-cv-client' do
      desired_capacity 26
      min_size 1
      max_size 40
      launch_configuration 'peterb-cv-client'
      availability_zones ['us-east-1c']
    end
  else
    machine 'sensu_client' do
      action :allocate

      add_machine_options bootstrap_options: {
        instance_type: 't2.micro',
        image_id: 'ami-dc5e75b4',
        security_group_ids: ['sg-2ee7694b' ],
        key_name: 'pburkholder-one',
        user_data: user_data
      }
    end
  end # if autoscale
end
