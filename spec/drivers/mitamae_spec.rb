require 'spec_helper'
require 'hocho/drivers/mitamae'

RSpec.describe Hocho::Drivers::Mitamae do
  it "ignores unknown initialize arguments" do
    expect { described_class.new(double, foo: :bar) }.not_to raise_error
  end
end
