# frozen_string_literal: true

require 'json'
require 'tempfile'
require 'bankfeed_insights/statement_loader'

RSpec.describe BankfeedInsights::StatementLoader do
  def write_fixture(payload)
    file = Tempfile.new(['statement', '.json'])
    file.write(payload.to_json)
    file.close
    file.path
  end

  describe '.load' do
    it 'builds an Account with its Transactions from the raw illion payload' do
      path = write_fixture(
        {
          accounts: {
            bank_of_statements: {
              accounts: [
                {
                  name: 'Transaction Account',
                  accountType: 'transaction',
                  statementData: {
                    details: [
                      { date: '31-05-2022', text: 'Wage', amount: 100.5, type: 'Credit' },
                      { date: '28-05-2022', text: 'Rent payment', amount: -50.25, type: 'Debit' }
                    ]
                  }
                }
              ]
            }
          }
        }
      )

      accounts = described_class.load(path)

      expect(accounts.size).to eq(1)
      account = accounts.first
      expect(account.name).to eq('Transaction Account')
      expect(account.account_type).to eq('transaction')

      wage, rent = account.transactions
      expect(wage.date).to eq(Date.new(2022, 5, 31))
      expect(wage.description).to eq('Wage')
      expect(wage.amount).to eq(100.5)
      expect(wage).to be_credit

      expect(rent.date).to eq(Date.new(2022, 5, 28))
      expect(rent.amount).to eq(50.25) # sign stripped, direction carries the meaning
      expect(rent).to be_debit
    end

    it 'flattens accounts across multiple institutions and accounts' do
      path = write_fixture(
        {
          accounts: {
            bank_a: { accounts: [{ name: 'Account 1', accountType: 'transaction', statementData: { details: [] } }] },
            bank_b: { accounts: [{ name: 'Account 2', accountType: 'savings', statementData: { details: [] } }] }
          }
        }
      )

      accounts = described_class.load(path)

      expect(accounts.map(&:name)).to contain_exactly('Account 1', 'Account 2')
    end

    it 'handles a missing statementData.details gracefully' do
      path = write_fixture(
        { accounts: { bank_a: { accounts: [{ name: 'No Data', accountType: 'transaction', statementData: {} }] } } }
      )

      accounts = described_class.load(path)

      expect(accounts.first.transactions).to eq([])
    end
  end
end
