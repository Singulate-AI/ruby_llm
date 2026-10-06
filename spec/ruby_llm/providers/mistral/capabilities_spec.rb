# frozen_string_literal: true

require 'spec_helper'
require 'timeout'

RSpec.describe RubyLLM::Providers::Mistral::Capabilities do
  describe '.supports_reasoning?' do
    it 'recognizes native and adjustable reasoning models' do
      expect(described_class.supports_reasoning?('magistral-small-latest')).to be(true)
      expect(described_class.supports_reasoning?('mistral-small-latest')).to be(true)
      expect(described_class.supports_reasoning?('mistral-medium-3-5')).to be(true)
      expect(described_class.supports_reasoning?('mistral-medium-3.5')).to be(true)
      expect(described_class.supports_reasoning?('pixtral-12b')).to be(false)
    end
  end

  describe '.capabilities_for' do
    it 'matches voxtral transcribe variants' do
      expect(described_class.capabilities_for('voxtral-mini-transcribe')).to eq(['transcription'])
      expect(described_class.capabilities_for('voxtral-small')).not_to eq(['transcription'])
    end

    it 'matches long ids repeating voxtral without excessive backtracking' do
      model_id = 'voxtral-' * 10_000

      capabilities = Timeout.timeout(5) { described_class.capabilities_for(model_id) }

      expect(capabilities).not_to eq(['transcription'])
    end
  end
end
