# frozen_string_literal: true

require 'date'
require 'bankfeed_insights/transaction'
require 'bankfeed_insights/account'
require 'bankfeed_insights/calculators/average_monthly_income'

RSpec.describe BankfeedInsights::Calculators::AverageMonthlyIncome do
  def credit(date:, amount:)
    BankfeedInsights::Transaction.new(date: date, description: 'Wage', amount: amount, direction: :credit)
  end

  def debit(date:, amount:)
    BankfeedInsights::Transaction.new(date: date, description: 'Rent', amount: amount, direction: :debit)
  end

  describe '.call' do
    it 'averages credits over the number of distinct calendar months they span' do
      account = BankfeedInsights::Account.new(
        transactions: [
          credit(date: Date.new(2022, 4, 1), amount: 100),
          credit(date: Date.new(2022, 4, 15), amount: 50),
          credit(date: Date.new(2022, 5, 1), amount: 300),
          debit(date: Date.new(2022, 5, 2), amount: 999) # debits are ignored
        ]
      )

      result = described_class.call(account)

      expect(result).to eq(total: 450.0, months_covered: 2, average_monthly: 225.0)
    end

    it 'returns zeroed-out values when there are no credits' do
      account = BankfeedInsights::Account.new(transactions: [debit(date: Date.new(2022, 5, 1), amount: 10)])

      result = described_class.call(account)

      expect(result).to eq(total: 0.0, months_covered: 0, average_monthly: 0.0)
    end
  end
end
