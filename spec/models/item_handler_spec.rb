require 'spec_helper'

describe ItemHandler  do
  it "should consider an item with a rc location valid for processing" do
    rc_item = load_fixture 'rc-item.json'

    expect(ItemHandler.should_process?(rc_item)).to eq(true)
  end

  it "should consider an item without a rc location invalid for processing" do
    rc_item = load_fixture 'non-rc-item.json'

    expect(ItemHandler.should_process?(rc_item)).to eq(false)
  end
end
