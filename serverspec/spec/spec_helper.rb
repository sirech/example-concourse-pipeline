require 'serverspec'
require 'docker-api'
require 'docker'
require 'rspec/wait'

set :backend, :docker
set :docker_image, ENV['IMAGE']

RSpec.configure do |config|
  config.wait_timeout = 60 # seconds
end
