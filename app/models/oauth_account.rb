class OauthAccount < ApplicationRecord
  belongs_to :user

  validates :battletag, presence: true
  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }

  scope :order_by_battletag, ->{ order('LOWER(battletag) ASC') }

  alias_attribute :to_s, :battletag

  has_many :matches, dependent: :destroy

  def friend_names_in_season(season)
    friend_names = {}
    matches.in_season(season).includes(:friends).map do |match|
      match.friends.each do |friend|
        friend_names[friend.name] ||= 1
      end
    end
    friend_names.keys.sort
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

  def self.find_by_battletag(battletag)
    where("LOWER(battletag) = ?", battletag.downcase).first
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
    User.parameterize(battletag)
  end
end
