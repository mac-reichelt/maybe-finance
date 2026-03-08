class Provider::Klutch
  TRANSACTIONS_QUERY = <<~GRAPHQL
    query($filter: TransactionFilter) {
      transactions(filter: $filter) {
        id
        amount
        originalAmount
        transactionStatus
        transactionType
        merchantName
        cardPresent
        transactionDate
        category {
          id
          name
        }
        mcc {
          code
          description
        }
        card {
          id
          name
        }
        items {
          id
          description
          price
          quantity
        }
        declineReason
      }
    }
  GRAPHQL

  AUTH_MUTATION = <<~GRAPHQL
    mutation($clientId: String, $secretKey: String) {
      createSessionToken(clientId: $clientId, secretKey: $secretKey)
    }
  GRAPHQL

  attr_reader :endpoint, :client_id, :secret_key

  def initialize(endpoint:, client_id:, secret_key:)
    @endpoint = endpoint
    @client_id = client_id
    @secret_key = secret_key
  end

  def authenticate
    data = graphql_request(AUTH_MUTATION, { clientId: client_id, secretKey: secret_key })
    data["createSessionToken"]
  end

  def get_transactions(start_date:, end_date:, statuses: %w[PENDING SETTLED], types: %w[CHARGE PAYMENT])
    token = authenticate

    variables = {
      filter: {
        transactionStatus: statuses,
        transactionTypes: types,
        startDate: start_date.iso8601,
        endDate: end_date.iso8601
      }
    }

    data = graphql_request(TRANSACTIONS_QUERY, variables, token: token)
    data["transactions"] || []
  end

  private

    def graphql_request(query, variables = {}, token: nil)
      headers = { "Content-Type" => "application/json" }
      headers["Authorization"] = "Bearer #{token}" if token

      response = connection.post do |req|
        req.headers = headers
        req.body = { query: query, variables: variables }.to_json
      end

      unless response.success?
        raise StandardError, "Klutch API error: #{response.status} - #{response.body}"
      end

      body = JSON.parse(response.body)

      if body["errors"].present?
        raise StandardError, "Klutch GraphQL errors: #{body['errors'].to_json}"
      end

      body["data"] || {}
    end

    def connection
      @connection ||= Faraday.new(url: endpoint) do |f|
        f.request :retry, max: 2, interval: 1
        f.adapter Faraday.default_adapter
      end
    end
end
