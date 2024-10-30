#!/usr/bin/env ruby

# gem install nokogiri

require 'net/http'
require 'nokogiri'

class Property
  attr_accessor :assessment_num, :href
  def initialize(assessment_num, href)
    @assessment_num = assessment_num
    @href = href
  end

  def Property.base_url
    "https://www.halifax.ca/home-property/property-taxes/tax-sale"
  end

  def assessment_num?
    assessment_num.to_i > 0 && assessment_num.length == 8
  end

  def not_assessment_num?
    !assessment_num?
  end

  def to_s
    "Assessment Number:#{assessment_num} | HREF:#{Property.base_url}#{href}"
  end

  def kenney?
    # TODO: this is obviously wrong
    assessment_num == "00453803"
  end
end

uri = URI(Property.base_url)
uri.freeze
html = Net::HTTP.get(uri)
doc = Nokogiri::HTML.parse(html)
tags = doc.xpath("//a[@data-entity-type]")

ps = tags
       .map {|t| Property.new(t[:title], t[:href]) }
       .delete_if {|p| p.not_assessment_num? }

# TODO: look up PDF in tags
# TODO: parse PDF and find PIDs
# TODO: add PIDs to Properties
# TODO: get kenney/special PID from secrets

ps.each {|p| puts p }
puts "Contains 00453803 (Kenney lot)? - #{ps.any?(&:kenney?)}"
