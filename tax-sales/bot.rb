#!/usr/bin/env ruby

# gem install nokogiri

require 'net/http'
require 'nokogiri'
require 'fileutils'

class Property
  attr_accessor :assessment_num, :href
  def initialize(assessment_num, href)
    @assessment_num = assessment_num
    @href = href
  end

  def assessment_num?
    assessment_num.to_i > 0 && assessment_num.length == 8
  end

  def not_assessment_num?
    !assessment_num?
  end

  def to_s
    "Assessment Number:#{assessment_num} | HREF:#{SalePage.base_url}#{href}"
  end

  def kenney?
    # TODO: this is obviously wrong
    assessment_num == "00453803"
  end
end

class ScheduleA
  attr_accessor :title, :href, :text
  def initialize(title, href, text)
    @title = title
    @href = href
    @text = text
  end

  def schedule_a?
    @text.upcase.include? "SCHEDULE A"
  end

  def not_schedule_a?
    !schedule_a?
  end

  def to_s
    "title:#{title} | PDF:#{pdf_url}"
  end

  def pdf_url
    "#{SalePage.base_url}#{href}"
  end
end

class SalePage
  attr_accessor :tags

  def SalePage.base_url
    "https://www.halifax.ca/home-property/property-taxes/tax-sale"
  end

  def scrape!
    puts "Getting listings..."
    uri = URI(SalePage.base_url)
    uri.freeze
    html = Net::HTTP.get(uri)
    doc = Nokogiri::HTML.parse(html)
    @tags = doc.xpath("//a[@data-entity-type]")
  end

  def properties
    @tags
      .map {|t| Property.new(t[:title], t[:href]) }
      .delete_if {|p| p.not_assessment_num? }
  end

  def list_pdf
    @tags
      .map {|t| ScheduleA.new(t[:title], t[:href], t.text) }
      .delete_if {|p| p.not_schedule_a? }
      .first
      .pdf_url
  end
end

class Listings
  attr_accessor :properties
  def initialize(properties)
    @properties = properties
  end
  def save_tmp!
    FileUtils.rm_f("latest.tmp")
    File.open("latest.tmp", 'w') do |f|
      puts "Writing listings to temporary file..."
      @properties.each {|p| f.puts p }
      f.puts "Contains 00453803 (Kenney lot)? - #{@properties.any?(&:kenney?)}"
    end
  end

  def compare_and_swap!
    old_listings = File.read("listings.txt") rescue ""
    if (old_listings != File.read("latest.tmp"))
      puts "New listings! Replacing 'listings.txt' and creating dated record..."
      FileUtils.cp("latest.tmp", "#{Time.now.strftime("%Y-%m-%d")}_listings.txt")
      FileUtils.cp("latest.tmp", "listings.txt")
      # TODO: commit to git repo (GH action)
      # TODO: send an email
    end
    FileUtils.rm_f("latest.tmp")
  end
end

page = SalePage.new
page.scrape!
puts page.list_pdf

listings = Listings.new(page.properties)
listings.save_tmp!
listings.compare_and_swap!

# TODO: look up PDF in tags
# TODO: parse PDF and find PIDs
# TODO: add PIDs to Properties
# TODO: get kenney/special PID from secrets
# TODO: git / email stuff in Listings
