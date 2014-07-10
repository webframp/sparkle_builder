var sparkle_builder = {
  build: {
    parameters: {},
    resources: {},
    multiselect: {},
    validation: {},
    create: {}
  },
  configuration: {}
};

/**
 * Access configuration
 *
 * @param key [String] configuration name
 * @param default_value [Object] default value if no value found
 * @return [Object]
 **/
sparkle_builder.config = function(key, default_value){
  if(sparkle_builder.configuration[key] == undefined){
    return default_value;
  } else {
    return window_rails.configuration[key];
  }
}

/**
 * Add parameter from UI form
 **/
sparkle_builder.build.parameters.add = function(){
  sparkle_builder.build.resources.disable();
  param = $('#sprkl-parameter').val();
  if(param.length > 0){
    sparkle_builder.build.parameters.set(param, true);
  }
  $('#sprkl-parameter').val('');
  sparkle_builder.build.parameters.display();
  sparkle_builder.build.resources.enable();
}

/**
 * Remove parameter from UI form
 *
 * @param name [String] parameter name
 **/
sparkle_builder.build.parameters.remove = function(name){
  sparkle_builder.build.resources.disable();
  sparkle_builder.build.parameters.delete(name);
  sparkle_builder.build.parameters.display();
  sparkle_builder.build.resource.enable();
}

/**
 * Display parameters on the UI form
 **/
sparkle_builder.build.parameters.display = function(){
  if(sparkle_builder.build.parameters.get()){
    params = Object.keys(
      sparkle_builder.build.parameters.get()
    ).sort();
    $('#sprkl-parameter-display').html('');
    content = '<table class="table table-bordered table-striped">';
    $.each(params, function(idx, value){
      content += '<tr><td>';
      content += value;
      content += '<a href="#" onclick="delete_parameter(';
      content += "'" + value + "'";
      content += '); return false;" style="color: black;" class="pull-right glyphicon glyphicon-remove-circle">';
      content += '</a></td></tr>';
    });
    content += '</table>';
    $('#sprkl-parameter-display').html(content);
  }
}

/**
 * Enable resource list on the form UI. Build template JSON
 * on enable.
 *
 * @param disable_json_build [true,false] do not build JSON template
 **/
sparkle_builder.build.resources.enable = function(disable_json_build){
  $('#sprkl-parameter-form *').removeAttr('disabled');
  $('#sprkl-resources').removeAttr('disabled');
  $('#sprkl-resources').multiSelect('refresh');
  if(!disable_json_build){
    sparkle_builder.build.load_template_json();
  }
}

/**
 * Disable resource list on the form UI
 **/
sparkle_builder.build.resources.disable = function(){
  $('#sprkl-parameter-form *').attr('disabled', 'disabled');
  $('#sprkl-resources').attr('disabled', 'disabled');
  $('#sprkl-resources').multiSelect('refresh');
}

/**
 * Update the resources list entries on the form UI
 *
 * @param old_resource [String]
 * @param new_resource [String]
 * @param new_resource_name [String]
 **/
sparkle_builder.build.resources.update_display = function(old_resource, new_resource, new_resource_name){
  $('#sprkl-resources').multiSelect('deselect', old_resource);
  $('#sprkl-resources').multiSelect('addOption', {value: new_resource, text: new_resource_name});
  $('#sprkl-resources').multiSelect('select', new_resource);
}

/**
 * Add a new resource to the build
 *
 * @param resource [String] type of resource
 **/
sparkle_builder.build.resources.add = function(resource){
  data = $('#sprkl-property-composer').serializeObject();
  if(!resource){
    resource = data['resource_type'];
  }
  keys = Object.keys(sparkle_builder.build.resources.get());
  if(keys.length > 0){
    idx = Math.max.apply(Math, $.map(keys, function(elm, i){
      parts = elm.split('_');
      resource_name = parts.slice(0, parts.length - 1).join('_');
      if(resource_name == resource){
        return Number(parts[parts.length - 1]);
      }
    }));
    idx = idx < 0 ? 0 : idx;
  }
  else {
    idx = 0;
  }
  if(data['resource_name']){
    key = data['resource_name'];
  }
  else {
    key = resource + '_' + (idx + 1);
    key = key.replace(/::/g, '');
  }
  if(data['resource_type'].substr(0, 8) == 'dynamics'){
    key = key + data['resource_type'].split('/')[1].replace('.rb', '');
  }
  sparkle_builder.build.resources.enable(true);
  sparkle_builder.build.resources.update_display(
    resource, key, key + " [" + resource.replace('AWS::', '') + "]"
  );
  sparkle_builder.build.reset_sparkle_box();
  sparkle_builder.build.resources.set(key, data);
  sparkle_builder.build.load_template_json();
  sparkle_ui.display.highlight('resource-body');
}

/**
 * Cancel addition of resource on form UI
 *
 * @param resource [String] resource to be canceled
 **/
sparkle_builder.build.resources.cancel = function(resource){
  data = $('form#sprkl-property-composer').serializeObject();
  if(!resource){
    resource = data['resource_name'] || data['resource_type'];
  }
  sparkle_builder.build.resources.enable();
  is_edit = data['resource_name'];
  if(is_edit){
    $('#sprkl-resources').multiSelect('select', resource);
  }
  else {
    $('#sprkl-resources').multiSelect('deselect', resource);
  }
  sparkle_builder.build.reset_sparkle_box();
  sparkle_ui.display.highlight('resource-body', 'danger');
}

/**
 * Remove resource from form UI
 *
 * @param resource [String]
 * @return [true,false]
 **/
sparkle_builder.build.resources.remove_from_ui_deprecated = function(resource){
  if(sparkle_builder.build.resources.exists(resource)){
    $('#sprkl-resources').multiSelect('select', resource);
    sparkle_builder.build.resources.configure(resource, true);
    return true;
  } else {
    return false;
  }
}

/**
 * Delete resource from internal data and form UI
 *
 * @param resource [String]
 * @return [true,false]
 **/
sparkle_builder.build.resources.remove = function(resource){
  if(!resource){
    resource = $('form#sprkl-property-composer').serializeObject()['resource_name'];
  }
  if(sparkle_builder.build.resources.delete(resource)){
    sparkle_builder.build.resources.enable();
    $('#sprkl-resources option[value="' + resource + '"]').remove();
    $('#sprkl-resources').multiSelect('refresh');
    sparkle_ui.display.highlight('resource-body');
    sparkle_builder.build.reset_sparkle_box();
    return true;
  } else {
    return false;
  }
}

/**
 * Update resource display and store data
 *
 * @param resource [String]
 * @return [true]
 **/
sparkle_builder.build.resources.update = function(resource){
  data = $('#sprkl-property-composer').serializeObject();
  sparkle_builder.build.resources.set(resource, data);
  sparkle_ui.display.highlight('resource-body', 'success');
  sparkle_builder.build.resources.enable();
  sparkle_builder.build.reset_sparkle_box();
  true
}

/**
 * Callback for deselect event on resources multiselect element
 *
 * @param value [Array<String>] items deselected
 **/
sparkle_builder.build.multiselect.resources_deselect = function(value){
  sparkle_builder.build.resources.configure(value, true);
}

/**
 * Configure the resource
 *
 * @param value [Array<String>]
 * @param deselected [true,false]
 **/
sparkle_builder.build.resources.configure = function(value, deselected){
  resource = value[0];
  parts = resource.split('/')
  configurable_resource = parts[0] != 'components';
  new_addition = !deselected && (parts.length > 1 || resource.split('::').length > 1)
  if(!configurable_resource){
    if(sparkle_builder.build.resources.exists(resource)){
      sparkle_builder.build.resources.delete(resource);
    } else {
      sparkle_builder.build.resources.set(
        resource, {
          resource_type: 'component'
        }
      );
    }
    sparkle_ui.display.highlight('resource-body');
    sparkle_builder.build.resources.enable();
  }
  else{
    if(new_addition || (deselected && sparkle_builder.build.resources.exists(resource))){
      $('#sprkl-property-builder').html('<div class="alert alert-warning"><strong>Loading...</strong></div>');
      $('#sprkl-resources').attr('disabled', 'disabled');
      $('#sprkl-resources').multiSelect('refresh');
      args = {resource: resource};
      if(!new_addition){
        args['configured'] = sparkle_builder.build.resources.get(resource);
        args['exists'] = true;
      }
      $.get(sparkle_builder.build.url_for('sprkl-property-populator'), args);
    }
  }
}

/**
 * Close the validation display modal
 **/
sparkle_builder.build.validation.close_display = function(){
  $('#validator-modal').modal('hide');
  sparkle_builder.build.resources.enable_resources();
}

/**
 * Make the validation progress bar look active
 **/
sparkle_builder.build.validation.look_busy = function(){
  $('body').data('omg-look-busy', 10);
  setTimeout(function(){
    elm = $('#validator-modal .progress-bar-info');
    if(elm.length > 0){
      completed = Number(elm.attr('aria-valuenow'));
      busy_by = $('body').data('omg-look-busy');
      addition = (100 - completed) / busy_by;
      if(busy_by > 2){
        $('body').data('omg-look-busy', busy_by - 1);
      }
      completed_now = completed + addition;
      elm.attr('aria-valuenow', completed_now);
      elm.attr('style', 'width: ' + completed_now + '%');
      look_busy();
    }
  }, 2500);
}

/**
 * Validate the current template
 **/
sparkle_builder.build.validation.validate_template = function(){
  sparkle_builder.build.resources.disable();
  $('#validator-modal').html($('body').data('validator-modal-body'));
  $('#validator-modal').modal('show');
  sparkle_builder.build.validation.look_busy();
  $.post(sparkle_builder.build.url_for('sprkl-do-validate'), sparkle_builder.build.build_params());
}

/**
 * Open template save modal
 **/
sparkle_builder.build.create.open_display = function(){
  sparkle_builder.build.resources.disable();
  $('#save-modal').modal('show');
}

/**
 * Save the template
 **/
sparkle_builder.build.create.save = function(){
  params = sparkle_builder.build.build_params();
  params['template_name'] = $('#template-name').val();
  $.post(sparkle_builder.build.url_for('sprkl-do-create'), params);
}

/**
 * Request update of the template on page
 **/
sparkle_builder.build.update_template = function(){
  params = sparkle_builder.build.build_params();
  $.ajax({
    url: sparkle_builder.url_for('sprkl-do-update'),
    type: 'PUT',
    contentType: 'application/json',
    data: JSON.stringify(params)
  });
}

/**
 * Fetch URL from DOM element (data-url value)
 *
 * @param dom_id [String]
 * @return [String] URL
 **/
sparkle_builder.build.url_for = function(dom_id){
  return $('#' + dom_id).attr('data-url');
}

/**
 * Return all stack build data parameters
 *
 * @return [Hash]
 **/
sparkle_builder.build.build_params = function(){
  return $('body').data('sparkles');
}

/**
 * Return value for resource or all resources
 *
 * @param resource_name [String]
 * @return [Object, Array<Object>]
 **/
sparkle_builder.build.resources.get = function(resource_name){
  if(resource_name){
    return $('body').data('sparkles')['build'][resource_name];
  }
  else {
    return $('body').data('sparkles')['build'];
  }
}

/**
 * Set value for resource
 *
 * @param resource_name [String]
 * @param resource_data [Hash]
 **/
sparkle_builder.build.resources.set = function(resource_name, resource_value){
  $('body').data('sparkles')['build'][resource_name] = resource_value;
}

/**
 * Check if resource exists
 *
 * @param resource_name [String]
 * @return [true,false]
 **/
sparkle_builder.build.resources.exists = function(resource_name){
  return !!sparkle_builder.build.resources.get(resource_name);
}

/**
 * Delete resource
 *
 * @param resource_name [String]
 * @return [true, false]
 **/
sparkle_builder.build.resources.delete = function(resource_name){
  if(sparkle_builder.build.resources.exists(resource_name)){
    delete $('body').data('sparkles')['build'][resource_name];
    return true;
  }
  else {
    return false;
  }
}

/**
 * Get value for parameter or all parameters
 *
 * @param parameter_name [String]
 * @return [Object, Array<Object>]
 **/
sparkle_builder.build.parameters.get = function(parameter_name){
  if(parameter_name){
    return $('body').data('sparkles')['parameters'][parameter_name];
  }
  else {
    return $('body').data('sparkles')['parameters'];
  }
}

/**
 * Set value for parameter
 *
 * @param parameter_name [String]
 * @param data [Hash]
 **/
sparkle_builder.build.parameters.set = function(paramter_name, data){
  $('body').data('sparkles')['parameters'][parameter_name] = data;
}

/**
 * Remove parameter
 *
 * @param parameter_name [String]
 * @return [true,false]
 **/
sparkle_builder.build.parameters.delete(parameter_name){
  if(sparkle_builder.build.parameters.exists(parameter_name)){
    delete $('body').data('sparkles')['parameters'][parameter_name]
    return true;
  }
  else {
    return false;
  }
}

/**
 * Check if parameter exists
 *
 * @param parameter_name [String]
 * @return [true,false]
 **/
sparkle_builder.build.parameters.exists = function(parameter_name){
  return !!sparkle_builder.build.parameters.get(parameter_name);
}

/**
 * Reset the resource customization box
 **/
sparkle_builder.build.reset_sparkle_box = function(){
  $('#sprkl-property-builder-title').html('Resource Customization');
  $('#sprkl-property-builder').html('');
}

/**
 * Load the template JSON into the display UI
 **/
sparkle_builder.build.load_template_json = function(){
  $.post(sparkle_builder.url_for('sprkl-build-json'), sparkle_builder.build.build_params());
}

// initialize the builder!
$(document).ready(
  function(){
    // init multi selector
    $('#sprkl-resources').multiSelect({
      afterSelect: sparkle_builder.build.resources.configure,
      afterDeselect: sparkle_builder.build.multiselect.resources_deselect
    });
    // init data store
    $('body').data('sparkles', {build: {}, parameters: {}});
    $('body').data('sparkle-settings', {colors: {}});
    // store modal data
    $('body').data('validator-modal-body', $('#validator-modal').html());
    $('#validator-modal').modal({show: false});
    // hook our custom buttons
    $('body').on('click', 'button.sprkl', function(event){
      window[$(this).attr('sprkl')]();
    });
    // hook the forms for intercept
    $('#builder-interface form').submit(function(event){
      event.preventDefault();
      return false;
    });
    // ensure things are active when validator is dismissed
    $('#validator-modal').on('hidden.bs.modal', function(e){
      sparkle_builder.build.resources.enable();
    });
    // Force CSRF support
    $.ajaxPrefilter(function(opts, orig_opts, xhr){
      xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'));
    });
  }
);
