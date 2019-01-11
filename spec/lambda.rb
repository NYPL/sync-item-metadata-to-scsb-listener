require 'spec_helper'

describe "lambda handler" do
  #Validations
  it "should validate that barcodes are invalid if they don't fit the format" do
    barcodes_not_array        = Message.new(barcodes: "Garmonbozia")
    barcodes_not_right_length = Message.new(barcodes: ['123', '456', 789])
    
    expect(barcodes_not_array.valid?).to        eq(false)
    expect(barcodes_not_right_length.valid?).to eq(false)
  end
end
