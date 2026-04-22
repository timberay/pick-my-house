module ApplicationHelper
  def level_selected_class(level)
    {
      "ok" => "bg-green-600 text-white border-green-600",
      "warn" => "bg-yellow-500 text-white border-yellow-500",
      "severe" => "bg-red-600 text-white border-red-600"
    }.fetch(level, "bg-gray-200")
  end
end
