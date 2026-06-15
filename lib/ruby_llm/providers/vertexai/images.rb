# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI
      # Image generation methods for the Vertex AI implementation
      module Images
        def images_url(with: nil, mask: nil) # rubocop:disable Lint/UnusedMethodArgument
          action = uses_generate_content?(@model) ? 'generateContent' : 'predict'
          "projects/#{@config.vertexai_project_id}/locations/#{@config.vertexai_location}" \
            "/publishers/google/models/#{@model}:#{action}"
        end
      end
    end
  end
end
