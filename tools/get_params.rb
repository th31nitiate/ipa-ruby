#!/usr/bin/env ruby
#
# This is used to extract API arguments from the IPA API browser via HTML pages
#
# To access available methods for html document run the following command:
# ./tools/get_params.rb html_file 1 463 '/html/body/div[1]/div[1]/div/div[2]/div/div/div[2]/div/div[3]/div/div[2]/ul/li[' ']/a' true
# As you can see there is 463 different methods. We could just access this information by looking at the IPA python code
#
#
require 'nokogiri'

html_data = File.read(ARGV[0])
xpath_initial = ARGV[3].nil? ? '/html/body/div[1]/div[1]/div/div[2]/div/div/div[1]/div/div[' : ARGV[3]
xpath_end = ARGV[4].nil? ? ']/h3/text()' : ARGV[4]
return_string = ARGV[5]
string_array = []
sym_array = []

# We append the html data here tot he lib from the local file
doc = Nokogiri::HTML(html_data)
# We user arg 1 and to for the range
(ARGV[1]..ARGV[2]).each { |value| string_array.append(doc.xpath(xpath_initial + value.to_s + xpath_end).text) }
string_array.each { |k| sym_array.append(k.to_sym) }
puts return_string.nil? ? sym_array.to_s : string_array.to_s


# In order to get the method names. This includes those which have no underscores and those which do. This is helpful in
# updating the create_methods hash script. You require two sets of arrays, @methods and func.
# no_underder = []
# method_name = []
# string_array.each { |value| if value.include?('_') then method_name.append(value.split('_')[0]) else no_underder.append(value) end }
#
# no_underder.to_s
# method_name.uniq!.to_s