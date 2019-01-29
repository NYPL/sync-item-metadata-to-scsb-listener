require 'spec_helper'
require 'webmock/rspec'
require 'aws-sdk-kms'

describe SierraMod11 do
  it "should produce expected check digit for a variety of bnumbers" do
    expect(SierraMod11.mod11('14272192')).to eq('14272192x')
    expect(SierraMod11.mod11('b14272192')).to eq('b14272192x')
    expect(SierraMod11.mod11('.b14272192')).to eq('.b14272192x')

    expect(SierraMod11.mod11('20909995')).to eq('209099951')
    expect(SierraMod11.mod11('b20909995')).to eq('b209099951')
    expect(SierraMod11.mod11('.b20909995')).to eq('.b209099951')

    expect(SierraMod11.mod11('20868979')).to eq('208689795')
    expect(SierraMod11.mod11('b20868979')).to eq('b208689795')
    expect(SierraMod11.mod11('.b20868979')).to eq('.b208689795')
  end

  it "should produce expected check digit for a variety of inumbers" do
    expect(SierraMod11.mod11('34556689')).to eq('345566890')
    expect(SierraMod11.mod11('i34556689')).to eq('i345566890')
    expect(SierraMod11.mod11('.i34556689')).to eq('.i345566890')
  end
end 
