# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::VertexAI::Images do # rubocop:disable RSpec/SpecFilePathFormat
  let(:config) do
    instance_double(
      RubyLLM::Configuration,
      vertexai_project_id: 'test-project',
      vertexai_location: 'us-central1'
    )
  end

  let(:provider_double) { instance_double(RubyLLM::Providers::VertexAI, slug: 'vertexai') }

  let(:test_instance) do
    klass = Class.new do
      include RubyLLM::Protocols::Gemini::Images
      include RubyLLM::Providers::VertexAI::Images

      def initialize(provider, config)
        @provider = provider
        @config = config
      end
    end
    klass.new(provider_double, config)
  end

  describe '#images_url' do
    context 'when model uses generateContent' do
      it 'returns the VertexAI generateContent URL with project and location' do
        model_info = instance_double(
          RubyLLM::Model::Info,
          metadata: { supported_generation_methods: %w[generateContent countTokens] }
        )
        allow(RubyLLM::Models).to receive(:find).and_return(model_info)

        test_instance.instance_variable_set(:@model, 'gemini-2.5-flash-image')
        test_instance.instance_variable_set(:@generate_content_cache, {})

        expected = 'projects/test-project/locations/us-central1/publishers/' \
                   'google/models/gemini-2.5-flash-image:generateContent'
        expect(test_instance.images_url).to eq(expected)
      end
    end

    context 'when model uses predict' do
      it 'returns the VertexAI predict URL with project and location' do
        model_info = instance_double(
          RubyLLM::Model::Info,
          metadata: { supported_generation_methods: %w[predict] }
        )
        allow(RubyLLM::Models).to receive(:find).and_return(model_info)

        test_instance.instance_variable_set(:@model, 'imagen-4.0-generate-001')
        test_instance.instance_variable_set(:@generate_content_cache, {})

        expected = 'projects/test-project/locations/us-central1/publishers/' \
                   'google/models/imagen-4.0-generate-001:predict'
        expect(test_instance.images_url).to eq(expected)
      end
    end

    context 'with a different project and location' do
      let(:config) do
        instance_double(
          RubyLLM::Configuration,
          vertexai_project_id: 'my-project',
          vertexai_location: 'europe-west4'
        )
      end

      it 'uses the configured project and location' do
        model_info = instance_double(
          RubyLLM::Model::Info,
          metadata: { supported_generation_methods: %w[generateContent] }
        )
        allow(RubyLLM::Models).to receive(:find).and_return(model_info)

        test_instance.instance_variable_set(:@model, 'gemini-2.5-flash-image')
        test_instance.instance_variable_set(:@generate_content_cache, {})

        expected = 'projects/my-project/locations/europe-west4/publishers/google/models/' \
                   'gemini-2.5-flash-image:generateContent'
        expect(test_instance.images_url).to eq(expected)
      end
    end
  end
end
