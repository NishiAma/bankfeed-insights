# frozen_string_literal: true

require 'json'
require 'date'
require_relative 'transaction'
require_relative 'account'

module BankfeedInsights
  class StatementLoader
    def self.load(path)
      raw = JSON.parse(File.read(path))
      raw.fetch('accounts').flat_map do |_institution, institution_data|
        institution_data.fetch('accounts').map { |account_json| build_account(account_json) }
      end
    end

    def self.build_account(account_json)
      details = account_json.dig('statementData', 'details') || []

      transactions = details.map do |t|
        Transaction.new(
          date: Date.strptime(t.fetch('date'), '%d-%m-%Y'),
          description: t.fetch('text').to_s,
          amount: t.fetch('amount').to_f.abs,
          direction: t.fetch('type').to_s.casecmp('credit').zero? ? :credit : :debit
        )
      end

      Account.new(
        name: account_json['name'],
        account_type: account_json['accountType'],
        transactions: transactions
      )
    end
  end
end
