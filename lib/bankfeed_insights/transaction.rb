# frozen_string_literal: true

module BankfeedInsights
  Transaction = Struct.new(:date, :description, :amount, :direction, keyword_init: true) do
    def credit?
      direction == :credit
    end

    def debit?
      direction == :debit
    end
  end
end
