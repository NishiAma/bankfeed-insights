# frozen_string_literal: true

require 'date'
require 'stringio'
require 'bankfeed_insights/transaction'
require 'bankfeed_insights/account'
require 'bankfeed_insights/report'

RSpec.describe BankfeedInsights::Report do
  def credit(description:, amount:, date: Date.new(2022, 5, 1))
    BankfeedInsights::Transaction.new(date: date, description: description, amount: amount, direction: :credit)
  end

  def debit(description:, amount:, date: Date.new(2022, 5, 1))
    BankfeedInsights::Transaction.new(date: date, description: description, amount: amount, direction: :debit)
  end

  describe '.print' do
    it 'prints all three sections with the underlying calculator results' do
      accounts = [
        BankfeedInsights::Account.new(
          name: 'Transaction Account',
          transactions: [
            credit(description: 'Wage', amount: 100),
            debit(description: 'Money to Crownbet', amount: 40),
            debit(description: 'Direct Debit FERRATUM', amount: 15)
          ]
        )
      ]

      output = capture_stdout { described_class.print(accounts) }

      expect(output).to include('BANKFEED INSIGHTS — STATEMENT ANALYSIS')
      expect(output).to include('[1] Average Monthly Income')
      expect(output).to include('Transaction Account')
      expect(output).to include('[2] Gambling Expenditure')
      expect(output).to include('Money to Crownbet')
      expect(output).to include('[3] Short-Term / Payday Lender Exposure')
      expect(output).to include('Ferratum')
    end

    it 'reports no lender activity when none is identified' do
      accounts = [BankfeedInsights::Account.new(name: 'Savings', transactions: [debit(description: 'Groceries', amount: 20)])]

      output = capture_stdout { described_class.print(accounts) }

      expect(output).to include('No short-term lender activity identified.')
    end
  end

  def capture_stdout(&block)
    original_stdout = $stdout
    $stdout = StringIO.new
    block.call
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
