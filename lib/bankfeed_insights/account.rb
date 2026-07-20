# frozen_string_literal: true

module BankfeedInsights
  Account = Struct.new(:name, :account_type, :transactions, keyword_init: true)
end
