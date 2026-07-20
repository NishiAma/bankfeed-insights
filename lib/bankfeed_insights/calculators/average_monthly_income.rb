# frozen_string_literal: true

module BankfeedInsights
  module Calculators
    # Account Aggregation: average monthly sales (deposits/credits), per account.
    module AverageMonthlyIncome
      def self.call(account)
        credits = account.transactions.select(&:credit?)
        return { total: 0.0, months_covered: 0, average_monthly: 0.0 } if credits.empty?

        total = credits.sum(&:amount)
        months_covered = credits.map { |t| [t.date.year, t.date.month] }.uniq.size

        {
          total: total.round(2),
          months_covered: months_covered,
          average_monthly: (total / months_covered).round(2)
        }
      end
    end
  end
end
