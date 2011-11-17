require "pgmonitor/version"

module Pgmonitor
  def self.settings=(opts)
    @@settings = opts
  end

  def self.settings
    @@settings ||= {}
  end

  def self.debug?
    settings[:debug] == true
  end

  def self.delay
    settings[:delay] || 2
  end

  def self.log_items
    return "" unless settings[:log_items]

    @@log_items ||= if settings[:log_items].kind_of?(Hash)
      " " + settings[:log_items].map { |k,v| "#{k}=#{v}" }.join(" ")
    elsif settings[:log_items].kind_of?(Array)
      " " + settings[:log_items].join(" ")
    else
      " #{settings[:log_items]}"
    end
  end
end

require 'pgmonitor/usagedata'
require 'pgmonitor/ps'
