require 'aws-sdk'

def cmd(instance_id, public_dns_name)
  string =<<-END
  knife bootstrap #{public_dns_name} \
    --bootstrap-vault-json '{"sensu_vault":["rabbitmq"]}' \
    -N cv_client-#{instance_id} \
    -E conjur \
    --hint ec2 \
    -r 'role[sensu_chefvault]' \
    --sudo \
    -x ubuntu
  END
end

as = Aws::AutoScaling::Client.new(
  region: 'us-east-1'
)

ec2 = Aws::EC2::Client.new(
  region: 'us-east-1'
)

resp = as.describe_auto_scaling_groups({
  auto_scaling_group_names: ["peterb-cv-client"]
})

as_instances = resp.auto_scaling_groups[0].instances.map{ |i| i.instance_id }

puts "length: #{as_instances.length}"

h = Hash.new()
resp = ec2.describe_instances({
  instance_ids: as_instances,
})

puts "length: #{resp.reservations[0].instances.length}"

#unless resp.last_page? do |j|
  resp.reservations[0].instances.each do |i|
    print cmd(i.instance_id, i.public_dns_name)
  end
#  resp.next_page
#end
