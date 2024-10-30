#!/usr/bin/env ruby

# gem install nokogiri

require 'net/http'
require 'nokogiri'

uri = URI('https://www.halifax.ca/home-property/property-taxes/tax-sale')
uri.freeze

html = Net::HTTP.get(uri)
# puts page

doc = Nokogiri::HTML.parse(html)
tags = doc.xpath("//a[@data-entity-type]")

tags.each do |t|
  puts "#{t[:title]} - #{t[:href]}" if t[:title].to_i > 0 && t[:title].length == 8
end
