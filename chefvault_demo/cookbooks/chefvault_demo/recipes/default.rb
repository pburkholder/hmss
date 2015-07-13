#
# Cookbook Name:: chefvault_demo
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

include_recipe 'chef_vault'  # cookbook installs the gem
rmq_items = chef_vault_item("sensu_vault", "rabbitmq")
node.default['sensu']['rabbitmq']['user'] = rmq_items['user']
node.default['sensu']['rabbitmq']['password'] = rmq_items['password']

include_recipe "sensu::default"

sensu_client node.name do
  address node["ipaddress"]
  subscriptions node["roles"] + ["all"]
end

include_recipe "sensu::client_service"
