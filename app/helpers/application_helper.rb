module ApplicationHelper
  def level_selected_class(level)
    {
      "ok" => "border-green-600 bg-green-600 text-white dark:border-green-500 dark:bg-green-500",
      "warn" => "border-yellow-500 bg-yellow-500 text-white dark:border-yellow-400 dark:bg-yellow-400",
      "severe" => "border-red-600 bg-red-600 text-white dark:border-red-500 dark:bg-red-500"
    }.fetch(level, "border-slate-300 bg-slate-200 dark:border-slate-600 dark:bg-slate-700")
  end
end
