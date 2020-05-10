require 'spec_helper'
require 'hocho/property_providers/ruby_script'

RSpec.describe Hocho::PropertyProviders::RubyScript do
  let(:host) { double(:host) }
  subject { described_class.new(script: 'host.properties[:a] = :b') }

  describe "#determine" do
    it "runs template" do
      properties = {}
      allow(host).to receive(:properties).and_return(properties)
      subject.determine(host)
      expect(properties[:a]).to eq(:b)
    end
  end
end
