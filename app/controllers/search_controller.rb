# frozen_string_literal: true

class SearchController < ApplicationController
  before_action :authenticate_user!
  before_action :set_search_service

  # GET /search
  def index
    @results = @search_service.search if params[:query].present?
    @filters = @search_service.filters if params[:query].present?

    respond_to do |format|
      format.html
      format.json do
        if @results
          render json: {
            html: render_to_string(partial: "search_results", locals: { results: @results }),
            total_count: @results[:total_count],
            search_time: @results[:search_time],
            pagination: @results[:pagination]
          }
        else
          render json: { html: "", total_count: 0, search_time: 0 }
        end
      end
    end
  rescue StandardError => e
    Rails.logger.error "Search error: #{e.message}"

    respond_to do |format|
      format.html do
        flash.now[:alert] = "Search temporarily unavailable. Please try again."
        render :index
      end
      format.json do
        render json: {
          error: "Search temporarily unavailable",
          html: render_to_string(partial: "search_error")
        }, status: :internal_server_error
      end
    end
  end

  # GET /search/suggestions
  def suggestions
    suggestions = @search_service.suggestions

    render json: { suggestions: suggestions }
  rescue StandardError => e
    Rails.logger.error "Search suggestions error: #{e.message}"
    render json: { suggestions: [] }
  end

  # POST /search/save
  def save
    if params[:query].present? && params[:results_count].present?
      @search_service.save_search(params[:results_count].to_i)
      render json: { success: true }
    else
      render json: {
        success: false,
        error: "Query and results count are required"
      }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "Save search error: #{e.message}"
    render json: {
      success: false,
      error: "Unable to save search"
    }, status: :internal_server_error
  end

  # GET /search/history
  def history
    recent_searches = @search_service.recent_searches

    render json: { history: recent_searches }
  rescue StandardError => e
    Rails.logger.error "Search history error: #{e.message}"
    render json: { history: [] }
  end

  # DELETE /search/history
  def clear_history
    current_user.search_histories.delete_all

    render json: { success: true, message: "Search history cleared" }
  rescue StandardError => e
    Rails.logger.error "Clear history error: #{e.message}"
    render json: {
      success: false,
      error: "Unable to clear history"
    }, status: :internal_server_error
  end

  private

  def set_search_service
    search_params = params.permit(:query, :scope, :page, :per_page, filters: {})
    search_params[:ip_address] = request.remote_ip
    search_params[:user_agent] = request.user_agent

    @search_service = GlobalSearchService.new(current_user, search_params)
  end

  def search_params
    params.permit(:query, :scope, :page, :per_page, filters: {})
  end
end
