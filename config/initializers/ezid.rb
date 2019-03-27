# frozen_string_literal: true

require 'erb'
require 'yaml'

# Yeah, there's many better ways to do this, but later.
def load_yml
  cfg_file = "#{::Rails.root}/config/ezid.yml"

  begin
    ezid_erb = ERB.new(IO.read(cfg_file)).result(binding)
  rescue StandardError, SyntaxError => e
    raise("#{cfg_file} could not be parsed with ERB. \n#{e.inspect}")
  end

  begin
    ezid_yml = YAML.safe_load(ezid_erb)
  rescue => e
    raise("#{cfg_file} was found, but could not be parsed.\n#{e.inspect}")
  end

  if ezid_yml.nil? || !ezid_yml.is_a?(Hash)
    raise("#{cfg_file} was found, but was blank or malformed.\n")
  end

  begin
    raise "The #{::Rails.env} environment settings were not found in #{cfg_file}" unless ezid_yml[::Rails.env]
    ezid_cfg = ezid_yml[::Rails.env].symbolize_keys
  end

  ezid_cfg
end

Ezid::Client.configure do |config|
  config.host     = ENV['EZID_HOST'] || Settings.ezid.host
  config.port     = ENV['EZID_PORT'] || Settings.ezid.port
  config.user     = ENV['EZID_USER'] || Settings.ezid.user
  config.password = ENV['EZID_PASSWORD'] || Settings.ezid.password
  config.timeout  = ENV['EZID_TIMEOUT'] || Settings.ezid.timeout
  config.default_shoulder = ENV['EZID_DEFAULT_SHOULDER'] || Settings.ezid.shoulder
end
