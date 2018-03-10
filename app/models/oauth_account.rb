class OAuthAccount < ApplicationRecord
  VALID_PLATFORMS = {
    'pc' => 'PC',
    'psn' => 'PlayStation',
    'xbl' => 'Xbox'
  }.freeze

  VALID_REGIONS = {
    'us' => 'United States',
    'eu' => 'Europe',
    'kr' => 'South Korea',
    'cn' => 'China',
    'global' => 'Global'
  }.freeze

  belongs_to :user, required: false

  validates :battletag, presence: true
  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: [:provider, :battletag] }
  validates :platform, inclusion: { in: VALID_PLATFORMS.keys }, allow_nil: true
  validates :region, inclusion: { in: VALID_REGIONS.keys }, allow_nil: true
  validates :avatar_url, format: %r{\Ahttps?://}, allow_nil: true, allow_blank: true

  scope :order_by_battletag, ->{ order('LOWER(battletag) ASC') }
  scope :without_user, ->{ where(user_id: nil) }

  after_update :remove_default, if: :saved_change_to_user_id?

  alias_attribute :to_s, :battletag

  has_many :matches, dependent: :destroy
  has_many :heroes, through: :matches
  has_many :season_shares, dependent: :destroy

  def name
    battletag.split('#').first
  end

  def overwatch_api_profile
    data = Rails.cache.fetch(overwatch_api_profile_cache_key, expires_in: 1.week) do
      overwatch_api.profile
    end
    return unless data

    OverwatchAPIProfile.new(data)
  end

  def overwatch_api_stats(heroes_by_name)
    data = Rails.cache.fetch(overwatch_api_stats_cache_key, expires_in: 1.week) do
      overwatch_api.stats
    end
    return unless data

    OverwatchAPIStats.new(data, heroes_by_name: heroes_by_name)
  end

  def overbuff_url
    "https://www.overbuff.com/players/#{platform}/#{to_param}?mode=competitive"
  end

  def master_overwatch_url
    "https://masteroverwatch.com/profile/#{platform}/#{region}/#{to_param}"
  end

  def play_overwatch_url
    "https://playoverwatch.com/en-us/career/#{platform}/#{to_param}"
  end

  def delete_career_high_cache
    Rails.cache.delete(career_high_cache_key)
  end

  def season_high(season)
    highest_sr_match = matches.in_season(season).with_rank.order('rank DESC').first
    highest_sr_match.try(:rank)
  end

  def career_high
    cache_key = career_high_cache_key
    existing_career_high = Rails.cache.fetch(cache_key)
    return existing_career_high if existing_career_high

    return unless persisted? && matches.any?

    highest_sr_match = matches.where('season <> ?', 1).with_rank.order('rank DESC').first
    new_career_high = highest_sr_match.try(:rank)

    Rails.cache.write(cache_key, new_career_high) if new_career_high

    new_career_high
  end

  def season_is_public?(season)
    season_number = season.is_a?(Season) ? season.number : season
    season_shares.exists?(season: season_number)
  end

  def can_be_unlinked?
    user && user.oauth_accounts.count > 1
  end

  def default?
    user && user.default_oauth_account == self
  end

  def active_seasons
    matches.select('DISTINCT season').order(:season).map(&:season)
  end

  def wipe_season(season)
    matches.in_season(season).destroy_all
  end

  def import(season, path:)
    importer = MatchImporter.new(oauth_account: self, season: season)
    importer.import(path)
    importer.matches
  end

  def export(season)
    exporter = MatchExporter.new(oauth_account: self, season: season)
    exporter.export
  end

  def last_placement_match_in(season)
    matches.in_season(season).placements.with_rank.ordered_by_time.last
  end

  def finished_placements?(season)
    return @finished_placements if defined? @finished_placements
    season_placement_count = matches.placements.in_season(season).count
    @finished_placements = if season_placement_count >= Match::TOTAL_PLACEMENT_MATCHES
      true
    else
      matches.non_placements.in_season(season).any? &&
        matches.in_season(season).placement_logs.any?
    end
  end

  def any_placements?(season)
    matches.placements.in_season(season).any?
  end

  def to_param
    return unless battletag
    User.parameterize(battletag)
  end

  def remove_default
    return unless user_id_before_last_save

    user = User.where(id: user_id_before_last_save).first
    return unless user && user.default_oauth_account == self

    user.default_oauth_account = user.oauth_accounts.first
    user.save
  end

  def platform_name
    VALID_PLATFORMS[platform]
  end

  def region_name
    VALID_REGIONS[region]
  end

  private

  def overwatch_api
    OverwatchAPI.new(battletag: battletag, region: region, platform: platform)
  end

  def overwatch_api_profile_cache_key
    "ow-api/profile/#{battletag}/#{region}/#{platform}"
  end

  def overwatch_api_stats_cache_key
    "ow-api/stats/#{battletag}/#{region}/#{platform}"
  end

  def career_high_cache_key
    "career-high-#{battletag}"
  end
end
