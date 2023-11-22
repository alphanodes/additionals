var oldAdditionalsToggleFilter = window.toggleFilter;

window.toggleFilter = function(field) {
  oldAdditionalsToggleFilter(field);
  return additionals_transform_to_select2(field);
};

/* global availableFilters, additionals_filter_urls, additionals_field_formats, formatNameWithIcon */
function additionals_transform_to_select2(field) {
  var field_format = availableFilters[field]['field_format'];
  var initialized_select2 = $('#tr_' + field + ' .values .select2');
  if (initialized_select2.length == 0 && (typeof additionals_field_formats !== 'undefined') && $.inArray(field_format, additionals_field_formats) >= 0) {
    $('#tr_' + field + ' .toggle-multiselect').hide();
    $('#tr_' + field + ' .values .value').attr('multiple', 'multiple');
    $('#tr_' + field + ' .values .value').select2({
      ajax: {
        url: additionals_filter_urls[field_format],
        dataType: 'json',
        delay: 250,
        data: function(params) {
          return { q: params.term };
        },
        processResults: function(data) {
          return { results: data };
        },
        cache: true
      },
      placeholder: ' ',
      minimumInputLength: 1,
      width: '90%',
      templateResult: formatNameWithIcon
    }).on('select2:open', function() {
      $(this).parent('span').find('.select2-search__field').val(' ').trigger($.Event('input', { which: 13 })).val('');
    });
  }
}

var SELECT2_DELAY = 250;

var select2Filters = {};

/* exported setSelect2Filter */
/* global operatorByType */
/* global buildFilterRow:writable */
function setSelect2Filter(type, options) {
  if (typeof operatorByType === 'undefined') { return; }

  operatorByType[type] = operatorByType[type] || operatorByType['list_optional'];
  select2Filters[type] = options;
}

var oldBuildFilterRow = buildFilterRow;
buildFilterRow = function (field, operator, values) {
  oldBuildFilterRow(field, operator, values);

  var options = select2Options(field);
  if (options) {
    setSelect2FilterValues(field, options, values);
    transformToSelect2(field, options);
  }
};

function select2Options(field) {
  var filter = availableFilters[field];
  var options = select2Filters[filter['type']];

  if (!options && filter['field_format']) {
    options = select2Filters[field];
  }

  return options;
}

function setSelect2FilterValues(field, options, values) {
  var needAddValues = !rowHasSelectTag(field);
  if (needAddValues) { addSelectTag(field); }

  var $select = findSelectTagInRowBy(field);
  if (options['multiple'] !== false) { $select.attr('multiple', true); }

  if (needAddValues) { addOptionTags($select, field, values); }
}

function addSelectTag(field) {
  var fieldId = sanitizeToId(field);
  $('#tr_' + fieldId).find('td.values').append(
    '<span style="display: none;"><select class="value" id="values_'+fieldId+'_1" name="v['+field+'][]"></select></span>'
  );
}

function addOptionTags($select, field, values) {
  var filterValues = availableFilters[field]['values'];

  for (var i = 0; i < filterValues.length; i++) {
    var filterValue = filterValues[i];
    var option = $('<option>');

    if ($.isArray(filterValue)) {
      option.val(filterValue[1]).text(filterValue[0]);
      if ($.inArray(filterValue[1], values) > -1) { option.attr('selected', true); }
    } else {
      option.val(filterValue).text(filterValue);
      if ($.inArray(filterValue, values) > -1) { option.attr('selected', true); }
    }

    $select.append(option);
  }
}

function sanitizeToId(field) { return field.replace('.', '_'); }

function findSelectTagInRowBy(field) {
  return findInRowBy(field, '.values select.value');
}

function rowHasSelectTag(field) {
  return findInRowBy(field, '.values select.value').length > 0;
}

function rowHasSelect2(field) {
  return findInRowBy(field, '.values .select2').length > 0;
}

function findInRowBy(field, selector) {
  return $('#tr_' + sanitizeToId(field) + ' ' + selector);
}

/* exported formatStateWithAvatar */
function formatStateWithAvatar(opt) {
  if (opt.loading) return opt.text;
  return $('<span>' + opt.avatar + '&nbsp;' + opt.text + '</span>');
}

/* exported formatStateWithMultiaddress */
function formatStateWithMultiaddress(opt) {
  if (opt.loading) return opt.text;
  return $('<span class="select2-contact">' + opt.avatar + '<p class="select2-contact__name">' + opt.text + '</p><p class="select2-contact__email">' + opt.email + '</p></span>');
}

/* exported formatSelectionWithEmails */
function formatSelectionWithEmails(opt) {
  var email = $.trim(opt.email).length ? ' <' + opt.email + '>' : '';
  return (opt.text || opt.name || '') + email;
}

function transformToSelect2(field, options) {
  if (rowHasSelect2(field)) { return; }

  findInRowBy(field, '.toggle-multiselect').hide();
  var selectField = findSelectTagInRowBy(field);
  selectField.select2(buildSelect2Options(options));

  var select2Instance = selectField.data('select2');
  select2Instance.on('results:message', function() {
    this.dropdown._resizeDropdown();
    this.dropdown._positionDropdown();
  });
}

/* exported select2Tag */
function select2Tag(id, options) {
  $(function () {
    var selectField = $('select#' + id);
    selectField.select2(buildSelect2Options(options));

    var select2Instance = selectField.data('select2');
    select2Instance.on('results:message', function() {
      this.dropdown._resizeDropdown();
      this.dropdown._positionDropdown();
    });
  });
}

function buildSelect2Options(options) {
  var result = {
    placeholder: options['placeholder'] || '',
    allowClear: !!options['allow_clear'],
    minimumInputLength: options['min_input_length'] || 0,
    templateResult: window[options['format_state']],
    templateSelection: window[options['format_selection']],
    width: options['width'] || '90%'
  };

  addDataSourceOptions(result, options);
  addTagsOptions(result, options);

  return result;
}

function addDataSourceOptions(target, options) {
  if (options['url']) {
    target['ajax'] = {
      url: options['url'],
      dataType: 'json',
      delay: SELECT2_DELAY,
      data: function (params) {
        if (params === undefined) {
          console.log('missing params for ajax call');
          console.log(target);
          console.log(options);
        }
        return { q: params.term };
      },
      processResults: function (data) {
        return { results: data };
      },
      cache: true
    };
  } else {
    target['data'] = options['data'] || [];
  }
}

function addTagsOptions(target, options) {
  if (options['tags']) {
    target['tags'] = true;
    target['tokenSeparators'] = [','];
    target['createTag'] = createTag;
  } else {
    target['tags'] = false;
  }
}

function createTag(params) {
  var term = $.trim(params.term);
  if (term === '' || term.indexOf(',') > -1) {
    return null; // Return null to disable tag creation
  }

  return { id: term, text: term };
}

/* exported fixScopedTags */
function fixScopedTags(e, eventSelect) {
  var values = eventSelect.val();
  var data = eventSelect.select2('data');

  // console.log('fixScopeTags');

  // new added tag
  if (e.params.originalSelect2Event == undefined || data == undefined) { return; }
  var new_tag = e.params.originalSelect2Event.data.id;
  if (! new_tag.includes('::')) { return; }

  // console.log('fixScopeTags - new_tag=' + new_tag);

  var group_name = buildTagGroupName(new_tag);
  var idToRemove = '';

  // search for existing tags with same group name
  var arrayLength = data.length;
  var current_tag;
  for (var i = 0; i < arrayLength; i++) {
    current_tag = data[i].id;
    if (new_tag != current_tag && current_tag.indexOf('::') >= 0 && buildTagGroupName(current_tag) == group_name) {
      idToRemove = current_tag;
      break;
    }
  }

  // leave if no remove id has been found
  if (idToRemove == '') { return; }

  // remove id from existing data
  if (values) {
    var j = values.indexOf(idToRemove);
    if (j >= 0) {
      values.splice(j, 1);
      eventSelect.val(values).trigger('change');
    }
  }
}

/* exported fixScopedTags */
function buildTagGroupName(tag_name) {
  // build labels
  var labels = tag_name.split('::');
  labels = labels.map(function (el) { return el.trim(); });

  // first label is group name
  // remove group value
  labels.pop();
  return labels.join('::');
}
