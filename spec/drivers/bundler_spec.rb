require 'spec_helper'
require 'hocho/drivers/bundler'

RSpec.describe Hocho::Drivers::Bundler do
  it "ignores unknown initialize arguments" do
    expect { described_class.new(double, foo: :bar) }.not_to raise_error
  end
end
