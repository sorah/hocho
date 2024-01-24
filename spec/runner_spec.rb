require 'spec_helper'
require 'hocho/runner'
require 'hocho/drivers/bundler'
require 'hocho/drivers/itamae_ssh'
require 'hocho/drivers/mitamae'

RSpec.describe Hocho::Runner do
  let(:host) { double(:host, name: "example.com") }

  it "runs bundler" do
    instance = described_class.new(host, driver: :bundler)
    expect_any_instance_of(Hocho::Drivers::Bundler).to receive(:run)

    expect { instance.run }.to output("=> Running on example.com using bundler\n").to_stdout
  end

  it "runs itamae via ssh" do
    instance = described_class.new(host, driver: :itamae_ssh)
    expect_any_instance_of(Hocho::Drivers::ItamaeSsh).to receive(:run)

    expect { instance.run }.to output("=> Running on example.com using itamae_ssh\n").to_stdout
  end

  it "runs mitamae" do
    instance = described_class.new(host, driver: :mitamae)
    expect_any_instance_of(Hocho::Drivers::Mitamae).to receive(:run)

    expect { instance.run }.to output("=> Running on example.com using mitamae\n").to_stdout
  end

  it "complains about unknown driver" do
    instance = described_class.new(host, driver: :foo)

    expect { instance.run }
      .to raise_error(Hocho::Utils::Finder::NotFound)
      .and output("=> Running on example.com using foo\n").to_stdout
  end
end
