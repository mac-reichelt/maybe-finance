class Provider::Simplefin
  BRIDGE_BASE_URL = "https://bridge.simplefin.org"

  attr_reader :access_url

  def initialize(access_url)
    @access_url = access_url
  end

  # Claims a setup token from SimpleFIN Bridge and returns the access URL
  # The setup token is a base64-encoded URL; POST to it to get the access URL
  def self.claim_setup_token(setup_token)
    claim_url = Base64.decode64(setup_token).strip

    uri = URI.parse(claim_url)
    raise ArgumentError, "Invalid setup token" unless uri.scheme == "https"

    response = Faraday.post(claim_url)

    unless response.success?
      raise StandardError, "Failed to claim SimpleFIN setup token: #{response.status}"
    end

    response.body.strip
  end

  # Fetches all accounts and their transactions from SimpleFIN
  # Options:
  #   start_date: Date - only return transactions on or after this date
  #   end_date: Date - only return transactions before this date
  def get_accounts(start_date: nil, end_date: nil)
    params = {}
    params["start-date"] = start_date.to_time.to_i if start_date
    params["end-date"] = end_date.to_time.to_i if end_date

    response = connection.get("#{base_path}/accounts", params)

    unless response.success?
      raise StandardError, "SimpleFIN API error: #{response.status} - #{response.body}"
    end

    JSON.parse(response.body)
  end

  private

    def connection
      parsed = URI.parse(access_url)

      @connection ||= Faraday.new(
        url: "#{parsed.scheme}://#{parsed.host}:#{parsed.port}",
        headers: { "Accept" => "application/json" }
      ) do |f|
        f.request :authorization, :basic, parsed.user, parsed.password
        f.request :retry, max: 2, interval: 1
        f.adapter Faraday.default_adapter
      end
    end

    def base_path
      URI.parse(access_url).path.chomp("/")
    end
end
