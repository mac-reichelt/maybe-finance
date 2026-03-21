class KlutchItemsController < ApplicationController
  before_action :set_klutch_item, only: %i[destroy sync]

  def new
    # Renders the form for entering Klutch API credentials
  end

  def create
    Current.family.create_klutch_item!(
      endpoint: klutch_item_params[:endpoint],
      client_id: klutch_item_params[:client_id],
      secret_key: klutch_item_params[:secret_key],
      item_name: klutch_item_params[:name].presence || "Klutch Card"
    )

    redirect_to accounts_path, notice: t(".success")
  rescue => e
    redirect_to accounts_path, alert: t(".error", message: e.message)
  end

  def destroy
    @klutch_item.destroy_later
    redirect_to accounts_path, notice: t(".success")
  end

  def sync
    unless @klutch_item.syncing?
      @klutch_item.sync_later
    end

    respond_to do |format|
      format.html { redirect_back_or_to accounts_path }
      format.json { head :ok }
    end
  end

  private
    def set_klutch_item
      @klutch_item = Current.family.klutch_items.find(params[:id])
    end

    def klutch_item_params
      params.require(:klutch_item).permit(:endpoint, :client_id, :secret_key, :name)
    end
end
