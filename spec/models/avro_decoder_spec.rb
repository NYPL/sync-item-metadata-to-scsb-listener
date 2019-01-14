require 'spec_helper'
require 'webmock/rspec'

describe AvroDecoder do
  before(:each) do
    ENV['PLATFORM_API_BASE_URL'] = 'https://example.com/api/v0.1/'

    [ 'Bib', 'Item' ].each do |schema_name|
      raw_response_file = File.new("./spec/fixtures/platform-api-current-schema-#{schema_name.downcase}.raw")
      stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}current-schemas/#{schema_name}").to_return(raw_response_file)
    end
  end

  after(:each) do
    WebMock.reset!
  end

  it "should create 'bib' AvroDecoder instance by name" do
    decoder = AvroDecoder.by_name 'Bib'
    expect(decoder).to be_a(AvroDecoder)
  end

  it "should create 'item' AvroDecoder instance by name" do
    decoder = AvroDecoder.by_name 'Item'
    expect(decoder).to be_a(AvroDecoder)
  end

  it "should decode avro-encoded bib" do
    decoder = AvroDecoder.by_name 'Bib'
    item = decoder.decode File.open('./spec/fixtures/bib-avro-encoded.txt').read
    expect(item).to be_a(Object)
    expect(item['id']).to eq('10079340')
  end

  it "should decode avro-encoded item" do
    decoder = AvroDecoder.by_name 'Item'
    item = decoder.decode File.open('./spec/fixtures/item-avro-encoded.txt').read
    expect(item).to be_a(Object)
    expect(item['id']).to eq('11907244')
  end

  it "should throw error if (item) data encoded incorrectly" do
    decoder = AvroDecoder.by_name 'Item'
    # Scramble the encoding a little by subbing 'A's for 'B's:
    bad_encoded_data = File.open('./spec/fixtures/item-avro-encoded.txt').read.gsub('A', 'B')
    expect { decoder.decode(bad_encoded_data) }.to raise_error(AvroError, "Error decoding data using Item schema")
  end


end
