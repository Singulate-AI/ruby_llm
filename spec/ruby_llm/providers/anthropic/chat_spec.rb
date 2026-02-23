# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Anthropic::Chat do
  describe '.render_payload' do
    let(:model) do
      instance_double(RubyLLM::Model::Info, id: 'claude-sonnet-4-5', max_tokens: nil,
                                            capabilities:)
    end
    let(:capabilities) do
      %w[function_calling reasoning vision streaming batch]
    end

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

    context 'when the capabilities include structured_output' do
      let(:capabilities) do
        %w[function_calling reasoning vision streaming batch structured_output]
      end

      it 'includes output_config when schema is provided' do
        schema = {
          name: 'response',
          schema: { type: 'object', properties: { name: { type: 'string' } } },
          strict: true
        }
        user_message = RubyLLM::Message.new(role: :user, content: 'Hello')

        payload = described_class.render_payload(
          [user_message],
          tools: {},
          temperature: nil,
          model: model,
          stream: false,
          schema: schema
        )

        expect(payload[:output_config]).to eq(
          format: { type: 'json_schema', schema: { type: 'object', properties: { name: { type: 'string' } } } }
        )
      end

      it 'strips strict key from schema' do
        schema = {
          name: 'response',
          schema: { type: 'object', strict: true, 'strict' => true, properties: { name: { type: 'string' } } },
          strict: true
        }
        user_message = RubyLLM::Message.new(role: :user, content: 'Hello')

        payload = described_class.render_payload(
          [user_message],
          tools: {},
          temperature: nil,
          model: model,
          stream: false,
          schema: schema
        )

        inner_schema = payload.dig(:output_config, :format, :schema)
        expect(inner_schema).not_to have_key(:strict)
        expect(inner_schema).not_to have_key('strict')
      end

      it 'uses canonical wrapped schema format' do
        schema = {
          name: 'PersonSchema',
          schema: {
            type: 'object',
            strict: true,
            properties: { name: { type: 'string' } }
          }
        }
        user_message = RubyLLM::Message.new(role: :user, content: 'Hello')

        payload = described_class.render_payload(
          [user_message],
          tools: {},
          temperature: nil,
          model: model,
          stream: false,
          schema: schema
        )

        expect(payload[:output_config]).to eq(
          format: { type: 'json_schema', schema: { type: 'object', properties: { name: { type: 'string' } } } }
        )
      end
    end

    it 'does not include output_config when schema is nil' do
      user_message = RubyLLM::Message.new(role: :user, content: 'Hello')

      payload = described_class.render_payload(
        [user_message],
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: nil
      )

      expect(payload).not_to have_key(:output_config)
    end

    it 'does not mutate the original schema' do
      schema = {
        name: 'response',
        schema: { type: 'object', strict: true, properties: { name: { type: 'string' } } },
        strict: true
      }
      user_message = RubyLLM::Message.new(role: :user, content: 'Hello')

      described_class.render_payload(
        [user_message],
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: schema
      )

      expect(schema[:schema]).to have_key(:strict)
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
