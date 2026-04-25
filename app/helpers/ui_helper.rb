module UiHelper
  BUTTON_BASE = [
    "inline-flex items-center justify-center gap-2 rounded-md font-medium",
    "transition-colors duration-150",
    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500/50 focus-visible:ring-offset-2",
    "dark:focus-visible:ring-blue-400/50 dark:focus-visible:ring-offset-slate-900"
  ].join(" ").freeze

  BUTTON_VARIANTS = {
    primary:   "bg-blue-600 text-white hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-400",
    secondary: "bg-slate-100 text-slate-700 hover:bg-slate-200 dark:bg-slate-700 dark:text-slate-200 dark:hover:bg-slate-600",
    outline:   "border border-slate-200 bg-white text-slate-700 hover:bg-slate-50 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-200 dark:hover:bg-slate-700",
    danger:    "bg-red-600 text-white hover:bg-red-700 dark:bg-red-500 dark:hover:bg-red-400",
    danger_outline: "border border-red-400 bg-white text-red-700 hover:bg-red-50 dark:border-red-500 dark:bg-slate-800 dark:text-red-300 dark:hover:bg-red-900/30",
    ghost:     "text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-800"
  }.freeze

  BUTTON_SIZES = {
    sm: "h-8 px-3 text-sm",
    md: "h-11 px-4 text-base",
    lg: "h-12 px-6 text-base"
  }.freeze

  def ui_button_classes(variant: :primary, size: :md, full_width: false, extra: nil)
    [
      BUTTON_BASE,
      BUTTON_VARIANTS.fetch(variant.to_sym),
      BUTTON_SIZES.fetch(size.to_sym),
      ("w-full" if full_width),
      extra
    ].compact.join(" ")
  end

  INPUT_BASE = [
    "w-full rounded-md border bg-white text-slate-900",
    "border-slate-200 placeholder:text-slate-400",
    "focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500/20",
    "transition-colors duration-150",
    "dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100 dark:placeholder:text-slate-500",
    "dark:focus:border-blue-400 dark:focus:ring-blue-400/20"
  ].join(" ").freeze

  INPUT_SIZES = {
    sm: "h-8 px-3 text-sm",
    md: "h-11 px-3 text-base",
    lg: "h-12 px-4 text-base"
  }.freeze

  def ui_input_classes(size: :md, error: false, extra: nil)
    [
      INPUT_BASE,
      INPUT_SIZES.fetch(size.to_sym),
      ("border-red-500 focus:border-red-500 focus:ring-red-500/20 dark:border-red-400" if error),
      extra
    ].compact.join(" ")
  end

  def ui_label_classes
    "block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5 break-keep"
  end
end
