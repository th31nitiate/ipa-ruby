#!/usr/bin/env ruby
#
# This is used to extract API arguments from the IPA API browser via HTML pages
#
require 'nokogiri'

html_data = File.read(ARGV[0])
xpath_section = ARGV[3].nil? ? '/html/body/div[1]/div[1]/div/div[2]/div/div/div[1]/div/div[' : ARGV[3]
string_array = []
sym_array = []

# We append the html data here tot he lib from the local file
doc = Nokogiri::HTML(html_data)
# We user arg 1 and to for the range
(ARGV[1]..ARGV[2]).each { |value| string_array.append(doc.xpath(xpath_section + value.to_s + ']/h3/text()').text) }
string_array.each { |k| sym_array.append(k.to_sym) }
puts sym_array.to_s
