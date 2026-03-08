module SimplefinAccount::TypeMappable
  extend ActiveSupport::Concern

  # SimpleFIN provides minimal type info, so we use simple mappings
  TYPE_MAPPING = {
    "depository" => {
      accountable: Depository,
      subtype: "checking"
    },
    "credit" => {
      accountable: CreditCard,
      subtype: "credit_card"
    },
    "investment" => {
      accountable: Investment,
      subtype: "brokerage"
    },
    "loan" => {
      accountable: Loan,
      subtype: "other"
    }
  }.freeze

  DEFAULT_MAPPING = {
    accountable: Depository,
    subtype: "other"
  }.freeze

  def map_accountable(account_type)
    mapping = TYPE_MAPPING[account_type] || DEFAULT_MAPPING
    mapping[:accountable].new
  end

  def map_subtype(account_type)
    mapping = TYPE_MAPPING[account_type] || DEFAULT_MAPPING
    mapping[:subtype]
  end
end
