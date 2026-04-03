class Provider::Ollama::AutoCategorizer
  def initialize(client, model, transactions: [], user_categories: [])
    @client = client
    @model = model
    @transactions = transactions
    @user_categories = user_categories
  end

  def auto_categorize
    response = client.chat(parameters: {
      model: model,
      messages: [
        { role: "system", content: instructions },
        { role: "user", content: developer_message }
      ],
      response_format: { type: "json_object" }
    })

    content = response.dig("choices", 0, "message", "content")
    Rails.logger.info("Ollama auto-categorize response received (model: #{model})")

    build_response(extract_categorizations(content))
  end

  private
    attr_reader :client, :model, :transactions, :user_categories

    AutoCategorization = Provider::LlmConcept::AutoCategorization

    def build_response(categorizations)
      categorizations.map do |categorization|
        AutoCategorization.new(
          transaction_id: categorization.dig("transaction_id"),
          category_name: normalize_category_name(categorization.dig("category_name")),
        )
      end
    end

    def normalize_category_name(category_name)
      return nil if category_name == "null" || category_name.nil?
      category_name
    end

    def extract_categorizations(content)
      response_json = JSON.parse(content)
      response_json.dig("categorizations") || []
    end

    def developer_message
      <<~MESSAGE.strip_heredoc
        Here are the user's available categories in JSON format:

        ```json
        #{user_categories.to_json}
        ```

        Use the available categories to auto-categorize the following transactions:

        ```json
        #{transactions.to_json}
        ```

        Respond with JSON in this exact format:
        {"categorizations": [{"transaction_id": "<id>", "category_name": "<name or null>"}]}
      MESSAGE
    end

    def instructions
      <<~INSTRUCTIONS.strip_heredoc
        You are an assistant to a consumer personal finance app.  You will be provided a list
        of the user's transactions and a list of the user's categories.  Your job is to auto-categorize
        each transaction.

        You MUST respond with valid JSON only. No other text.

        Closely follow ALL the rules below while auto-categorizing:

        - Return 1 result per transaction
        - Correlate each transaction by ID (transaction_id)
        - Attempt to match the most specific category possible (i.e. subcategory over parent category)
        - Category and transaction classifications should match (i.e. if transaction is an "expense", the category must have classification of "expense")
        - If you don't know the category, return "null" as the category_name
          - You should always favor "null" over false positives
          - Be slightly pessimistic.  Only match a category if you're 60%+ confident it is the correct one.
        - Each transaction has varying metadata that can be used to determine the category
          - Note: "hint" comes from 3rd party aggregators and typically represents a category name that
            may or may not match any of the user-supplied categories
      INSTRUCTIONS
    end
end
