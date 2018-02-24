require 'test_helper'

class SeasonTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  test 'latest_number returns highest season number' do
    create(:season, number: 1)
    create(:season, number: 3)
    create(:season, number: 2)

    assert_equal 3, Season.latest_number
  end

  test 'to_s returns number' do
    season = create(:season, number: 4)

    assert_equal '4', season.to_s
  end

  test 'to_param returns number' do
    season = create(:season, number: 5)

    assert_equal '5', season.to_param
  end

  test 'requires number' do
    season = Season.new

    refute_predicate season, :valid?
    assert_includes season.errors.messages[:number], "can't be blank"
  end

  test 'requires positive number' do
    season = Season.new(number: -1)

    refute_predicate season, :valid?
    assert_includes season.errors.messages[:number], 'must be greater than 0'
  end

  test 'requires integer number' do
    season = Season.new(number: 3.5)

    refute_predicate season, :valid?
    assert_includes season.errors.messages[:number], 'must be an integer'
  end

  test 'requires positive max_rank' do
    season = Season.new(max_rank: -1)

    refute_predicate season, :valid?
    assert_includes season.errors.messages[:max_rank], 'must be greater than 0'
  end

  test 'requires integer max_rank' do
    season = Season.new(max_rank: 3500.3)

    refute_predicate season, :valid?
    assert_includes season.errors.messages[:max_rank], 'must be an integer'
  end
end