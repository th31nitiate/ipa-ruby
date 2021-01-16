#!/usr/bin/env ruby
#
# https://docs.ruby-lang.org/en/2.0.0/OpenSSL.html
#
# openssl req -in csr.pem -noout -text
#
require 'openssl'

# Need to factor in request for service certificates
name = OpenSSL::X509::Name.parse("CN=#{ARGV[0]}")

key = OpenSSL::PKey::RSA.new 2048
csr = OpenSSL::X509::Request.new
csr.version = 0
csr.subject = name
csr.public_key = key.public_key
csr.sign key, OpenSSL::Digest::SHA1.new

open 'csr.pem', 'w' do |io|
  io.write csr.to_pem
end
