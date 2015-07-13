#
# Cookbook Name:: chefvault_demo
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

include_recipe 'chef-vault'  # cookbook installs the gem
master_address = 'sensu_master.cheffian.com'
node.default["sensu"]["rabbitmq"]["host"] = master_address
node.default["sensu"]["redis"]["host"] = master_address
node.default["sensu"]["api"]["host"] = master_address

rmq_items = chef_vault_item("sensu_vault", "rabbitmq")
node.default['sensu']['rabbitmq']['user'] = rmq_items['user']
node.default['sensu']['rabbitmq']['password'] = rmq_items['password']

include_recipe "sensu::default"

sensu_client node.name do
  address node["ipaddress"]
  subscriptions node["roles"] + ["all"]
end

include_recipe "sensu::client_service"
