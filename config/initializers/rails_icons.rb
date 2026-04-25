RailsIcons.configure do |config|
  config.default_library = "heroicons"
  config.libraries.heroicons.default_variant = "outline"
  config.libraries.heroicons.exclude_variants = [ :mini, :micro ]

  config.libraries.heroicons.outline.default.css = "w-5 h-5"
  config.libraries.heroicons.outline.default.stroke_width = "1.5"

  config.libraries.heroicons.solid.default.css = "w-5 h-5"
end
