# frozen_string_literal: true

require 'date'
require 'bankfeed_insights/transaction'
require 'bankfeed_insights/account'
require 'bankfeed_insights/calculators/short_term_lender_exposure'

RSpec.describe BankfeedInsights::Calculators::ShortTermLenderExposure do
  def debit(description:, amount:)
    BankfeedInsights::Transaction.new(date: Date.new(2022, 5, 1), description: description, amount: amount, direction: :debit)
  end

  def credit(description:, amount:)
    BankfeedInsights::Transaction.new(date: Date.new(2022, 5, 1), description: description, amount: amount, direction: :credit)
  end

  describe '.call' do
    it 'groups debits by identified lender, across accounts' do
      accounts = [
        BankfeedInsights::Account.new(transactions: [
          debit(description: 'Direct Debit 428198 FERRATUM 11813938', amount: 15.30),
          debit(description: 'Sunshine Loan Repayment', amount: 65.44)
        ]),
        BankfeedInsights::Account.new(transactions: [
          debit(description: 'MoneyMe payment', amount: 43.57),
          credit(description: 'MoneyMe Loan Funded', amount: 295.13) # credits are ignored
        ])
      ]

      result = described_class.call(accounts)

      expect(result[:distinct_lenders]).to contain_exactly('Ferratum', 'Sunshine Loans', 'MoneyMe')
      expect(result[:total_transaction_count]).to eq(3)
      expect(result[:total_repayments]).to eq(124.31)
      expect(result[:by_lender]['Ferratum']).to eq(count: 1, total: 15.30)
    end

    it 'does not misidentify a generic loan transaction as "Sunshine Loans"' do
      # Regression test: %w[sunshine loan] would silently split into two
      # separate keywords ("sunshine" and "loan"), and "loan" alone matches
      # almost any loan-related transaction. `['sunshine loan']` (a single
      # phrase) must not match plain "Loan Repayment" text.
      accounts = [BankfeedInsights::Account.new(transactions: [debit(description: 'Loan Repayment', amount: 124.40)])]

      result = described_class.call(accounts)

      expect(result[:distinct_lenders]).to be_empty
      expect(result[:total_repayments]).to eq(0.0)
    end

    it 'returns empty results when no lenders are identified' do
      accounts = [BankfeedInsights::Account.new(transactions: [debit(description: 'Groceries', amount: 50)])]

      result = described_class.call(accounts)

      expect(result[:distinct_lenders]).to eq([])
      expect(result[:total_transaction_count]).to eq(0)
    end
  end
end
