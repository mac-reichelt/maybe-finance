class Provider::Ollama::ChatParser
  Error = Class.new(StandardError)

  def initialize(object, model: nil)
    @object = object
    @model = model
  end

  def parsed
    ChatResponse.new(
      id: response_id,
      model: response_model,
      messages: messages,
      function_requests: function_requests
    )
  end

  private
    attr_reader :object, :model

    ChatResponse = Provider::LlmConcept::ChatResponse
    ChatMessage = Provider::LlmConcept::ChatMessage
    ChatFunctionRequest = Provider::LlmConcept::ChatFunctionRequest

    def response_id
      object.dig("id") || SecureRandom.uuid
    end

    def response_model
      object.dig("model") || model
    end

    def messages
      choice = object.dig("choices", 0)
      return [] unless choice

      message = choice.dig("message")
      return [] unless message

      content = message.dig("content")
      return [] if content.blank?

      [
        ChatMessage.new(
          id: SecureRandom.uuid,
          output_text: content
        )
      ]
    end

    def function_requests
      choice = object.dig("choices", 0)
      return [] unless choice

      tool_calls = choice.dig("message", "tool_calls")
      return [] unless tool_calls.present?

      tool_calls.map do |tool_call|
        ChatFunctionRequest.new(
          id: tool_call.dig("id") || SecureRandom.uuid,
          call_id: tool_call.dig("id") || SecureRandom.uuid,
          function_name: tool_call.dig("function", "name"),
          function_args: tool_call.dig("function", "arguments")
        )
      end
    end
end
