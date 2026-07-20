# frozen_string_literal: true

require_relative '../keywords'

module BankfeedInsights
  module Calculators
    # Risk & Expenditure: gambling spend as a percentage of total expenditure,
    # across all linked accounts.
    module GamblingExpenditure
      def self.call(accounts)
        debits = accounts.flat_map(&:transactions).select(&:debit?)
        total_expenditure = debits.sum(&:amount)

        gambling_debits = debits.select { |t| gambling?(t) }
        gambling_total = gambling_debits.sum(&:amount)

        {
          total_expenditure: total_expenditure.round(2),
          gambling_expenditure: gambling_total.round(2),
          gambling_pct_of_expenditure: total_expenditure.zero? ? 0.0 : (gambling_total.to_f / total_expenditure * 100).round(2),
          matched_transactions: gambling_debits
        }
      end

      def self.gambling?(transaction)
        text = transaction.description.downcase
        Keywords::GAMBLING.any? { |keyword| text.include?(keyword) }
      end
    end
  end
end
