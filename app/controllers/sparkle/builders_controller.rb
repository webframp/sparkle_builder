class Sparkle::BuildersController < ApplicationController

  include SparkleBuilder::Persistence

  helper :sparkle

  before_filter :sparkle_instance
  before_filter :load_target_urls
  before_filter :load_aws_resources

  def sparkle_instance
    SparkleFormation.new('dummy')
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
        begin
          @items = list_templates.sort_by(&:last_modified).reverse.map do |item|
            {:name => File.basename(item.identity).sub('.json', ''), :modified => item.last_modified}
          end
        rescue => e
          @items = []
          flash[:warn] = e.to_s
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
        @redirect_url = sparkle_builders_path
      end
    end
  end

  def edit
    respond_to do |format|
      format.html do
        @build = fetch_build(params[:id])
        @build['parameters'] = {} unless @build['parameters'].is_a?(Hash)
        @build['build'] = {} unless @build['build'].is_a?(Hash)
        @template_name = @build['template_name'] = params[:id]
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
        flash[:success] = "Edited template [#{template_name}]!"
        @redirect_url = sparkle_builders_path
      end
    end
  end

  def destroy
    respond_to do |format|
      format.html do
        delete_template(params[:id])
        delete_build(params[:id])
        flash[:warn] = "Template [#{params[:id]}] has been deleted!"
        redirect_to sparkle_builders_path
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

  def fetch_resources
    {}.tap do |hash|
      enabled = Rails.application.config.sparkle.fetch(:enabled_resources, %w(components dynamics aws)).map(&:to_sym)
      if(enabled.include?(:aws))
        hash['AWS'] = SfnAws.registry.keys.sort.reverse.map do |key|
          [key.sub('AWS::', ''), key]
        end
      end
      if(SparkleFormation.sparkle_path)
        [:components, :dynamics].each do |key|
          if(enabled.include?(key))
            items = Dir.glob(
              File.join(SparkleFormation.custom_paths["#{key}_directory".to_sym], '*.rb')
            ).sort.reverse.map do |file|
              [File.basename(file).sub('.rb', '').humanize, File.join(key.to_s, File.basename(file))]
            end
            hash[key.to_s.capitalize] = items unless items.empty?
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
      'sprkl-property-populator' => property_populator_sparkle_builders_path,
      'sprkl-do-validate' => validator_sparkle_builders_path,
      'sprkl-do-create' => sparkle_builders_path,
      'sprkl-build-json' => build_json_sparkle_builders_path
    }
    if(params[:id])
      @target_urls['sprkl-do-update'] = sparkle_builder_path(params[:id])
    end
  end

  def construct_properties(resource)
    dyn_name = resource.split('/').last.sub('.rb', '')
    begin
      res = SparkleFormation.dynamic_info(dyn_name)
      (res[:parameters].try(:keys) || []).map(&:to_s)
    rescue KeyError
      SfnAws.registry.fetch(resource, {}).fetch(:properties, [])
    end
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
    all_resources = {}.tap do |a_r|
      (all_resources || {}).each do |r_name, resource|
        updated_resource = {}.tap do |r|
          resource.each do |k,v|
            if(v.to_s.start_with?('{') || v.to_s.start_with?('{'))
              r[k] = JSON.load(v)
            else
              r[k] = v
            end
          end
        end
        a_r[r_name] = updated_resource
      end
    end
    parameters = params[:parameters].is_a?(Hash) ? params[:parameters] : {}
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
            v['resource_type'] = v['resource_type'].gsub('::', '_').underscore
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
      sfn_hash = sfn.dump
      KnifeCloudformation::AwsCommons::Stack.clean_parameters!(sfn_hash)
      sfn_hash
    else
      {}
    end
  end

end
