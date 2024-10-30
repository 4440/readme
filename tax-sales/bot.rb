#!/usr/bin/env ruby

# gem install nokogiri

require 'net/http'
require 'nokogiri'

class Property
  attr_accessor :pid, :href
  def initialize(pid, href)
    @pid = pid
    @href = href
  end

  def Property.base_url
    "https://www.halifax.ca/home-property/property-taxes/tax-sale"
  end

  def pid?
    pid.to_i > 0 && pid.length == 8
  end

  def not_pid?
    !pid?
  end

  def to_s
    "PID:#{pid} | HREF:#{Property.base_url}#{href}"
  end

  def kenney?
    pid == "00453803"
  end
end

uri = URI(Property.base_url)
uri.freeze
html = Net::HTTP.get(uri)
doc = Nokogiri::HTML.parse(html)
tags = doc.xpath("//a[@data-entity-type]")

ps = tags
       .map {|t| Property.new(t[:title], t[:href]) }
       .delete_if {|p| p.not_pid? }

ps.each {|p| puts p }
puts "Contains 00453803 (Kenney lot)? - #{ps.any?(&:kenney?)}"
