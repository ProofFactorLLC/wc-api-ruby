require "httparty"
require "json"

require "woocommerce_api/oauth"
require "woocommerce_api/version"

module WooCommerce
  class API

    def initialize url, consumer_key, consumer_secret, args = {}
      # Required args
      @url = url
      @consumer_key = consumer_key
      @consumer_secret = consumer_secret

      # Optional args
      defaults = {version: "v3", verify_ssl: true}
      args = defaults.merge(args)

      @version = args[:version]
      @verify_ssl = args[:verify_ssl] == true
      @signature_method = args[:signature_method]

      # Internal args
      @is_ssl = @url.start_with? "https"
    end

    # Public: GET requests.
    #
    # endpoint - A String naming the request endpoint.
    #
    # Returns the request Hash.
    def get endpoint, data = nil
      do_request :get, add_query_params(endpoint, data)
    end

    # Public: POST requests.
    #
    # endpoint - A String naming the request endpoint.
    # data     - The Hash data for the request.
    #
    # Returns the request Hash.
    def post endpoint, data
      do_request :post, endpoint, data
    end

    # Public: PUT requests.
    #
    # endpoint - A String naming the request endpoint.
    # data     - The Hash data for the request.
    #
    # Returns the request Hash.
    def put endpoint, data
      do_request :put, endpoint, data
    end

    # Public: DELETE requests.
    #
    # endpoint - A String naming the request endpoint.
    #
    # Returns the request Hash.
    def delete endpoint, data = nil
      do_request :delete, add_query_params(endpoint, data)
    end

    protected

    def add_query_params(endpoint, data)
      return endpoint if data.nil? || data.empty?
      endpoint += '?' unless endpoint.include? '?'
      endpoint += '&' unless endpoint.end_with? '?'
      endpoint + URI.encode(flatten_hash(data).join('&'))
    end

    # Internal: Get URL for requests
    #
    # endpoint - A String naming the request endpoint.
    #
    # Returns the endpoint String.
    def get_url endpoint, method
      url = @url
      url = "#{url}/" unless url.end_with? "/"
      url = "#{url}wc-api/#{@version}/#{endpoint}"
      @is_ssl ? ssl_url(url) : oauth_url(url, method)
    end

    # Internal: Requests default options.
    #
    # method   - A String naming the request method
    # endpoint - A String naming the request endpoint.
    # data     - The Hash data for the request.
    #
    # Returns the response in JSON String.
    def do_request method, endpoint, data = {}
      url = get_url(endpoint, method)
      options = {
        format: :json,
        verify: @verify_ssl,
        headers: {
          "User-Agent" => "WooCommerce API Client-Ruby/#{WooCommerce::VERSION}",
          "Content-Type" => "application/json;charset=utf-8",
          "Accept" => "application/json"
        }
      }
      options.merge!(body: data.to_json) if data
      HTTParty.send(method, url, options)
    end

    # Internal: Generates the URL used for ssl connections
    #
    # url    - A String naming the current request url
    #
    # Returns a url to be used for the query.
    def ssl_url(url)
      add_query_params(url,
                       consumer_key: @consumer_key,
                       consumer_secret: @consumer_secret)
    end

    # Internal: Generates an oauth url given current settings
    #
    # url    - A String naming the current request url
    # method - The HTTP verb of the request
    #
    # Returns a url to be used for the query.
    def oauth_url(url, method)
      oauth = WooCommerce::OAuth.new(url,
                                     method,
                                     @version,
                                     @consumer_key,
                                     @consumer_secret,
                                     @signature_method)
      oauth.get_oauth_url
    end

    def flatten_hash(hash)
      hash.flat_map do |key, value|
        case value
        when Hash
          value.map do |inner_key, inner_value|
            "#{key}[#{inner_key}]=#{inner_value}"
          end
        when Array
          value.map { |inner_value| "#{key}[]=#{inner_value}" }
        else
          "#{key}=#{value}"
        end
      end
    end
  end
end
