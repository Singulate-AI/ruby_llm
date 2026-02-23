# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Chat do
  describe '.render_payload' do
    let(:model) { instance_double(RubyLLM::Model::Info, id: 'anthropic.claude-sonnet-4-20250514-v1:0', max_tokens: nil) }

    it 'includes schema instruction in system blocks when schema is provided' do
      schema = { type: 'object', properties: { name: { type: 'string' } } }
      user_message = RubyLLM::Message.new(role: :user, content: 'Generate a person')

      payload = described_class.render_payload(
        [user_message],
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: schema,
        thinking: nil
      )

      expect(payload[:system]).to be_an(Array)
      expect(payload[:system].length).to eq(1)
      expect(payload[:system].last[:text]).to include('json')
      expect(payload[:system].last[:text]).to include(schema.to_s)
    end

    it 'does not include system blocks when no schema or system messages are provided' do
      user_message = RubyLLM::Message.new(role: :user, content: 'Hello')

      payload = described_class.render_payload(
        [user_message],
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: nil,
        thinking: nil
      )

      expect(payload).not_to have_key(:system)
    end
  end
end
