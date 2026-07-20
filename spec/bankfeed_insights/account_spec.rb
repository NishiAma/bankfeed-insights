# frozen_string_literal: true

require 'bankfeed_insights/account'

RSpec.describe BankfeedInsights::Account do
  subject(:account) do
    described_class.new(name: 'Transaction Account', account_type: 'transaction', transactions: [:tx1, :tx2])
  end

  it 'exposes the attributes it was built with' do
    expect(account.name).to eq('Transaction Account')
    expect(account.account_type).to eq('transaction')
    expect(account.transactions).to eq([:tx1, :tx2])
  end
end
