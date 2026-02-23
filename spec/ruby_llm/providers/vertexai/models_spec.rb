# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::VertexAI::Models do # rubocop:disable RSpec/SpecFilePathFormat
  let(:test_instance) do
    klass = Class.new do
      include RubyLLM::Providers::VertexAI::Models

      def slug
        'vertexai'
      end
    end
    klass.new
  end

  describe 'KNOWN_GOOGLE_MODELS' do
    it 'includes gemini-2.5-flash-image' do
      expect(described_class::KNOWN_GOOGLE_MODELS).to include('gemini-2.5-flash-image')
    end

    it 'includes imagen models' do
      imagen_models = %w[
        imagegeneration@005
        imagen-3.0-capability-001
        imagen-3.0-fast-generate-001
        imagen-3.0-generate-001
        imagen-3.0-generate-002
        imagen-4.0-fast-generate-001
        imagen-4.0-generate-001
        imagen-4.0-ultra-generate-001
      ]

      imagen_models.each do |model_id|
        expect(described_class::KNOWN_GOOGLE_MODELS).to include(model_id),
                                                        "Expected KNOWN_GOOGLE_MODELS to include '#{model_id}'"
      end
    end

    it 'includes embedding models' do
      expect(described_class::KNOWN_GOOGLE_MODELS).to include('text-embedding-005')
    end
  end

  describe '#build_known_metadata' do
    it 'returns metadata with supported_generation_methods for flash-image models' do
      metadata = test_instance.send(:build_known_metadata, 'gemini-2.5-flash-image')

      expect(metadata[:source]).to eq('known_models')
      expect(metadata[:version]).to eq('2.0')
      expect(metadata[:description]).to eq('Gemini 2.5 Flash Preview Image')
      expect(metadata[:supported_generation_methods]).to eq(%w[generateContent countTokens])
    end

    it 'returns basic metadata for non-flash-image models' do
      metadata = test_instance.send(:build_known_metadata, 'gemini-2.5-pro')

      expect(metadata).to eq({ source: 'known_models' })
      expect(metadata).not_to have_key(:supported_generation_methods)
    end

    it 'returns basic metadata for imagen models' do
      metadata = test_instance.send(:build_known_metadata, 'imagen-4.0-generate-001')

      expect(metadata).to eq({ source: 'known_models' })
      expect(metadata).not_to have_key(:supported_generation_methods)
    end
  end

  describe '#build_known_models' do
    it 'returns Model::Info objects for all known models' do
      models = test_instance.send(:build_known_models)

      expect(models.length).to eq(described_class::KNOWN_GOOGLE_MODELS.length)
      expect(models).to all(be_a(RubyLLM::Model::Info))
    end

    it 'sets the provider to vertexai slug' do
      models = test_instance.send(:build_known_models)

      models.each do |model|
        expect(model.provider).to eq('vertexai')
      end
    end

    it 'sets flash-image model metadata with generation methods' do
      models = test_instance.send(:build_known_models)
      flash_image = models.find { |m| m.id == 'gemini-2.5-flash-image' }

      expect(flash_image).not_to be_nil
      expect(flash_image.metadata[:supported_generation_methods]).to eq(%w[generateContent countTokens])
    end

    it 'sets default capabilities for known models' do
      models = test_instance.send(:build_known_models)

      models.each do |model|
        expect(model.capabilities).to eq(%w[streaming function_calling])
      end
    end
  end
end
