# frozen_string_literal: true

require 'date'
require 'bankfeed_insights/transaction'
require 'bankfeed_insights/account'
require 'bankfeed_insights/calculators/gambling_expenditure'

RSpec.describe BankfeedInsights::Calculators::GamblingExpenditure do
  def debit(description:, amount:)
    BankfeedInsights::Transaction.new(date: Date.new(2022, 5, 1), description: description, amount: amount, direction: :debit)
  end

  def credit(description:, amount:)
    BankfeedInsights::Transaction.new(date: Date.new(2022, 5, 1), description: description, amount: amount, direction: :credit)
  end

  describe '.call' do
    it 'sums gambling debits across accounts and computes their share of total expenditure' do
      accounts = [
        BankfeedInsights::Account.new(transactions: [
          debit(description: 'Money to Crownbet', amount: 100),
          debit(description: 'Rent payment', amount: 300),
          credit(description: 'Wage', amount: 5000) # credits are ignored entirely
        ]),
        BankfeedInsights::Account.new(transactions: [
          debit(description: 'TAB Sportsbet wager', amount: 100)
        ])
      ]

      result = described_class.call(accounts)

      expect(result[:total_expenditure]).to eq(500.0)
      expect(result[:gambling_expenditure]).to eq(200.0)
      expect(result[:gambling_pct_of_expenditure]).to eq(40.0)
      expect(result[:matched_transactions].map(&:description)).to contain_exactly('Money to Crownbet', 'TAB Sportsbet wager')
    end

    it 'is case-insensitive when matching keywords' do
      accounts = [BankfeedInsights::Account.new(transactions: [debit(description: 'CROWNBET Deposit', amount: 50)])]

      result = described_class.call(accounts)

      expect(result[:gambling_expenditure]).to eq(50.0)
    end

    it 'returns 0% when there is no expenditure at all' do
      accounts = [BankfeedInsights::Account.new(transactions: [])]

      result = described_class.call(accounts)

      expect(result[:gambling_pct_of_expenditure]).to eq(0.0)
    end
  end
end
