# frozen_string_literal: true

RSpec.describe NJTransit::Error do
  describe "#initialize" do
    it "accepts a message" do
      error = described_class.new("Something went wrong")
      expect(error.message).to eq("Something went wrong")
    end

    it "accepts a response" do
      response = double("response")
      error = described_class.new("Error", response: response)
      expect(error.response).to eq(response)
    end
  end
end

RSpec.describe NJTransit::APIError do
  it "inherits from Error" do
    expect(described_class.superclass).to eq(NJTransit::Error)
  end
end

RSpec.describe NJTransit::AuthenticationError do
  it "inherits from ClientError" do
    expect(described_class.superclass).to eq(NJTransit::ClientError)
  end
end
