#!/usr/bin/env ruby
#
#= FreeIPA Ruby client
#
# Author: m3rl1n th31nitiate
#
#== Capabilities
#
# This library works with ruby by enabling the communication and provisioning of objects with IPA via
# the HTTP API. Authentication is currently done through username and password although other options may
# be possible.
#
# The GSSAPI authentication protocol seems to be broken. This could be caused by an outdated GSSAPI requisite
#
# == Main methods
#
# * login
#   * This method is responsible for managing logins for the users. The main thing to factor in is the ability to
#   perform multiple authentication method. What is required is that a token is generated so that it can be used
#   in alternative requests.
#   * Management of how long the token is valid for can be set on the FreeIPA server. Currently it is not possible to
#   supply your own token how that can be a later authentication option. A session timeout option is avalible but only
#   valid within the http client and not for the authentication itself.
# * api_post
#   * This method is what is used to interact with API server. It performs requests through the use of the httpclient
#   * Authentication tokens are stored in memory for the duration of the session
#   * It takes as arguments the API method, item and parameters relating to the method as input
#   * To find what methods & parameters can be used you can view the API browser via IPA
#
#
#
#

require 'httpclient'
require 'base64'
require 'gssapi'
require 'json'
require 'pry'

# Not sure if the GSSAPI is fully functional requires further testing

module IPA
  class Client
    attr_reader :uri, :http, :headers

    def initialize(host: nil, ca_cert: '/etc/ipa/ca.crt', username: nil, password: nil)
      raise ArgumentError, 'Missing FreeIPA host' unless host


      @uri = URI.parse("https://#{host}/ipa/session/json")

      @http = HTTPClient.new
      @http.ssl_config.set_trust_ca(ca_cert)
      @headers = { 'referer' => "https://#{@uri.host}/ipa/json", 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
      @method = :keberose
      # Username has to be set to enable HTTP based authentication
      if username
        @method = :user_pass
        @credentials = { 'user' => username.to_s, 'password' => password.to_s }
      end

      login(@uri.host)
    end

    # Need to change login username and password information
    def login(host)
      # Set the timeout to 15 minutes
      @session_timeout = (Time.new.to_i + 900)

      login_headers = { 'referer' => "https://#{@uri.host}/ipa/ui/index.html", 'Accept' => 'application/json' }

      if @method == :keberose
        login_method = 'login_kerberos'
        gssapi = GSSAPI::Simple.new(@uri.host, 'HTTP')
        # Initiate the security context
        token = gssapi.init_context
        login_headers.merge!('Authorization' => "Negotiate #{Base64.strict_encode64(token)}", 'Content-Type' => 'application/json')
        login_request = { method: 'ping', params: [[], {}] }
      elsif @method == :user_pass
        login_method = 'login_password'
        login_headers.merge!('Content-Type' => 'application/x-www-form-urlencoded', 'Accept' => 'text/plain')
        login_request = @credentials
      end

      login_uri = URI.parse("https://#{@uri.host}/ipa/session/#{login_method}")

      resp = @http.post(login_uri, login_request, login_headers)

      return unless resp.status != 200

      # invalid passowrd could also mean invalid username
      puts "HTTP #{resp.status.to_s + ':' + resp.reason} Error authenticating user: #{resp.headers['X-IPA-Rejection-Reason']}"
    end

    # Consider using catch throw here when working with large amount os data
    def api_post(method: nil, item: [], params: {})
      raise ArgumentError, 'Missing method in API request' unless method

      if Time.new.to_i > @session_timeout then
        login(@host)
      end

      request = {}
      request[:method] = method
      request[:params] = [[item || []], params]
      # We use a StandardError since it is based on the HTTP response code with a JSON payload definition
      begin
        resp = @http.post(@uri, request.to_json, @headers)
        JSON.parse(resp.body)['result']['result']
      rescue StandardError
        puts "The following error has occurred #{JSON.parse(resp.body)['error']['message']}"
      end
    end

    # This method can be used to view Host avalible with in a group in IPA
    def hostgroup_show(hostgroup: nil,all: false, params: {})
      raise ArgumentError, 'Hostgroup is required' unless hostgroup

      params[:all] = all

      api_post(method: 'hostgroup_show', item: hostgroup, params: params)
    end

    # This method is used to create an empty host group
    def hostgroup_add(hostgroup: nil, description: nil, all: false, params: {})
      raise ArgumentError, 'Hostgroup is required' unless hostgroup
      raise ArgumentError, 'description is required' unless description

      params[:all] = all
      params[:description] = description

      api_post(method: 'hostgroup_add', item: hostgroup, params: params)
    end

    # This method can be used to add a group member to a host group
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

    # This method is used to add
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

    # We have to be careful when working with parameter structs
    # This is because if you set a value to nil it IPA may not
    # auto generate the value even if it can
    def add_user(uid: nil, all: false, params: {})
      raise ArgumentError, 'UID is required' unless uid
      raise ArgumentError, 'Given is required' unless params[:givenname]
      raise ArgumentError, 'Surname is required' unless params[:sn]
      raise ArgumentError, 'Common is required' unless params[:cn]

      # Remove empty values from the string
      params.compact!

      # We can create a list of params then convert them to hash before passing them to the
      # library. This can be done using value.to_h
      api_post(method: 'user_add', item: uid, params: params)
    end

    def user_show(uid: nil, all: false, params: {})
      raise ArgumentError, 'User uid is required' unless uid

      params[:all] = all

      api_post(method: 'user_show', item: uid, params: params)
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