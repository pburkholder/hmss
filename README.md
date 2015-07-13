HMSS: Her Majesty's Secret Service
----------------------------------

A comparison of (and eventual library for) different secret services with
Chef, such as:

- encrypted data bags
- chef vault
- conjur/summons
- hashicorp vault


---

# References

https://github.com/pburkholder/conjur_demo
https://github.com/johnbellone/vault-cookbook

Note: use 'pdbchef' as the chef server

---

# Desired view - Uichwa Dashboard

Port 3000 not open to internet, so:

```
ssh -D ubuntu@sensu_master.cheffian.com
```

Then use FoxyProxy to connect to http://sensu_master.cheffian.com:3000

---

## Target code

For a node to subscribe to the Sensu RabbitMQ channels, the file /etc/sensu/config.json should have:

```
{
  "rabbitmq": {
    "host": "sensu_master.cheffian.com",
    "port": 5671,
    "vhost": "/sensu",
    "user": "user_from_conjur",
    "password": "password_from_conjur",
  },
  "other_stuff" : ""
}
```

---

## Cookbook: Conjur

### Fetch secret and set node attribute(\*)

```
require 'conjur/cli' # use node.run_state below?
Conjur::Config.load
Conjur::Config.apply
conjur = Conjur::Authn.connect nil, noask: true
user_var = conjur.variable 'monitor/rabbitmq/user'
password_var = conjur.variable 'monitor/rabbitmq/password'
node.default['sensu']['rabbitmq']['user'] = user_var.value
node.default['sensu']['rabbitmq']['password'] = password_var.value
```

----

## Conjur config files:

```
# conjur.conf
---
account: chef
appliance_url: https://ec2-54-90-25-181.compute-1.amazonaws.com/api
plugins:
- host-factory
netrc_path: "/etc/conjur.identity"
cert_file: "/etc/conjur-chef.pem"
```
```
# conjur.identity
machine   https://ec2-54-90-25-181.compute-1.amazonaws.com/api/authn
login     host/sensu_client-i-5a619df2
password  3efqgj12974pbx3q1vvctvsse95xp3854n6a7mj2v9xbsz2gd1kkk
```

----

### Conjur identity cookbook pseudocode

```
remote_file target_path # get dpkg from s3
dpkg_package "conjur"   # install it
Gem.path << "/opt/conjur/embedded/lib/ruby/gems/2.1.0"
Gem::Specification.reset  # reset gem paths
include_recipe "conjur::conjurrc"  # setup /etc/conjur.conf, pem file
gem_package 'conjur-asset-host-factory' # use conjur's gem binary
ruby_block "generate conjur identity" do # guard & unlink omitted
    require 'json'
    hostfactory_token = ::File.read('/etc/conjur_hostfactory_token').chomp
    conjur_json = %x(
      /usr/local/bin/conjur hostfactory hosts create #{hostfactory_token} #{node.name}
    )
    conjur_response = JSON.parse(conjur_json)
    conjur_identity = <<END_ID
machine   #{node['conjur']['configuration']['appliance_url']}/authn
login     host/#{node.name}
password  #{conjur_response['api_key']}
END_ID
  end
end.run_action(:create)
```

----

### Cookbook requires /etc/conjur_hostfactory_token

1. Generate on the admin workstation:
```
export HOST_FACTORY= \
`conjur hostfactory tokens create --duration-hours=1 sensu/generic |
 jsonfield 0.token`
```

2. Insert into userdata with this:
```
user_data = <<END_SCRIPT
...
cat <<END_TOKEN>/etc/conjur_hostfactory_token
#{token}
END_TOKEN
...
END_SCRIPT
```

3. Use chef-provisioning to destroy/create autoscale group

---

## Cookbook: with chef-vault

```
include_recipe 'chef_vault'  # cookbook installs the gem
rmq_items = chef_vault_item("sensu_vault", "rabbitmq")
node.default['sensu']['rabbitmq']['user'] = rmq_items['user']
node.default['sensu']['rabbitmq']['password'] = rmq_items['password']
```

----

## Set up

chef-vault needs no client setup, since it leverages encrypted data bags, but the vault needs to set with the node search that matters

By default vault will run in chef-solo mode, use `-m client`

```
knife vault create \
  sensu_vault rabbitmq -m client \
   '{"user": "sensu_chefvault", "password": "password_cv"}'  \
   -S "role:sensu_chefvault" -A "pburkholder-getchef-com"
```
```
WARNING: No clients were returned from search, you may not have got what you expected!!
```

----

The 'no setup' is a bit of a lie, I forced the sensu_master
to have a user, `user_from_chef_vault` with https://github.com/pburkholder/chef-monitor/blob/pdb/conjur/recipes/conjurized.rb#L42

----

## Look at the bags

```
knife data bag show sensu_vault rabbitmq
...
knife data bag show sensu_vault rabbitmq_keys
...
# no clients
# one value for pburkholder-getchef-com
```

----

## Look at the vault

knife vault show sensu_vault rabbitmq

```
id:       rabbitmq
password: password_cv
user:     sensu_chefvault
```

----

## Recipe and role

- see chefvault_demo/roles/sensu_chefvault.json
- knife role from file !$
- berks vendor; berks upload

----

## Get some nodes in

- Spin up 26 nodes
- 52.3.39.55 ip; id: i-2fa41187
- Bootstrap:
```
knife bootstrap 52.3.39.55 \
  --bootstrap-vault-item sensu_vault::rabbitmq \
  -N cv_client-i-2fa41187 \
  -E conjur \
  --hint ec2 \
  -r 'role[sensu_chefvault]' \
  --sudo \
  -x ubuntu
```
```
knife bootstrap 52.3.39.55 \
  --bootstrap-vault-json '{"sensu_vault":["rabbitmq"]}' \
  -N cv_client-i-2fa41187 \
  -E conjur \
  --hint ec2 \
  -r 'role[sensu_chefvault]' \
  --sudo \
  -x ubuntu

-- Does provisioning support vault? - Nope




+describe Chef::Knife::Bootstrap::ChefVaultHandler do
spec/unit/knife/bootstrap/chef_vault_handler_spec.rb
https://github.com/chef/chef/pull/2030/files


# AWS notes

## Autoscale groups -
