#!/usr/bin/env ruby
#
# client.rb
#
# Author: m3rl1n th31nitiate
#

require 'httpclient'
require 'base64'
require 'gssapi'
require 'json'

# Not sure if the GSSAPI is fully funcational requires furher testing


module IPA
  class Client
    attr_reader :uri, :http, :headers

    def initialize(host: nil, ca_cert: '/etc/ipa/ca.crt', username: nil, password: nil)
      raise ArgumentError, 'Missing FreeIPA host' unless host


      @uri = URI.parse("https://#{host}/ipa/session/json")

      @host = host
      @http = HTTPClient.new
      @http.ssl_config.set_trust_ca(ca_cert)
      @headers = { 'referer' => "https://#{uri.host}/ipa/json", 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
      @method = :keberose
      # Username has to be set to enable HTTP based authentication
      if username
        @method = :user_pass
        @credentials = { 'user' => username.to_s, 'password' => password.to_s }
      end

      login(host)
    end


    # Need to change login username and password information
    def login(host)
      # Set the timeout to 15 minutes
      @session_timeout = (Time.new.to_i + 900)

      login_headers = { 'referer' => "https://#{uri.host}/ipa/ui/index.html", 'Accept' => 'application/json' }

      if @method == :keberose
        login_method = "login_kerberos"
        gssapi = GSSAPI::Simple.new(@uri.host, 'HTTP')
        # Initiate the security context
        token = gssapi.init_context
        login_headers.merge!('Authorization' => "Negotiate #{Base64.strict_encode64(token)}", 'Content-Type' => 'application/json')
        login_request = { method: 'ping', params: [[], {}] }
      elsif @method == :user_pass
        login_method = "login_password"
        login_headers.merge!('Content-Type' => 'application/x-www-form-urlencoded', 'Accept' => 'text/plain')
        login_request = { 'user' => @username.to_s, 'password' => @password.to_s }
      end

      login_uri = URI.parse("https://#{uri.host}/ipa/session/#{login_method}")

      self.http.post(login_uri, login_request, login_headers)
    end

    def api_post(method: nil, item: [], params: {})
      raise ArgumentError, 'Missing method in API request' unless method

      if Time.new.to_i > @session_timeout then
        self.login(@host)
      end

      request = {}
      request[:method] = method
      request[:params] = [[item || []], params]
      resp = http.post(uri, request.to_json, headers)
      JSON.parse(resp.body)
    end

    def hostgroup_show(hostgroup: nil,all: false, params: {})
      raise ArgumentError, 'Hostgroup is required' unless hostgroup

      params[:all] = all

      api_post(method: 'hostgroup_show', item: hostgroup, params: params)
    end

    def hostgroup_add(hostgroup: nil, description: nil, all: false, params: {})
      raise ArgumentError, 'Hostgroup is required' unless hostgroup
      raise ArgumentError, 'description is required' unless description

      params[:all] = all
      params[:description] = description

      api_post(method: 'hostgroup_add', item: hostgroup, params: params)
    end

    def hostgroup_add_member(hostgroup: nil, hostnames: nil, params: {})
      raise ArgumentError, 'Hostgroup is required' unless hostgroup
      raise ArgumentError, 'Hostnames is required' unless hostnames
      params[:all] = true

      if hostnames.kind_of?(Array)
        params[:host] = hostnames
      end
      if hostnames.kind_of?(String)
        params[:host] = [hostnames]
      end

      api_post(method: 'hostgroup_add_member', item: hostgroup, params: params)
    end

    def host_add(hostname: nil, all: false, force: false, random: nil, userpassword: nil, params: {})
      raise ArgumentError, 'Hostname is required' unless hostname

      params[:all] = all
      params[:force] = force
      params[:random] = random unless random.nil?
      params[:userpassword] = userpassword unless userpassword.nil?

      api_post(method: 'host_add', item: hostname, params: params)
    end

    def host_del(hostname: nil, params: {})
      raise ArgumentError, 'Hostname is required' unless hostname

      api_post(method: 'host_del', item: hostname, params: params)
    end

    def host_find(hostname: nil, all: false, params: {})
      params[:all] = all

      api_post(method: 'host_find', item: hostname, params: params)
    end

    def host_show(hostname: nil, all: false, params: {})
      raise ArgumentError, 'Hostname is required' unless hostname

      params[:all] = all

      api_post(method: 'host_show', item: hostname, params: params)
    end

    def host_exists?(hostname)
      resp = host_show(hostname: hostname)
      if resp['error']
        false
      else
        true
      end
    end
  end
end
