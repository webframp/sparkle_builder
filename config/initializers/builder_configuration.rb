unless(Rails.application.config.sparkle[:storage])
  Rails.application.config.sparkle[:storage] = Smash.new
  Rails.application.config.sparkle[:builder] = Smash.new(
    :hooks => {
      :create => {
        :before => [],
        :after => []
      },
      :update => {
        :before => [],
        :after => []
      },
      :destroy => {
        :before => [],
        :after => []
      }
    }
  )
end
