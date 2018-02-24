class Season < ApplicationRecord
  LATEST_SEASON_CACHE_KEY = 'latest-season'

  validates :number, :max_rank, presence: true, numericality: { greater_than: 0, only_integer: true }

  has_many :matches, foreign_key: 'season', primary_key: 'number'

  scope :order_by_number, ->{ order(:number) }
  scope :latest_first, ->{ order(number: :desc) }

  after_create :reset_latest_number, if: :saved_change_to_number?

  delegate :to_s, :to_param, to: :number

  def self.latest_number(skip_cache: false)
    Rails.cache.delete(LATEST_SEASON_CACHE_KEY) if skip_cache

    cached_value = Rails.cache.fetch(LATEST_SEASON_CACHE_KEY)
    return cached_value if cached_value

    season = latest_first.first
    new_value = season.try(:number)
    Rails.cache.write(LATEST_SEASON_CACHE_KEY, new_value) if new_value

    new_value
  end

  private

  def reset_latest_number
    return unless number
    latest_number = self.class.latest_number

    if latest_number && number > latest_number
      Rails.cache.delete(LATEST_SEASON_CACHE_KEY)
    end
  end
end