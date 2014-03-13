module SparkleBuilder
  class Engine < ::Rails::Engine

    config.to_prepare do
      if(Rails.application.config.respond_to?(:sparkle) && Rails.application.config.sparkle)
        sparkle_conf = Rails.application.config.sparkle.with_indifferent_access
      else
        sparkle_conf = {}.with_indifferent_access
      end
      Rails.application.config.sparkle = sparkle_conf
    end

  end
end
