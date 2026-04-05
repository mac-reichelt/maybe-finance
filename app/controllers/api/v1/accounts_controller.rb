# frozen_string_literal: true

class Api::V1::AccountsController < Api::V1::BaseController
  include Pagy::Backend

  before_action :ensure_read_scope, only: :index
  before_action :ensure_write_scope, only: :sync_all

  def index
    family = current_resource_owner.family
    accounts_query = family.accounts.visible.alphabetically

    @pagy, @accounts = pagy(
      accounts_query,
      page: safe_page_param,
      limit: safe_per_page_param
    )

    @per_page = safe_per_page_param

    render :index
  rescue => e
    Rails.logger.error "AccountsController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render_json({ error: "internal_server_error", message: "An unexpected error occurred" }, status: :internal_server_error)
  end

  def sync_all
    family = current_resource_owner.family
    existing_sync = family.syncs.incomplete.first

    if existing_sync
      render_json({
        message: "Sync already in progress",
        sync: sync_payload(existing_sync)
      }, status: :ok)
    else
      sync = family.sync_later

      render_json({
        message: "Sync initiated for all accounts",
        sync: sync_payload(sync)
      }, status: :accepted)
    end
  rescue => e
    Rails.logger.error "AccountsController#sync_all error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render_json({ error: "internal_server_error", message: "An unexpected error occurred" }, status: :internal_server_error)
  end

  private

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def sync_payload(sync)
      {
        id: sync.id,
        status: sync.status,
        created_at: sync.created_at
      }
    end

    def safe_page_param
      page = params[:page].to_i
      page > 0 ? page : 1
    end

    def safe_per_page_param
      per_page = params[:per_page].to_i

      case per_page
      when 1..100
        per_page
      else
        25
      end
    end
end
