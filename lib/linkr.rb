require 'ostruct'
require 'net/http'
require 'addressable/uri'

class Linkr
  class TooManyRedirects < StandardError; end

  attr_accessor :original_url, :redirect_limit, :timeout
  attr_writer :url, :response

  def initialize(original_url, opts={})
    opts = {
     :redirect_limit => 5,
     :timeout => 5
    }.merge(opts)

    @original_url = original_url
    @redirect_limit = opts[:redirect_limit]
    @timeout = opts[:timeout]
    @proxy = ENV['http_proxy'] ? Addressable::URI.parse(ENV['http_proxy']) : OpenStruct.new
    @link_cache = nil
  end

  def url
    resolve unless @url
    @url
  end

  def body
    response.body
  end

  def response
    resolve unless @response
    @response
  end

  def self.resolve(*args)
    self.new(*args).url
  end

  private

  def resolve
    raise TooManyRedirects if @redirect_limit < 0

    self.url = original_url unless @url
    @uri = Addressable::URI.parse(@url).normalize

    fix_relative_url if !@uri.normalized_site && @link_cache

    begin
      http = Net::HTTP::Proxy(@proxy.host, @proxy.port).new(@uri.hostname, @uri.port)
      http.read_timeout = http.open_timeout = @timeout
      self.response = http.request_head(@uri.request_uri)
    rescue
      raise URI::InvalidURIError
    end

    redirect if response.kind_of?(Net::HTTPRedirection)
  end

  def redirect
    @link_cache = @uri.normalized_site
    self.url = response['location']
    @redirect_limit -= 1
    resolve
  end

  def fix_relative_url
    @url = File.join(@link_cache, @uri.omit(:scheme,:authority).to_s)
    @uri = Addressable::URI.parse(@url).normalize
    @link_cache = nil
  end
end