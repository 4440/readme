#!/usr/bin/env ruby

# gem install nokogiri
# gem install pdf-reader

require 'net/http'
require 'fileutils'
require 'nokogiri'
require 'pdf/reader'

class PdfLink
  attr_accessor :title, :href, :text
  def initialize(title, href, text=nil)
    @title = title
    @href = href
    @text = text
  end

  def schedule_a?
    return false unless @text
    @text.upcase.include? "SCHEDULE A"
  end

  def not_schedule_a?
    !schedule_a?
  end

  def assessment_num?
    title.to_i > 0 && title.length == 8
  end

  def not_assessment_num?
    !assessment_num?
  end

  def to_s
    return "title:#{title} | PDF:#{pdf_url}" if schedule_a?
    return "Assessment Number:#{title} | HREF:#{assessment_url}" if assessment_num?
    "UNKNOWN PDF LINK"
  end

  def pdf_url
    "#{SalePage.base_url}#{href}"
  end

  def assessment_url
    "#{SalePage.sale_url}#{href}"
  end
end

class SalePage
  attr_accessor :tags

  def SalePage.base_url
    # not "https://www.halifax.ca/home-property/property-taxes/tax-sale"
    "https://www.halifax.ca"
  end

  def SalePage.sale_url
    "https://www.halifax.ca/home-property/property-taxes/tax-sale"
  end

  def scrape!
    puts "Getting listings..."
    uri = URI(SalePage.sale_url)
    uri.freeze
    html = Net::HTTP.get(uri)
    doc = Nokogiri::HTML.parse(html)
    @tags = doc.xpath("//a[@data-entity-type]")
  end

  def deeds
    @tags
      .map {|t| PdfLink.new(t[:title], t[:href]) }
      .delete_if {|p| p.not_assessment_num? }
  end

  def list_pdf
    @tags
      .map {|t| PdfLink.new(t[:title], t[:href], t.text) }
      .delete_if {|p| p.not_schedule_a? }
      .first
      .pdf_url
  end
end

class Property
  attr_accessor :assessment_num, :redeemable
  def initialize(assessment_num, pids, price, redeemable)
    @assessment_num = assessment_num
    @pids = pids
    @price = price
    @redeemable = redeemable
  end

  def pids
    @pids.join(" & ")
  end

  def price
    "$#{@price.to_i + 1}"
  end

  def kenney?
    pids.include? "00453803"
  end
end

class ListingsPdf
  attr_accessor :lines

  def initialize(url)
    @url = url
    @file = "listings.pdf"
  end

  def fetch(uri_str, limit = 10)
    if !uri_str.to_s.include? "https"
      puts "### url '#{uri_str}' is missing a protocol. Adding 'https'..."
      uri_str = "https:#{uri_str}"
    end
    raise ArgumentError, 'too many HTTP redirects' if limit == 0
    response = Net::HTTP.get_response(URI(uri_str))
    case response
    when Net::HTTPSuccess then
      response
    when Net::HTTPRedirection then
      location = response['location']
      puts "### redirected to #{location}"
      fetch(location, limit - 1)
    else
      response.value
    end
  end

  def download!
    puts "Attempting to download pdf '#{@url}'..."
    uri = URI(@url)
    uri.freeze
    pdf = fetch(uri)
    File.write(@file, pdf.body)
  end

  def parse
    puts "Parsing pdf into property listings..."
    reader = PDF::Reader.new(File.expand_path(@file))
    @lines = reader.pages.map {|p| p.text.split(/\n/) }.flatten
    properties = @lines.map do |line|
      next if line.include? "Redeemable" # skip the header
      next if line.strip.length == 0 # skip empty
      next if line.include? "MOBILE HOME ONLY" # no thx
      assno = line[0..7].strip
      pids = line[77..97].split(",").map(&:strip)
      price = line[199..211].gsub("$", "").gsub(",", "").strip
      redeemable = line[223..225].strip
      Property.new(assno, pids, price, redeemable)
    end.compact
    properties
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
      f.puts "PIDs, Price, Assessment No, Redeemable"
      @properties.each do |p|
        f.puts "#{p.pids},#{p.price},#{p.assessment_num},#{p.redeemable}"
      end
      f.puts "# Contains 00453803 (Kenney lot)? - #{@properties.any?(&:kenney?)}"
    end
  end

  def compare_and_swap!
    old_listings = File.read("listings.csv") rescue ""
    if (old_listings != File.read("latest.tmp"))
      puts "New listings! Replacing 'listings.csv' and creating dated record..."
      FileUtils.cp("latest.tmp", "#{Time.now.strftime("%Y-%m-%d")}_listings.csv")
      FileUtils.cp("latest.tmp", "listings.csv")
      # TODO: commit to git repo (GH action)
      # TODO: send an email
    end
    FileUtils.rm_f("latest.tmp")
  end
end

def main
  page = SalePage.new
  page.scrape!

  pdf = ListingsPdf.new(page.list_pdf)
  pdf.download!

  listings = Listings.new(pdf.parse)
  listings.save_tmp!
  listings.compare_and_swap!
end

main()

# TODO: get kenney/special PID from secrets
# TODO: git / email stuff in Listings
