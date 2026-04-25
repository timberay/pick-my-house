module ChecklistHelper
  def domain_label(domain)
    t("checklist.domains.#{domain.key}.label")
  end

  def item_label(item)
    t("checklist.items.#{item.key}.label")
  end
end
