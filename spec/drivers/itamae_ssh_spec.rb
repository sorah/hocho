require 'spec_helper'
require 'hocho/drivers/itamae_ssh'

RSpec.describe Hocho::Drivers::ItamaeSsh do
  it "ignores unknown initialize arguments" do
    expect { described_class.new(double, foo: :bar) }.not_to raise_error
  end
end
