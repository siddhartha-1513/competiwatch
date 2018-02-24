module TrendsHelper
  def win_rate_color(win_rate)
    if win_rate >= 90
      'rgb(139, 236, 34)'
    elsif win_rate >= 60
      '#c4e556'
    elsif win_rate >= 50
      '#fdde73'
    elsif win_rate >= 40
      '#f0a05b'
    elsif win_rate >= 30
      '#EC914E'
    else
      '#de4f3b'
    end
  end

  def show_streaks_chart?(matches)
    show_win_loss_chart?(matches)
  end

  def show_win_loss_chart?(matches)
    matches.any?
  end

  def show_group_stats?(matches)
    show_group_member_chart?(matches)
  end

  def show_map_chart?(matches)
    matches.any? { |match| match.map.present? }
  end

  def show_group_size_chart?(matches)
    show_group_member_chart?(matches)
  end

  def show_group_member_chart?(matches)
    return @show_group_member_chart if defined? @show_group_member_chart
    @show_group_member_chart = matches.any? { |match| match.friends.any? }
  end

  def show_thrower_leaver_chart?(matches)
    return @show_thrower_leaver_chart if defined? @show_thrower_leaver_chart
    @show_thrower_leaver_chart = matches.any? { |match| match.thrower? || match.leaver? }
  end

  def show_career_high_heroes_chart?(matches, oauth_account)
    career_high = oauth_account.career_high
    return false unless career_high.present?

    matches.any? do |match|
      match.season != 1 && match.rank &&
        match.rank >= career_high - TrendsController::CAREER_HIGH_CUTOFF && match.heroes.any?
    end
  end

  def show_role_chart?(matches)
    show_heroes_chart?(matches)
  end

  def show_heroes_chart?(matches)
    return @show_heroes_chart if defined? @show_heroes_chart
    @show_heroes_chart = matches.any? { |match| match.heroes.any? }
  end

  def show_day_time_chart?(matches)
    matches.any? { |match| match.day_of_week.present? || match.time_of_day.present? }
  end
end
