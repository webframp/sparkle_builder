unless(Rails.application.config.sparkle[:storage])
  Rails.application.config.sparkle[:storage] = {}.with_indifferent_access
  Rails.application.config.sparkle[:builder] = {
    :hooks => {
      :create => {
        :before => [],
        :after => []
      }.with_indifferent_access,
      :update => {
        :before => [],
        :after => []
      }.with_indifferent_access,
      :destroy => {
        :before => [],
        :after => []
      }.with_indifferent_access
    }.with_indifferent_access
  }.with_indifferent_access
end
