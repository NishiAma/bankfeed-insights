# frozen_string_literal: true

require 'date'
require 'bankfeed_insights/transaction'

RSpec.describe BankfeedInsights::Transaction do
  subject(:transaction) do
    described_class.new(date: Date.new(2022, 5, 1), description: 'Test', amount: 10.0, direction: direction)
  end

  context 'when direction is :credit' do
    let(:direction) { :credit }

    it { is_expected.to be_credit }
    it { is_expected.not_to be_debit }
  end

  context 'when direction is :debit' do
    let(:direction) { :debit }

    it { is_expected.to be_debit }
    it { is_expected.not_to be_credit }
  end
end
