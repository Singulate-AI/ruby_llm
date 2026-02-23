# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Anthropic::Chat do
  describe '.render_payload' do
    let(:model) { instance_double(RubyLLM::Model::Info, id: 'claude-sonnet-4-5', max_tokens: nil) }

    it 'embeds raw system content blocks unchanged' do
      system_raw = RubyLLM::Providers::Anthropic::Content.new(
        'avoid greetings',
        cache_control: { type: 'ephemeral' }
      )

      system_message = RubyLLM::Message.new(role: :system, content: system_raw)
      user_message = RubyLLM::Message.new(role: :user, content: 'Hello there')

      payload = described_class.render_payload(
        [system_message, user_message],
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: nil
      )

      expect(payload[:system]).to eq(system_raw.value)
      expect(payload[:messages].first[:content]).to eq([{ type: 'text', text: 'Hello there' }])
    end
  end

  describe '.build_system_content' do
    it 'returns an empty array when there are no system messages and no schema' do
      result = described_class.build_system_content([], nil)
      expect(result).to eq([])
    end

    it 'appends a schema instruction when schema is provided with system messages' do
      schema = { type: 'object', properties: { name: { type: 'string' } } }
      system_message = RubyLLM::Message.new(role: :system, content: 'Be helpful')

      result = described_class.build_system_content([system_message], schema)

      expect(result.length).to eq(2)
      expect(result.first).to eq({ type: 'text', text: 'Be helpful' })
      expect(result.last[:type]).to eq('text')
      expect(result.last[:text]).to include('json')
      expect(result.last[:text]).to include(schema.to_s)
    end

    it 'returns a schema instruction even when there are no system messages' do
      schema = { type: 'object', properties: { age: { type: 'integer' } } }

      result = described_class.build_system_content([], schema)

      expect(result.length).to eq(1)
      expect(result.first[:type]).to eq('text')
      expect(result.first[:text]).to include('json')
      expect(result.first[:text]).to include(schema.to_s)
    end
  end

  describe '.parse_completion_response' do
    it 'captures cache usage metrics on the message' do
      response_body = {
        'model' => 'claude-sonnet-4-5-20250929',
        'content' => [{ 'type' => 'text', 'text' => 'Hi!' }],
        'usage' => {
          'input_tokens' => 42,
          'output_tokens' => 5,
          'cache_read_input_tokens' => 21,
          'cache_creation_input_tokens' => 7
        }
      }

      response = instance_double(Faraday::Response, body: response_body)

      message = described_class.parse_completion_response(response)

      expect(message.input_tokens).to eq(42)
      expect(message.output_tokens).to eq(5)
      expect(message.cached_tokens).to eq(21)
      expect(message.cache_creation_tokens).to eq(7)
    end
  end
end
