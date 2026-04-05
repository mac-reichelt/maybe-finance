class Provider::Ollama::ChatConfig
  def initialize(functions: [], function_results: [])
    @functions = functions
    @function_results = function_results
  end

  def tools
    functions.map do |fn|
      {
        type: "function",
        function: {
          name: fn[:name],
          description: fn[:description],
          parameters: fn[:params_schema]
        }
      }
    end
  end

  def build_messages(prompt, instructions: nil)
    msgs = []

    msgs << { role: "system", content: instructions } if instructions.present?

    msgs << { role: "user", content: prompt }

    function_results.each do |fn_result|
      msgs << {
        role: "tool",
        tool_call_id: fn_result[:call_id],
        content: fn_result[:output].to_json
      }
    end

    msgs
  end

  private
    attr_reader :functions, :function_results
end
