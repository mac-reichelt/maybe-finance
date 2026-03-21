class SimplefinItemsController < ApplicationController
  before_action :set_simplefin_item, only: %i[destroy sync]

  def new
    # Renders the form for entering a SimpleFIN setup token
  end

  def create
    Current.family.create_simplefin_item!(
      setup_token: simplefin_item_params[:setup_token],
      item_name: simplefin_item_params[:name].presence || "SimpleFIN"
    )

    redirect_to accounts_path, notice: t(".success")
  rescue => e
    redirect_to accounts_path, alert: t(".error", message: e.message)
  end

  def destroy
    @simplefin_item.destroy_later
    redirect_to accounts_path, notice: t(".success")
  end

  def sync
    unless @simplefin_item.syncing?
      @simplefin_item.sync_later
    end

    respond_to do |format|
      format.html { redirect_back_or_to accounts_path }
      format.json { head :ok }
    end
  end

  private
    def set_simplefin_item
      @simplefin_item = Current.family.simplefin_items.find(params[:id])
    end

    def simplefin_item_params
      params.require(:simplefin_item).permit(:setup_token, :name)
    end
end
