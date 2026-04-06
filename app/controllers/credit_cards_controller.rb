class CreditCardsController < ApplicationController
  include AccountableResource

  permitted_accountable_attributes(
    :id,
    :available_credit,
    :minimum_payment,
    :apr,
    :annual_fee,
    :expiration_date,
    :statement_end_day,
    :payment_due_day,
    :cashback_percentage
  )
end
