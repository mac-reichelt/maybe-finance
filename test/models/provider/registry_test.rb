require "test_helper"

class Provider::RegistryTest < ActiveSupport::TestCase
  test "synth configured with ENV" do
    Setting.stubs(:synth_api_key).returns(nil)

    with_env_overrides SYNTH_API_KEY: "123" do
      assert_instance_of Provider::Synth, Provider::Registry.get_provider(:synth)
    end
  end

  test "synth configured with Setting" do
    Setting.stubs(:synth_api_key).returns("123")

    with_env_overrides SYNTH_API_KEY: nil do
      assert_instance_of Provider::Synth, Provider::Registry.get_provider(:synth)
    end
  end

  test "synth not configured" do
    Setting.stubs(:synth_api_key).returns(nil)

    with_env_overrides SYNTH_API_KEY: nil do
      assert_nil Provider::Registry.get_provider(:synth)
    end
  end

  test "ollama configured with ENV" do
    Setting.stubs(:ollama_base_url).returns(nil)
    Setting.stubs(:ollama_model).returns(nil)

    with_env_overrides OLLAMA_BASE_URL: "http://localhost:11434", OLLAMA_MODEL: "qwen2.5:7b" do
      provider = Provider::Registry.get_provider(:ollama)
      assert_instance_of Provider::Ollama, provider
    end
  end

  test "ollama configured with Setting" do
    Setting.stubs(:ollama_base_url).returns("http://localhost:11434")
    Setting.stubs(:ollama_model).returns("llama3.1")

    with_env_overrides OLLAMA_BASE_URL: nil, OLLAMA_MODEL: nil do
      provider = Provider::Registry.get_provider(:ollama)
      assert_instance_of Provider::Ollama, provider
    end
  end

  test "ollama not configured" do
    Setting.stubs(:ollama_base_url).returns(nil)
    Setting.stubs(:ollama_model).returns(nil)

    with_env_overrides OLLAMA_BASE_URL: nil, OLLAMA_MODEL: nil do
      assert_nil Provider::Registry.get_provider(:ollama)
    end
  end

  test "llm concept includes ollama and openai" do
    registry = Provider::Registry.for_concept(:llm)
    assert_instance_of Provider::Registry, registry
  end
end
