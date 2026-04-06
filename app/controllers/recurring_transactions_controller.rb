class RecurringTransactionsController < ApplicationController
  before_action :set_recurring_transaction, only: %i[show edit update destroy confirm dismiss]

  def index
    @recurring_transactions = Current.family.recurring_transactions
      .includes(:category, :merchant)
      .order(:next_expected_date)

    @active = @recurring_transactions.active
    @pending = @recurring_transactions.pending_confirmation
    @subscriptions = @recurring_transactions.active.subscriptions
  end

  def show
  end

  def new
    @recurring_transaction = Current.family.recurring_transactions.new(
      currency: Current.family.currency,
      frequency: "monthly",
      start_date: Date.current
    )
    @categories = Current.family.categories.alphabetically
    @merchants = Current.family.assigned_merchants.alphabetically
  end

  def create
    @recurring_transaction = Current.family.recurring_transactions.new(recurring_transaction_params)

    if @recurring_transaction.save
      redirect_to recurring_transactions_path, notice: "Recurring transaction created"
    else
      @categories = Current.family.categories.alphabetically
      @merchants = Current.family.assigned_merchants.alphabetically
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @categories = Current.family.categories.alphabetically
    @merchants = Current.family.assigned_merchants.alphabetically
  end

  def update
    if @recurring_transaction.update(recurring_transaction_params)
      redirect_to recurring_transactions_path, notice: "Recurring transaction updated"
    else
      @categories = Current.family.categories.alphabetically
      @merchants = Current.family.assigned_merchants.alphabetically
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @recurring_transaction.destroy!
    redirect_to recurring_transactions_path, notice: "Recurring transaction deleted"
  end

  def confirm
    @recurring_transaction.confirm!
    redirect_to recurring_transactions_path, notice: "Recurring transaction confirmed"
  end

  def dismiss
    @recurring_transaction.dismiss!
    redirect_to recurring_transactions_path, notice: "Recurring transaction dismissed"
  end

  def detect
    detector = RecurringTransaction::Detector.new(Current.family)
    @detected = detector.detect_and_create!

    redirect_to recurring_transactions_path,
      notice: "#{@detected.size} recurring transaction(s) detected"
  end

  private

    def set_recurring_transaction
      @recurring_transaction = Current.family.recurring_transactions.find(params[:id])
    end

    def recurring_transaction_params
      params.require(:recurring_transaction).permit(
        :title, :amount, :currency, :frequency, :frequency_day,
        :frequency_interval, :start_date, :end_date, :next_expected_date,
        :is_subscription, :category_id, :merchant_id, :status
      )
    end
end
