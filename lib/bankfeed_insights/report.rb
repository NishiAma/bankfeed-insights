# frozen_string_literal: true

require_relative 'calculators/average_monthly_income'
require_relative 'calculators/gambling_expenditure'
require_relative 'calculators/short_term_lender_exposure'

module BankfeedInsights
  module Report
    def self.print(accounts)
      puts '=' * 72
      puts 'BANKFEED INSIGHTS — STATEMENT ANALYSIS'
      puts '=' * 72

      print_average_monthly_income(accounts)
      print_gambling_expenditure(accounts)
      print_short_term_lender_exposure(accounts)
      puts
    end

    def self.print_average_monthly_income(accounts)
      puts "\n[1] Average Monthly Income (deposits/credits) — per account"
      puts '-' * 72
      accounts.each do |account|
        result = Calculators::AverageMonthlyIncome.call(account)
        printf(
          "  %-20s total: $%10.2f  over %2d months  ->  avg: $%.2f/mo\n",
          account.name, result[:total], result[:months_covered], result[:average_monthly]
        )
      end
    end

    def self.print_gambling_expenditure(accounts)
      puts "\n[2] Gambling Expenditure as % of Total Expenditure — all accounts"
      puts '-' * 72
      gambling = Calculators::GamblingExpenditure.call(accounts)
      puts "  Total expenditure:     $#{format('%.2f', gambling[:total_expenditure])}"
      puts "  Gambling expenditure:  $#{format('%.2f', gambling[:gambling_expenditure])}"
      puts "  Gambling % of spend:   #{gambling[:gambling_pct_of_expenditure]}%"
      return if gambling[:matched_transactions].empty?

      puts '  Matched transactions:'
      gambling[:matched_transactions].each do |t|
        puts "    - #{t.date} #{t.description} ($#{format('%.2f', t.amount)})"
      end
    end

    def self.print_short_term_lender_exposure(accounts)
      puts "\n[3] Short-Term / Payday Lender Exposure — all accounts"
      puts '-' * 72
      lenders = Calculators::ShortTermLenderExposure.call(accounts)
      if lenders[:distinct_lenders].empty?
        puts '  No short-term lender activity identified.'
        return
      end

      puts "  Distinct lenders identified: #{lenders[:distinct_lenders].join(', ')}"
      puts "  Total repayments: $#{format('%.2f', lenders[:total_repayments])} " \
           "across #{lenders[:total_transaction_count]} transaction(s)"
      lenders[:by_lender].each do |name, v|
        puts "    - #{name}: $#{format('%.2f', v[:total])} (#{v[:count]} txn(s))"
      end
    end
  end
end
