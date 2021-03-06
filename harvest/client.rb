require 'json'
require 'net/http'
require 'uri'
require 'openssl'
require 'base64'

module Harvest
  class Client
    def initialize(subdomain:, email:, password:)
      @subdomain = subdomain
      @email = email
      @password = password
    end

    def authorization
      Base64.encode64("#{@email}:#{@password}").delete("\r\n")
    end

    def headers
      {
        "Accept"        => "application/json",
        "Content-Type"  => "application/json",
        "Authorization" => "Basic #{authorization}",
        "User-Agent"    => "BIG_BROTHER"
      }
    end

    def host
      "#{@subdomain}.harvestapp.com"
    end

    def connection
      http = Net::HTTP.new(host, 443)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http
    end

    def projects(filters={})
      uri = URI.parse("https://#{host}/projects")
      response = connection.get(uri.request_uri, headers)
      json = JSON.parse(response.body)
      projects = json.collect { |object| object['project'] }

      projects.select do |project|
        filters.all? do |key, value|
          if project[key.to_s].is_a?(Array)
            project[key.to_s].include?(value)
          else
            project[key.to_s] == value
          end
        end
      end
    end

    def people(filters={})
      uri = URI.parse("https://#{host}/people")
      response = connection.get(uri.request_uri, headers)
      json = JSON.parse(response.body)
      people = json.collect { |object| object['user'] }

      people.select do |person|
        filters.all? do |key, value|
          if person[key.to_s].is_a?(Array)
            person[key.to_s].include?(value)
          else
            person[key.to_s] == value
          end
        end
      end
    end

    def total_billable_hours(person_id:, from:, to:)
      personal_time_entries(
        person_id: person_id,
        from: from,
        to: to,
        billable: true
      ).inject(0) do |sum, entry|
        sum + entry['day_entry']['hours'].to_f
      end
    end

    def project_time_entries(project_id:, from:, to:)
      uri = URI.parse("https://#{host}/projects/#{project_id}/entries")
      params = { from: from, to: to }
      uri.query = URI.encode_www_form(params)
      response = connection.get(uri.request_uri, headers)
      json = JSON.parse(response.body)
      entries = json.collect { |object| object['day_entry'] }
    end

    def personal_time_entries(person_id:, from:, to:, billable: false)
      uri = URI.parse("https://#{host}/people/#{person_id}/entries")

      if billable
        params = { from: from, to: to, billable: 'yes' }
      else
        params = { from: from, to: to }
      end

      uri.query = URI.encode_www_form(params)
      response = connection.get(uri.request_uri, headers)
      JSON.parse(response.body)
    end
  end
end
