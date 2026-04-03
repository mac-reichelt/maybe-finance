class Provider::Ollama < Provider
  include LlmConcept

  Error = Class.new(Provider::Error)

  def initialize(base_url, model: nil)
    @base_url = base_url.chomp("/")
    @default_model = model || "qwen2.5:7b"
    @client = ::OpenAI::Client.new(
      access_token: "ollama",
      uri_base: "#{@base_url}/v1"
    )
  end

  def supports_model?(model)
    # Ollama can serve any pulled model; be permissive here
    true
  end

  def auto_categorize(transactions: [], user_categories: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-categorize. Max is 25 per request." if transactions.size > 25

      AutoCategorizer.new(
        client,
        default_model,
        transactions: transactions,
        user_categories: user_categories
      ).auto_categorize
    end
  end

  def auto_detect_merchants(transactions: [], user_merchants: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-detect merchants. Max is 25 per request." if transactions.size > 25

      AutoMerchantDetector.new(
        client,
        default_model,
        transactions: transactions,
        user_merchants: user_merchants
      ).auto_detect_merchants
    end
  end

  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, previous_response_id: nil)
    with_provider_response do
      chat_model = model.presence || default_model

      chat_config = ChatConfig.new(
        functions: functions,
        function_results: function_results
      )

      messages = chat_config.build_messages(prompt, instructions: instructions)

      has_tools = chat_config.tools.present?

      # When tools are defined, use non-streaming to ensure tool_calls are
      # captured reliably. Synthesize streaming events for the caller.
      if has_tools || streamer.nil?
        params = {
          model: chat_model,
          messages: messages,
          tools: chat_config.tools.presence || nil
        }.compact

        raw_response = client.chat(parameters: params)
        parsed = ChatParser.new(raw_response, model: chat_model).parsed

        if streamer.present?
          # Synthesize streaming events so the Responder receives expected callbacks
          if parsed.messages.any?
            parsed.messages.each do |msg|
              streamer.call(Provider::LlmConcept::ChatStreamChunk.new(type: "output_text", data: msg.output_text))
            end
          end
          streamer.call(Provider::LlmConcept::ChatStreamChunk.new(type: "response", data: parsed))
        end

        parsed
      else
        collected_chunks = []

        stream_proxy = proc do |chunk, _bytesize|
          parsed_chunk = ChatStreamParser.new(chunk).parsed

          unless parsed_chunk.nil?
            streamer.call(parsed_chunk)
            collected_chunks << parsed_chunk
          end
        end

        params = {
          model: chat_model,
          messages: messages,
          stream: stream_proxy
        }

        raw_response = client.chat(parameters: params)

        response_chunk = collected_chunks.find { |chunk| chunk.type == "response" }
        response_chunk&.data || ChatParser.new(raw_response || {}, model: chat_model).parsed
      end
    end
  end

  private
    attr_reader :client, :default_model, :base_url
end
