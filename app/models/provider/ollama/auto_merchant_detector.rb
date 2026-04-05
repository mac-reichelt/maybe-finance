class Provider::Ollama::AutoMerchantDetector
  def initialize(client, model, transactions:, user_merchants:)
    @client = client
    @model = model
    @transactions = transactions
    @user_merchants = user_merchants
  end

  def auto_detect_merchants
    response = client.chat(parameters: {
      model: model,
      messages: [
        { role: "system", content: instructions },
        { role: "user", content: developer_message }
      ],
      response_format: { type: "json_object" }
    })

    content = response.dig("choices", 0, "message", "content")
    Rails.logger.info("Ollama auto-detect merchants response received (model: #{model})")

    build_response(extract_merchants(content))
  end

  private
    attr_reader :client, :model, :transactions, :user_merchants

    AutoDetectedMerchant = Provider::LlmConcept::AutoDetectedMerchant

    def build_response(merchants)
      merchants.map do |merchant|
        AutoDetectedMerchant.new(
          transaction_id: merchant.dig("transaction_id"),
          business_name: normalize_ai_value(merchant.dig("business_name")),
          business_url: normalize_ai_value(merchant.dig("business_url")),
        )
      end
    end

    def normalize_ai_value(ai_value)
      return nil if ai_value == "null" || ai_value.nil?
      ai_value
    end

    def extract_merchants(content)
      response_json = JSON.parse(content)
      response_json.dig("merchants") || []
    end

    def developer_message
      <<~MESSAGE.strip_heredoc
        Here are the user's available merchants in JSON format:

        ```json
        #{user_merchants.to_json}
        ```

        Use BOTH your knowledge AND the user-generated merchants to auto-detect the following transactions:

        ```json
        #{transactions.to_json}
        ```

        Return "null" if you are not 80%+ confident in your answer.

        Respond with JSON in this exact format:
        {"merchants": [{"transaction_id": "<id>", "business_name": "<name or null>", "business_url": "<url or null>"}]}
      MESSAGE
    end

    def instructions
      <<~INSTRUCTIONS.strip_heredoc
        You are an assistant to a consumer personal finance app.

        You MUST respond with valid JSON only. No other text.

        Closely follow ALL the rules below while auto-detecting business names and website URLs:

        - Return 1 result per transaction
        - Correlate each transaction by ID (transaction_id)
        - Do not include the subdomain in the business_url (i.e. "amazon.com" not "www.amazon.com")
        - User merchants are considered "manual" user-generated merchants and should only be used in 100% clear cases
        - Be slightly pessimistic.  We favor returning "null" over returning a false positive.
        - NEVER return a name or URL for generic transaction names (e.g. "Paycheck", "Laundromat", "Grocery store", "Local diner")

        Determining a value:

        - First attempt to determine the name + URL from your knowledge of global businesses
        - If no certain match, attempt to match one of the user-provided merchants
        - If no match, return "null"

        Example 1 (known business):

        ```
        Transaction name: "Some Amazon purchases"

        Result:
        - business_name: "Amazon"
        - business_url: "amazon.com"
        ```

        Example 2 (generic business):

        ```
        Transaction name: "local diner"

        Result:
        - business_name: null
        - business_url: null
        ```
      INSTRUCTIONS
    end
end
