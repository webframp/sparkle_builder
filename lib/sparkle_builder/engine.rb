module SparkleBuilder
  class Engine < ::Rails::Engine

    config.to_prepare do
      require 'sparkle_formation'
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
        storage_bucket = fog.directories.get(bucket)
        unless(storage_bucket)
          storage_bucket = fog.directories.create(:key => bucket)
        end
        Rails.application.config.sparkle[:storage_bucket] = storage_bucket
        unless(Rails.application.config.sparkle[:storage_bucket])
          Rails.application.config.sparkle[:storage_bucket] = fog.directories.create(:identity => bucket)
        end
      else
        Rails.logger.warn 'Builder cannot persist data. The `:bucket` and `:credentials` must be configured!'
      end
    end

  end

  module Persistence

    # Persist build metadata to storage
    #
    # @param name [String] name of build
    # @param build [Hash]
    # @return [Fog::File]
    def save_build(name, build)
      bucket.files.create(
        :identity => generate_build_path(name),
        :body => build
      )
    end

    # Persist template to storage
    #
    # @param name [String] name of template
    # @param template [String] JSON template
    # @return [Fog::File]
    def save_template(name, template)
      bucket.files.create(
        :identity => generate_template_path(name),
        :body => template
      )
    end

    # Retrieve template from storage
    #
    # @param name [String] name of template
    # @param return_container [TrueClass, FalseClass] return remote reponse instead of string
    # @return [Fog::File, String]
    def fetch_template(name, return_container=false)
      result = bucket.files.get(generate_template_path(name))
      return_container ? result : result.body
    end

    # Retrieve build from storage
    #
    # @param name [String] name of template
    # @param return_container [TrueClass, FalseClass] return container
    # @return [Fog::File, String]
    def fetch_build(name, return_container=false)
      build = bucket.files.get(generate_build_path(name))
      return_container ? build : JSON.load(build.body)
    end

    # @return [String] storage key prefix
    def get_prefix
      current_user.try(:username) || '_default'
    end

    # @return [Array<Fog::Files>] all allowed templates
    def list_templates
      bucket.files.all(:prefix => File.join('stacks', get_prefix))
    end

    # Delete template from persistent storage
    #
    # @param name [String] name of template
    def delete_template(name)
      fetch_template(name, :container).destroy
    end

    # Delete build metadata from persistent storage
    #
    # @param name [String] name of build
    def delete_build(name)
      fetch_build(name, :container).destroy
    end

    # Generates persistent storage key for template
    #
    # @param name [String] template name
    # @return [String] key
    def generate_template_path(name)
      File.join('stacks', get_prefix, "#{name}.json")
    end

    # Generates persistent storage key for build metadata
    #
    # @param name [String] build name
    # @return [String] key
    def generate_build_path(name)
      File.join('builds', get_prefix, "#{name}.json")
    end

    # @return [Fog::Orchestration]
    def sparkle_api
      unless(Rails.application.config.sparkle[:orchestration_connection])
        raise 'No credentials provided for orchestration API connection!'
      end
      Rails.application.config.sparkle[:orchestration_connection]
    end

    # @return [Fog::Files]
    def bucket
      unless(Rails.application.config.sparkle[:storage_bucket])
        raise 'No storage bucket available'
      end
      Rails.application.config.sparkle[:storage_bucket]
    end

  end
end
