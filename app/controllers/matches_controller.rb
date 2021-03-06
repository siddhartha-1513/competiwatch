class MatchesController < ApplicationController
  MATCH_PARAM_FIELDS = [
    :map_id, :rank, :comment, :prior_match_id, :placement, :result, :time_of_day,
    :day_of_week, :season, :enemy_thrower, :ally_thrower, :enemy_leaver, :ally_leaver,
    :account_id
  ].freeze

  before_action :authenticate_user!, except: :index
  before_action :set_account, only: [:index, :create]
  before_action :ensure_account_is_mine, only: :create
  before_action :set_season, only: [:index, :create]
  before_action :set_match, only: [:edit, :update, :destroy]
  before_action :ensure_season_is_visible, only: :index
  before_action :ensure_latest_match_is_old_enough, only: :create

  def index
    @can_edit = signed_in? && @account.user == current_user
    @matches = @account.matches.in_season(@season_number).
      includes(:prior_match, :map).ordered_by_time
    Match.prefill_group_members(@matches, user: @account.user)
    Match.prefill_heroes(@matches)
    set_streaks(@matches)
    @longest_win_streak = @matches.map(&:win_streak).compact.max
    @longest_loss_streak = @matches.map(&:loss_streak).compact.max
    @latest_match = @matches.last
    @placement_rank = placement_rank_from(@matches, season: @season_number,
                                          account: @account)

    if @can_edit
      @maps = get_maps
      @heroes_by_role = get_heroes_by_role
      @friends = current_user.friend_names(@season_number)
      @all_friends = current_user.all_friend_names
      placement = !@account.finished_placements?(@season_number)
      @match = @account.matches.new(prior_match: @latest_match, season: @season_number,
                                    placement: placement)
    end
  end

  def create
    @match = @account.matches.new(create_match_params)
    @match.season = @season_number
    @selected_heroes = (params[:heroes] || []).map(&:to_i)
    @selected_friend_names = params[:friend_names] || []

    if @selected_friend_names.size > Match::MAX_FRIENDS_PER_MATCH
      flash[:error] = "Cannot have more than #{Match::MAX_FRIENDS_PER_MATCH} other players " \
                      'in your group.'
      return render_edit_on_fail
    end

    @match.set_friends_from_names(@selected_friend_names)
    @match.hero_ids = @selected_heroes

    return render_edit_on_fail unless @match.save
    redirect_to matches_path(@season_number, @account, anchor: "match-row-#{@match.id}")
  end

  def edit
    @latest_match = @match.account.matches.ordered_by_time.last
    @maps = get_maps
    @heroes_by_role = get_heroes_by_role
    @friends = current_user.friend_names(@match.season)
    @all_friends = current_user.all_friend_names
    @season = Season.find_by_number(@match.season)
    @selected_friend_names = []
    @selected_heroes = []
  end

  def destroy
    season = @match.season
    @account = @match.account

    if @match.destroy
      flash[:notice] = "Successfully deleted #{@account}'s match."
      redirect_to matches_path(season, @account)
    else
      flash[:error] = 'Could not delete match.'
      render_edit_on_fail
    end
  end

  def update
    @match.assign_attributes(update_match_params)
    @account = @match.account
    @selected_friend_names = params[:friend_names] || []
    @selected_heroes = (params[:heroes] || []).map(&:to_i)

    unless @account && @account.user == current_user
      flash[:error] = 'Invalid account.'
      return render_edit_on_fail
    end

    if @selected_friend_names.size > Match::MAX_FRIENDS_PER_MATCH
      flash[:error] = "Cannot have more than #{Match::MAX_FRIENDS_PER_MATCH} other players in your group."
      return render_edit_on_fail
    end

    @match.set_friends_from_names(@selected_friend_names)
    @match.hero_ids = @selected_heroes

    return render_edit_on_fail unless @match.save
    redirect_to matches_path(@match.season, @account, anchor: "match-row-#{@match.id}")
  end

  private

  def render_edit_on_fail
    @friends = current_user.friend_names(@match.season)
    @all_friends = current_user.all_friend_names
    @maps = get_maps
    @heroes_by_role = get_heroes_by_role
    @latest_match = @account.matches.ordered_by_time.last
    unless defined? @season
      @season = Season.find_by_number(@match.season)
    end

    render 'matches/edit'
  end

  def update_match_params
    params.require(:match).permit(MATCH_PARAM_FIELDS)
  end

  def create_match_params
    params.require(:match).permit(MATCH_PARAM_FIELDS).except(:account_id)
  end

  def set_match
    @match = Match.where(id: params[:id]).first
    render_404 unless @match && @match.user == current_user
  end

  def get_maps
    Rails.cache.fetch('maps:v2') { Map.order(:name) }
  end

  def get_heroes_by_role
    heroes = Rails.cache.fetch('heroes') { Hero.order(:name) }
    heroes.group_by(&:role).sort_by { |role, _heroes| Hero::ROLE_SORT[role] }.to_h
  end

  def placement_rank_from(matches, season:, account:)
    placement_log_match = matches.placement_logs.first
    if placement_log_match
      placement_log_match.rank
    else
      last_placement = account.last_placement_match_in(season)
      last_placement.rank if last_placement
    end
  end

  def ensure_latest_match_is_old_enough
    latest_match = @account.user.matches.order(created_at: :desc).first
    return unless latest_match

    time_diff = Time.zone.now - latest_match.created_at
    return if time_diff >= 2.minutes

    flash[:error] = 'You are logging matches too frequently.'
    redirect_to matches_path(@season_number, @account)
  end
end
