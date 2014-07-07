module SparkleBuilder
  class Engine < ::Rails::Engine

    JAVASCRIPTS = %w(jquery.multi-select.js jquery.serialize-object.min.js typeahead.bundle.min.js sparkle_builder.js)
    STYLESHEETS = %w(multi-select.css)

    config.to_prepare do
      require 'sparkle_formation'
      Rails.application.config.sparkle = {}
      SparkleUi::Setup.init!
      credentials = Rails.application.config.sparkle.
        try(:[], :storage).
        try(:[], :credentials)
      bucket = Rails.application.config.sparkle.
        try(:[], :storage).
        try(:[], :bucket)
      if(credentials && bucket)
        require 'fog'
        fog = Rails.application.config.sparkle[:storage_connection] = fog = Fog::Storage.new(credentials)
        Rails.application.config.sparkle[:storage_bucket] = fog.directories.get(bucket)
        unless(Rails.application.config.sparkle[:storage_bucket])
          Rails.application.config.sparkle[:storage_bucket] = fog.directories.create(:identity => bucket)
        end
      else
        Rails.logger.warn 'Builder cannot persist data. The `:bucket` and `:credentials` must be configured!'
      end
      # Register javascripts
      JAVASCRIPTS.each do |file|
        ActionView::Helpers::AssetTagHelper.register_javascript_expansion :plugins, file
        ActionView::Helpers::AssetTagHelper.register_javascript_expansion :sparkle_ui, file
      end
      # Register stylesheets
      STYLESHEETS.each do |file|
        ActionView::Helpers::AssetTagHelper.register_stylesheet_expansion :plugins, file
        ActionView::Helpers::AssetTagHelper.register_stylesheet_expansion :sparkle_ui, file
      end
    end

  end

  module Persistence

    def save_build(name, build)
      bucket.files.create(
        :identity => generate_build_path(name),
        :body => build
      )
    end

    def save_template(name, template)
      bucket.files.create(
        :identity => generate_template_path(name),
        :body => template
      )
    end

    def fetch_template(name, return_container=false)
      result = bucket.files.get(generate_template_path(name))
      return_container ? result : result.body
    end

    def fetch_build(name, return_container=false)
      build = bucket.files.get(generate_build_path(name))
      return_container ? build : JSON.load(build.body)
    end

    def get_prefix
      current_user.try(:username) || '_default'
    end

    def list_templates
      bucket.files.all(:prefix => File.join('stacks', get_prefix))
    end

    def delete_template(name)
      fetch_template(name, :container).destroy
    end

    def delete_build(name)
      fetch_build(name, :container).destroy
    end

    def generate_template_path(name)
      File.join('stacks', get_prefix, "#{name}.json")
    end

    def generate_build_path(name)
      File.join('builds', get_prefix, "#{name}.json")
    end

    def sparkle_api
      unless(Rails.application.config.sparkle[:orchestration_connection])
        raise 'No credentials provided for orchestration API connection!'
      end
      Rails.application.config.sparkle[:orchestration_connection]
    end

    def bucket
      unless(Rails.application.config.sparkle[:storage_bucket])
        raise 'No storage bucket available'
      end
      Rails.application.config.sparkle[:storage_bucket]
    end

  end
end
