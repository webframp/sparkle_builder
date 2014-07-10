// parameter helpers

function add_parameter(){
  disable_resources();
  param = $('#sprkl-parameter').val();
  if(param.length > 0){
    parameter_set(param, true);
  }
  $('#sprkl-parameter').val('');
  display_parameters();
  enable_resources();
}

function delete_parameter(name){
  disable_resources();
  parameter_delete(name);
  display_parameters();
  enable_resources();
}

function display_parameters(){
  if(parameter_get()){
    params = Object.keys(parameter_get()).sort();
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

// resource ui helpers
function enable_resources(disable_json_build){
  $('#sprkl-parameter-form *').removeAttr('disabled');
  $('#sprkl-resources').removeAttr('disabled');
  $('#sprkl-resources').multiSelect('refresh');
  if(!disable_json_build){
    build_template_json();
  }
}

function disable_resources(){
  $('#sprkl-parameter-form *').attr('disabled', 'disabled');
  $('#sprkl-resources').attr('disabled', 'disabled');
  $('#sprkl-resources').multiSelect('refresh');
}

function update_resource_display(old_resource, new_resource, new_resource_name){
  $('#sprkl-resources').multiSelect('deselect', old_resource);
  $('#sprkl-resources').multiSelect('addOption', {value: new_resource, text: new_resource_name});
  $('#sprkl-resources').multiSelect('select', new_resource);
}

// resource data helpers
function add_resource(resource){
  data = $('#sprkl-property-composer').serializeObject();
  if(!resource){
    resource = data['resource_type'];
  }
  keys = Object.keys(resource_get());
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
  enable_resources(true);
  update_resource_display(resource, key, key + " [" + resource.replace('AWS::', '') + "]");
  reset_sparkle_box();
  resource_set(key, data);
  build_template_json();
  highlight('resource-body', 1000);
}

function cancel_resource(resource){
  data = $('form#sprkl-property-composer').serializeObject();
  if(!resource){
    resource = data['resource_name'] || data['resource_type'];
  }
  enable_resources();
  is_edit = data['resource_name'];
  if(is_edit){
    $('#sprkl-resources').multiSelect('select', resource);
  }
  else {
    $('#sprkl-resources').multiSelect('deselect', resource);
  }
  reset_sparkle_box();
  highlight('resource-body', {duration: 1000, style: 'remove'});
}

// NOTE: this is for multiselect callback
function remove_resource(resource){
  if(resource_exists(resource)){
    $('#sprkl-resources').multiSelect('select', resource);
    configure_resource(resource, true);
  }
}

function delete_resource(resource){
  if(!resource){
    resource = $('form#sprkl-property-composer').serializeObject()['resource_name'];
  }
  if(resource_delete(resource)){
    enable_resources();
    $('#sprkl-resources option[value="' + resource + '"]').remove();
    $('#sprkl-resources').multiSelect('refresh');
    highlight('resource-body', {duration: 1000, style: 'warn'});
    reset_sparkle_box();
  }
}

function update_resource(resource){
  data = $('#sprkl-property-composer').serializeObject();
  resource_set(resource, data);
  highlight('resource-body', {duration: 1000, style: 'success'});
  enable_resources();
  reset_sparkle_box();
}

function multiselect_deselect_callback(value){
  configure_resource(value, true);
}

function configure_resource(value, deselected){
  resource = value[0];
  parts = resource.split('/')
  configurable_resource = parts[0] != 'components';
  new_addition = !deselected && (parts.length > 1 || resource.split('::').length > 1)
  if(!configurable_resource){
    if(resource_exists(resource)){
      resource_delete(resource);
    }
    else {
      resource_set(resource, {resource_type: 'component'});
    }
    highlight('resource-body', 1000);
    enable_resources();
  }
  else{
    if(new_addition || (deselected && resource_exists(resource))){
      $('#sprkl-property-builder').html('<div class="alert alert-warning"><strong>Loading...</strong></div>');
      $('#sprkl-resources').attr('disabled', 'disabled');
      $('#sprkl-resources').multiSelect('refresh');
      args = {resource: resource};
      if(!new_addition){
        args['configured'] = resource_get(resource);
        args['exists'] = true;
      }
      $.get(url_for('sprkl-property-populator'), args);
    }
  }
}

// validations
function close_validator(){
  $('#validator-modal').modal('hide');
  enable_resources();
}

function validate_template(){
  disable_resources();
  $('#validator-modal').html($('body').data('validator-modal-body'));
  $('#validator-modal').modal('show');
  look_busy();
  $.post(url_for('sprkl-do-validate'), build_params());
}

// creator
function save_template_prompt(){
  disable_resources();
  $('#save-modal').modal('show');
}

function save_template(){
  params = build_params();
  params['template_name'] = $('#template-name').val();
  $.post(url_for('sprkl-do-create'), params);
}

function update_template(){
  params = build_params();
  $.ajax({
    url: url_for('sprkl-do-update'),
    type: 'PUT',
    contentType: 'application/json',
    data: JSON.stringify(params)
  });
}

// helpers
function url_for(dom_id){
  return $('#' + dom_id).attr('data-url');
}

function build_params(){
  return $('body').data('sparkles');
}

// resource data helpers
function resource_get(resource_name){
  if(resource_name){
    return $('body').data('sparkles')['build'][resource_name];
  }
  else {
    return $('body').data('sparkles')['build'];
  }
}

function resource_set(resource_name, resource_value){
  $('body').data('sparkles')['build'][resource_name] = resource_value;
}

function resource_exists(resource_name){
  return !!resource_get(resource_name);
}

function resource_delete(resource_name){
  if(resource_exists(resource_name)){
    delete $('body').data('sparkles')['build'][resource_name];
    return true;
  }
  else {
    return false;
  }
}

// parameter data helpers
function parameter_get(parameter_name){
  if(parameter_name){
    return $('body').data('sparkles')['parameters'][parameter_name];
  }
  else {
    return $('body').data('sparkles')['parameters'];
  }
}

function parameter_set(parameter_name, data){
  $('body').data('sparkles')['parameters'][parameter_name] = data;
}

function parameter_delete(parameter_name){
  if(parameter_exists(parameter_name)){
    delete $('body').data('sparkles')['parameters'][parameter_name]
    return true;
  }
  else {
    return false;
  }
}

function parameter_exists(parameter_name){
  return !!parameter_get(parameter_name);
}

function look_busy(){
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

function reset_sparkle_box(){
  $('#sprkl-property-builder-title').html('Resource Customization');
  $('#sprkl-property-builder').html('');
}

function highlight(dom_id, args){
  color = color_for(args['style']);
  $('#' + dom_id).effect({effect: 'highlight', color: color, duration: args['duration'] || 1000});
}

function build_template_json(){
  $.post(url_for('sprkl-build-json'), build_params());
}

function color_for(style){
  $('body').data('sparkle-settings')['colors'][style] || '#f0f0f0';
}

// initialize the builder!
$(document).ready(
  function(){
    // init multi selector
    $('#sprkl-resources').multiSelect({
      afterSelect: configure_resource,
      afterDeselect: multiselect_deselect_callback
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
      enable_resources();
    });
    // Force CSRF support
    $.ajaxPrefilter(function(opts, orig_opts, xhr){
      xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'));
    });
  }
);
