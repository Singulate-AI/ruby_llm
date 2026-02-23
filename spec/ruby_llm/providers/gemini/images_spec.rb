# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Gemini::Images do
  # Create a test class that includes the Images module so we can test its methods
  let(:test_instance) do
    klass = Class.new do
      include RubyLLM::Providers::Gemini::Images

      # Provide a slug method used by check_generate_content
      def slug
        'gemini'
      end
    end
    klass.new
  end

  describe '#images_url' do
    context 'when model uses generateContent' do
      it 'returns the generateContent URL' do
        model_info = instance_double(
          RubyLLM::Model::Info,
          metadata: { supported_generation_methods: %w[generateContent countTokens] }
        )
        allow(RubyLLM::Models).to receive(:find).and_return(model_info)

        test_instance.instance_variable_set(:@model, 'gemini-2.5-flash-image')
        test_instance.instance_variable_set(:@generate_content_cache, {})

        expect(test_instance.images_url).to eq('models/gemini-2.5-flash-image:generateContent')
      end
    end

    context 'when model uses predict' do
      it 'returns the predict URL' do
        model_info = instance_double(
          RubyLLM::Model::Info,
          metadata: { supported_generation_methods: %w[predict] }
        )
        allow(RubyLLM::Models).to receive(:find).and_return(model_info)

        test_instance.instance_variable_set(:@model, 'imagen-4.0-generate-001')
        test_instance.instance_variable_set(:@generate_content_cache, {})

        expect(test_instance.images_url).to eq('models/imagen-4.0-generate-001:predict')
      end
    end
  end

  describe '#render_image_payload' do
    context 'when model uses generateContent' do
      before do
        model_info = instance_double(
          RubyLLM::Model::Info,
          metadata: { supported_generation_methods: %w[generateContent countTokens] }
        )
        allow(RubyLLM::Models).to receive(:find).and_return(model_info)
      end

      it 'returns a generateContent payload with aspect ratio' do
        payload = test_instance.render_image_payload('a cat', model: 'gemini-2.5-flash-image', size: '1920x1080')

        expect(payload).to have_key(:contents)
        expect(payload[:contents].first[:parts].first[:text]).to eq('a cat')
        expect(payload).to have_key(:generationConfig)
        expect(payload[:generationConfig][:responseModalities]).to eq(['IMAGE'])
        expect(payload[:generationConfig][:imageConfig][:aspectRatio]).to eq('16:9')
      end

      it 'defaults to 1:1 aspect ratio when size is nil' do
        payload = test_instance.render_image_payload('a cat', model: 'gemini-2.5-flash-image', size: nil)

        expect(payload[:generationConfig][:imageConfig][:aspectRatio]).to eq('1:1')
      end
    end

    context 'when model uses predict' do
      before do
        model_info = instance_double(
          RubyLLM::Model::Info,
          metadata: { supported_generation_methods: %w[predict] }
        )
        allow(RubyLLM::Models).to receive(:find).and_return(model_info)
      end

      it 'returns a predict payload' do
        payload = test_instance.render_image_payload('a cat', model: 'imagen-4.0-generate-001', size: '1024x1024')

        expect(payload).to have_key(:instances)
        expect(payload[:instances].first[:prompt]).to eq('a cat')
        expect(payload).to have_key(:parameters)
        expect(payload[:parameters][:sampleCount]).to eq(1)
      end
    end
  end

  describe '#calculate_aspect_ratio' do
    it 'returns 1:1 for nil size' do
      result = test_instance.send(:calculate_aspect_ratio, nil)
      expect(result).to eq('1:1')
    end

    it 'returns 1:1 for empty size' do
      result = test_instance.send(:calculate_aspect_ratio, '')
      expect(result).to eq('1:1')
    end

    it 'returns 1:1 for invalid format' do
      result = test_instance.send(:calculate_aspect_ratio, 'invalid')
      expect(result).to eq('1:1')
    end

    it 'returns 16:9 for 1920x1080' do
      result = test_instance.send(:calculate_aspect_ratio, '1920x1080')
      expect(result).to eq('16:9')
    end

    it 'returns 1:1 for 1024x1024' do
      result = test_instance.send(:calculate_aspect_ratio, '1024x1024')
      expect(result).to eq('1:1')
    end

    it 'returns 9:16 for 1080x1920 (portrait)' do
      result = test_instance.send(:calculate_aspect_ratio, '1080x1920')
      expect(result).to eq('9:16')
    end

    it 'returns 4:3 for 1024x768' do
      result = test_instance.send(:calculate_aspect_ratio, '1024x768')
      expect(result).to eq('4:3')
    end

    it 'returns 3:2 for 1500x1000' do
      result = test_instance.send(:calculate_aspect_ratio, '1500x1000')
      expect(result).to eq('3:2')
    end

    it 'returns 21:9 for ultrawide 2560x1080' do
      result = test_instance.send(:calculate_aspect_ratio, '2560x1080')
      expect(result).to eq('21:9')
    end

    it 'handles the × unicode multiplication sign' do
      result = test_instance.send(:calculate_aspect_ratio, '1920×1080')
      expect(result).to eq('16:9')
    end
  end

  describe '#uses_generate_content?' do
    it 'returns true when model metadata includes generateContent' do
      model_info = instance_double(
        RubyLLM::Model::Info,
        metadata: { supported_generation_methods: %w[generateContent countTokens] }
      )
      allow(RubyLLM::Models).to receive(:find).and_return(model_info)
      test_instance.instance_variable_set(:@generate_content_cache, {})

      expect(test_instance.send(:uses_generate_content?, 'gemini-2.5-flash-image')).to be true
    end

    it 'returns false when model metadata does not include generateContent' do
      model_info = instance_double(
        RubyLLM::Model::Info,
        metadata: { supported_generation_methods: %w[predict] }
      )
      allow(RubyLLM::Models).to receive(:find).and_return(model_info)
      test_instance.instance_variable_set(:@generate_content_cache, {})

      expect(test_instance.send(:uses_generate_content?, 'imagen-4.0-generate-001')).to be false
    end

    it 'falls back to name pattern matching when model is not found' do
      allow(RubyLLM::Models).to receive(:find).and_raise(RubyLLM::ModelNotFoundError, 'not found')
      test_instance.instance_variable_set(:@generate_content_cache, {})

      expect(test_instance.send(:uses_generate_content?, 'gemini-2.5-flash-image')).to be true
    end

    it 'falls back to false for non-gemini-image models when model is not found' do
      allow(RubyLLM::Models).to receive(:find).and_raise(RubyLLM::ModelNotFoundError, 'not found')
      test_instance.instance_variable_set(:@generate_content_cache, {})

      expect(test_instance.send(:uses_generate_content?, 'imagen-4.0-generate-001')).to be false
    end

    it 'falls back to name pattern when metadata has no supported_generation_methods' do
      model_info = instance_double(
        RubyLLM::Model::Info,
        metadata: {}
      )
      allow(RubyLLM::Models).to receive(:find).and_return(model_info)
      test_instance.instance_variable_set(:@generate_content_cache, {})

      expect(test_instance.send(:uses_generate_content?, 'gemini-2.5-flash-image')).to be true
    end

    it 'caches the result for subsequent calls' do
      model_info = instance_double(
        RubyLLM::Model::Info,
        metadata: { supported_generation_methods: %w[generateContent] }
      )
      allow(RubyLLM::Models).to receive(:find).and_return(model_info)
      test_instance.instance_variable_set(:@generate_content_cache, {})

      test_instance.send(:uses_generate_content?, 'gemini-2.5-flash-image')
      test_instance.send(:uses_generate_content?, 'gemini-2.5-flash-image')

      expect(RubyLLM::Models).to have_received(:find).once
    end
  end

  describe '#parse_image_response' do
    context 'when model uses generateContent' do
      before do
        model_info = instance_double(
          RubyLLM::Model::Info,
          metadata: { supported_generation_methods: %w[generateContent] }
        )
        allow(RubyLLM::Models).to receive(:find).and_return(model_info)
        test_instance.instance_variable_set(:@generate_content_cache, {})
      end

      it 'extracts image data from generateContent response format' do
        response = instance_double(Faraday::Response, body: {
                                     'candidates' => [{
                                       'content' => {
                                         'parts' => [{
                                           'inlineData' => {
                                             'data' => 'base64encodeddata',
                                             'mimeType' => 'image/png'
                                           }
                                         }]
                                       }
                                     }]
                                   })

        image = test_instance.send(:parse_image_response, response, model: 'gemini-2.5-flash-image')

        expect(image).to be_a(RubyLLM::Image)
        expect(image.data).to eq('base64encodeddata')
        expect(image.mime_type).to eq('image/png')
        expect(image.model_id).to eq('gemini-2.5-flash-image')
      end
    end

    context 'when model uses predict' do
      before do
        model_info = instance_double(
          RubyLLM::Model::Info,
          metadata: { supported_generation_methods: %w[predict] }
        )
        allow(RubyLLM::Models).to receive(:find).and_return(model_info)
        test_instance.instance_variable_set(:@generate_content_cache, {})
      end

      it 'extracts image data from predict response format' do
        response = instance_double(Faraday::Response, body: {
                                     'predictions' => [{
                                       'bytesBase64Encoded' => 'predictbase64data',
                                       'mimeType' => 'image/jpeg'
                                     }]
                                   })

        image = test_instance.send(:parse_image_response, response, model: 'imagen-4.0-generate-001')

        expect(image).to be_a(RubyLLM::Image)
        expect(image.data).to eq('predictbase64data')
        expect(image.mime_type).to eq('image/jpeg')
        expect(image.model_id).to eq('imagen-4.0-generate-001')
      end

      it 'defaults mime_type to image/png when not provided' do
        response = instance_double(Faraday::Response, body: {
                                     'predictions' => [{
                                       'bytesBase64Encoded' => 'predictbase64data'
                                     }]
                                   })

        image = test_instance.send(:parse_image_response, response, model: 'imagen-4.0-generate-001')

        expect(image.mime_type).to eq('image/png')
      end
    end
  end
end
