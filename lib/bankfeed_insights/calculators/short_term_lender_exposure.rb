# frozen_string_literal: true

require_relative '../keywords'

module BankfeedInsights
  module Calculators
    # Loan Metrics: exposure to identified short-term/payday lenders — a strong
    # risk signal for a lending decision that isn't in the example list, but is
    # directly supported by this data (Ferratum, MoneyMe, Sunshine Loans, ...).
    module ShortTermLenderExposure
      def self.call(accounts)
        debits = accounts.flat_map(&:transactions).select(&:debit?)

        by_lender = Hash.new { |hash, key| hash[key] = { count: 0, total: 0.0 } }
        debits.each do |transaction|
          lender = identify_lender(transaction.description)
          next unless lender

          by_lender[lender][:count] += 1
          by_lender[lender][:total] += transaction.amount
        end

        {
          distinct_lenders: by_lender.keys,
          total_repayments: by_lender.values.sum { |v| v[:total] }.round(2),
          total_transaction_count: by_lender.values.sum { |v| v[:count] },
          by_lender: by_lender.transform_values { |v| { count: v[:count], total: v[:total].round(2) } }
        }
      end

      def self.identify_lender(description)
        text = description.downcase
        match = Keywords::SHORT_TERM_LENDERS.find { |_name, keywords| keywords.any? { |kw| text.include?(kw) } }
        match&.first
      end
    end
  end
end
