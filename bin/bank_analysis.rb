#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'bankfeed_insights/statement_loader'
require 'bankfeed_insights/report'

path = ARGV[0] || File.expand_path('../data/sample_bank_statements.json', __dir__)
accounts = BankfeedInsights::StatementLoader.load(path)
BankfeedInsights::Report.print(accounts)
