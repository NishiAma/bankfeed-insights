# frozen_string_literal: true

module BankfeedInsights
  module Keywords
    GAMBLING = %w[
      bet betting crownbet sportsbet ladbrokes bet365 betfair unibet neds
      pointsbet betstar tab casino poker keno wager bookmaker
    ].freeze

    # name => list of substrings (any match identifies the lender)
    # NB: multi-word phrases must be single array elements, not `%w[]`
    # (`%w[sunshine loan]` is ["sunshine", "loan"], and "loan" alone
    # over-matches almost every loan-related transaction).
    SHORT_TERM_LENDERS = {
      'Ferratum' => ['ferratum'],
      'MoneyMe' => ['moneyme'],
      'Sunshine Loans' => ['sunshine loan'],
      'G2G / Good To Go Loans' => ['g2g'],
      'Cash Converters' => ['cash converters'],
      'Nimble' => ['nimble'],
      'Wallet Wizard' => ['wallet wizard'],
      'Cigno' => ['cigno'],
      'Jacaranda Finance' => ['jacaranda'],
      'Agile Finance' => ['agile finance']
    }.freeze
  end
end
