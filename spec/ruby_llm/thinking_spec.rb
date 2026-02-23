# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Thinking do
  describe '#to_s' do
    it 'returns the text as a string' do
      thinking = described_class.new(text: 'I need to consider this carefully')
      expect(thinking.to_s).to eq('I need to consider this carefully')
    end

    it 'returns an empty string when text is nil' do
      thinking = described_class.new(text: nil, signature: 'sig123')
      expect(thinking.to_s).to eq('')
    end

    it 'returns the text even when signature is also present' do
      thinking = described_class.new(text: 'some thought', signature: 'sig456')
      expect(thinking.to_s).to eq('some thought')
    end
  end

  describe '.build' do
    it 'returns nil when both text and signature are nil' do
      expect(described_class.build(text: nil, signature: nil)).to be_nil
    end

    it 'returns nil when text is empty and signature is nil' do
      expect(described_class.build(text: '', signature: nil)).to be_nil
    end

    it 'returns nil when text is nil and signature is empty' do
      expect(described_class.build(text: nil, signature: '')).to be_nil
    end

    it 'returns a Thinking instance when text is present' do
      result = described_class.build(text: 'thinking...', signature: nil)
      expect(result).to be_a(described_class)
      expect(result.text).to eq('thinking...')
      expect(result.signature).to be_nil
    end

    it 'returns a Thinking instance when signature is present' do
      result = described_class.build(text: nil, signature: 'sig123')
      expect(result).to be_a(described_class)
      expect(result.text).to be_nil
      expect(result.signature).to eq('sig123')
    end
  end
end
