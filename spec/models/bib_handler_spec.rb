require 'spec_helper'

describe BibHandler  do
  it "should consider a bib valid for processing" do
    bib = load_fixture 'bib.json'

    # TODO need to mock external responses
    # BibHandler.process bib
  end
end
