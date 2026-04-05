class Provider::Ollama::ChatStreamParser
  Error = Class.new(StandardError)

  def initialize(object)
    @object = object
  end

  def parsed
    return nil unless object.is_a?(Hash)

    choice = object.dig("choices", 0)
    return nil unless choice

    finish_reason = choice.dig("finish_reason")

    if finish_reason == "stop" || finish_reason == "tool_calls"
      # Final chunk — build a complete response
      Chunk.new(type: "response", data: build_final_response)
    else
      delta = choice.dig("delta")
      return nil unless delta

      content = delta.dig("content")
      return nil unless content.present?

      Chunk.new(type: "output_text", data: content)
    end
  end

  private
    attr_reader :object

    Chunk = Provider::LlmConcept::ChatStreamChunk

    def build_final_response
      Provider::Ollama::ChatParser.new(object, model: object.dig("model")).parsed
    end
end
