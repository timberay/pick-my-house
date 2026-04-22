module ApplicationHelper
  def rating_form_url(category:, house:, context:)
    if context == :owner
      house_rating_path(house, category.id)
    else
      share_rating_path(house.share_token, category.id)
    end
  end
end
