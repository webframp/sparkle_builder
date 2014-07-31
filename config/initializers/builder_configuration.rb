unless(Rails.application.config.sparkle[:storage])
  Rails.application.config.sparkle[:storage] = {}.with_indifferent_access
end
