class SparkleBuilderController < ApplicationController

  helper :sparkle

  before_filter :load_target_urls
  before_filter :load_aws_resources

  def initialize(*args, &block)
    super
    credentials = Rails.application.config.sparkle.
      try(:[], :storage).
      try(:[], :credentials)
    bucket = Rails.application.config.sparkle.
      try(:[], :storage).
      try(:[], :bucket)
    if(credentials && bucket)
      require 'fog'
      @fog = Fog::Storage.new(credentials)
      @bucket = @fog.directories.get(bucket)
      unless(@bucket)
        @bucket = @fog.directories.create(:identity => bucket)
      end
    else
      Rails.logger.warn 'Builder cannot persist data. The `:bucket` and `:credentials` must be configured!'
    end
    orchestration_credentials = Rails.application.config.sparkle.
      try(:[], :orchestration).
      try(:[], :credentials)
    if(orchestration_credentials)
      require 'fog'
      @api = Fog::Orchestration.new(orchestration_credentials)
    end
  end

  def property_populator
    respond_to do |format|
      format.js do
        if(params[:configured])
          @resource = params[:configured][:resource_type]
          @existing_values = params[:configured]
        else
          @resource = params[:resource]
        end
        @resource_type = params[:configured] ? params[:configured][:resource_type] : params[:resource]
        @properties = construct_properties(@resource)
      end
    end
  end

  def validate
    respond_to do |format|
      format.js do
        begin
          stack = sparkle_api.stacks.new(:template => compile_formation.to_json)
          stack.validate
        rescue => e
          @error = e.message
        end
      end
    end
  end

  def build_json
    respond_to do |format|
      format.js do
        @json = JSON.pretty_generate(JSON.load(compile_formation.to_json))
      end
    end
  end

  def index
    respond_to do |format|
      format.html do
        @items = list_templates.sort_by(&:last_modified).reverse.map do |item|
          {:name => File.basename(item.identity).sub('.json', ''), :modified => item.last_modified}
        end
      end
    end
  end

  def new
    respond_to do |format|
      format.html do
        @template_seeds = fetch_seeds
        @template_resources = fetch_resources
      end
    end
  end

  def create
    respond_to do |format|
      format.js do
        build_data = JSON.dump(:parameters => params[:parameters], :build => params[:build])
        template = JSON.pretty_generate(JSON.load(compile_formation.to_json))
        template_name = params[:template_name].gsub(/[^a-zA-Z0-9\.-_]/, '_').downcase.sub(/_+$/, '')
        save_template(template_name, template)
        save_build(template_name, build_data)
        flash[:success] = "Created new template #{template_name}!"
        @redirect_url = sparkle_builder_index_url
      end
    end
  end

  def edit
    respond_to do |format|
      format.html do
        @build = fetch_build(params[:id])
        @template_name = params[:id]
        @template_seeds = fetch_seeds
        @template_resources = fetch_resources
      end
    end
  end

  def update
    respond_to do |format|
      format.js do
        build_data = JSON.dump(:parameters => params[:parameters], :build => params[:build])
        template = JSON.pretty_generate(JSON.load(compile_formation.to_json))
        template_name = params[:template_name].gsub(/[^a-zA-Z0-9\.-_]/, '_').downcase.sub(/_+$/, '')
        save_template(template_name, template)
        save_build(template_name, build_data)
        flash[:success] = "Edited template #{template_name}!"
        @redirect_url = sparkle_builder_index_url
      end
    end
  end

  def destroy
    respond_to do |format|
      format.html do
        puts '*' * 200
        p delete_template(params[:id])
        p delete_build(params[:id])
        flash[:warn] = "Template [#{params[:id]}] has been deleted!"
        redirect_to sparkle_builder_index_url
      end
    end
  end

  def create_hook
    # provides @stack_name and @json_file
  end

  def update_hook
    # provides @stack_name and @json_file
  end

  def destroy_hook
    # provides @stack_name (prior to resource destruction)
  end

  private

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

  def fetch_resources
    {}.tap do |hash|
      enabled = Rails.application.config.sparkle.fetch(:enabled_resources, %w(components dynamics aws)).map(&:to_sym)
      if(enabled.include?(:aws))
        hash['AWS'] = SfnAws.registry.keys.sort.map do |key|
          [key.sub('AWS::', ''), key]
        end
      end
      if(SparkleFormation.sparkle_path)
        [:components, :dynamics].each do |key|
          if(enabled.include?(key))
            hash[key.to_s.capitalize] = Dir.glob(
              File.join(SparkleFormation.custom_paths["#{key}_directory".to_sym], '*.rb')
            ).map do |file|
              [File.basename(file).sub('.rb', '').humanize, File.join(key.to_s, File.basename(file))]
            end
          end
        end
      end
    end
  end

  SEED_IGNORE_DIRECTORIES = ['dynamics', 'components']

  def fetch_seeds
    if(SparkleFormation.sparkle_path)
      {}.tap do |hash|
        Dir.glob(File.join(SparkleFormation.sparkle_path, '*')).sort.each do |entry|
          next if SEED_IGNORE_DIRECTORIES.include?(File.basename(entry))
          path = entry.sub(SparkleFormation.sparkle_path, '').sub(/^\//, '')
          if(File.file?(entry) && entry.end_with?('.rb'))
            hash['Base'] ||= []
            hash['Base'] << [path.sub('.rb', '').humanize, path]
          elsif(File.directory?(entry))
            key = File.basename(path).tr('-_', ' ').humanize
            hash[key] ||= []
            Dir.glob(File.join(entry, '**', '*.rb')).sort.each do |entry|
              path = entry.sub(SparkleFormation.sparkle_path, '').sub(/^\//, '')
              readable_entry = path.sub('.rb', '').split('/')
              readable_entry.shift
              readable_entry = readable_entry.map{|i|i.tr('-_', ' ').humanize}.join(' / ')
              hash[key] << [readable_entry, path]
            end
          else
            Rails.logger.error "Unknown type discovered. Unable to process. Path: #{entry}"
          end
        end
      end
    else
      {}
    end
  end

  def load_target_urls
    @target_urls = {
      'sprkl-property-populator' => property_populator_sparkle_builder_index_url,
      'sprkl-do-validate' => validator_sparkle_builder_index_url,
      'sprkl-do-create' => sparkle_builder_index_url,
      'sprkl-build-json' => build_json_sparkle_builder_index_url
    }
    if(params[:id])
      @target_urls['sprkl-do-update'] = sparkle_builder_url(params[:id])
    end
  end

  def construct_properties(resource)
    SfnAws.registry.fetch(resource, {}).fetch(:properties, [])
  end

  def load_aws_resources
    enabled = Rails.application.config.sparkle.fetch(:enabled_resources, [:aws])
    if(enabled.include?(:aws))
      if(!defined?(SfnAws) || SfnAws.registry.empty?)
        require 'sparkle_formation/aws'
        SfnAws.load!
      end
    end
  end

  def compile_formation
    all_resources = params[:build]
    parameters = params[:parameters]
    if(all_resources || parameters)
      all_resources ||= {}
      parameters ||= {}
      components = all_resources.find_all{|k,v|v['resource_type'] == 'component'}.map do |c|
        File.basename(c.first).sub('.rb', '').to_sym
      end
      dynamics = Hash[
        all_resources.find_all do |k,v|
          v['resource_type'] != 'component'
        end.map do |k,v|
          v['resource_type'] = File.basename(v['resource_type']).sub('.rb', '')
          if(v['resource_type'].include?('::'))
            v['resource_type'] = v['resource_type'].downcase.gsub('::', '_')
          end
          v['resource_type'] = v['resource_type'].to_sym
          [k, v]
        end
      ]
      sfn = SparkleFormation.new('generated')
      unless(components.empty?)
        sfn.load(*components)
      end
      SfnCache[:dynamics] = dynamics
      SfnCache[:parameters] = parameters
      sfn.overrides do
        ::SfnCache[:parameters].each do |_parameter_name, _parameter_options|
          parameters(_parameter_name) do
            type 'String'
          end
        end
        ::SfnCache[:dynamics].each do |_dyn_resource_name, _dyn_properties|
          _dyn_properties.delete_if{|k,v| v.blank?}
          dynamic!(
            _dyn_properties.delete('resource_type'),
            _dyn_properties.delete('resource_name'),
            _dyn_properties
          )
        end
      end
      sfn.compile._dump
    else
      {}
    end
  end

  def sparkle_api
    unless(@api)
      raise 'No credentials provided for orchestration API connection!'
    end
    @api
  end

  def bucket
    unless(@bucket)
      raise 'No storage bucket available'
    end
    @bucket
  end

end
