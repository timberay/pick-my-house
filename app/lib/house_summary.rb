class HouseSummary
  attr_reader :house, :checks

  def self.for(house)
    new(house, house.inspection_checks.to_a)
  end

  def initialize(house, checks)
    @house = house
    @checks = checks
  end

  def counts
    @counts ||= {
      ok: by_severity[:ok].size,
      warn: by_severity[:warn].size,
      severe: by_severity[:severe].size,
      unchecked: unchecked_items.size
    }
  end

  def severe_items
    @severe_items ||= entries_for(:severe)
  end

  def warn_items
    @warn_items ||= entries_for(:warn)
  end

  def unchecked_items
    @unchecked_items ||= Checklist.items.reject { |i| checked_keys.include?(i.key) }
  end

  def deleted_items
    @deleted_items ||= checks.reject { |c| Checklist.item_keys.include?(c.item_key) }
  end

  private

  def entries_for(severity)
    (by_severity[severity] || []).map do |check|
      { check: check, item: Checklist.item(check.item_key) }
    end
  end

  def by_severity
    @by_severity ||= Hash.new { |h, k| h[k] = [] }.tap do |hash|
      live_checks.each { |c| hash[c.severity.to_sym] << c }
    end
  end

  def live_checks
    @live_checks ||= checks.select { |c| Checklist.item_keys.include?(c.item_key) }
  end

  def checked_keys
    @checked_keys ||= live_checks.map(&:item_key).to_set
  end
end
