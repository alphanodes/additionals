var oldAdditionalsToggleFilter = window.toggleFilter;

window.toggleFilter = function(field) {
  oldAdditionalsToggleFilter(field);
  return additionals_transform_to_select2(field);
};

function filterAdditionalsFormatState (opt) {
  var $opt = $('<span>' + opt.name_with_icon + '</span>');
  return $opt;
}

/* global availableFilters additionals_field_formats additionals_filter_urls:true* */
function additionals_transform_to_select2(field){
  var field_format = availableFilters[field]['field_format'];
  var initialized_select2 = $('#tr_' + field + ' .values .select2');
  if (initialized_select2.size() == 0 && $.inArray(field_format, additionals_field_formats) >= 0) {
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
        processResults: function(data, params) {
          return { results: data };
        },
        cache: true
      },
      placeholder: ' ',
      minimumInputLength: 1,
      width: '60%',
      templateResult: filterAdditionalsFormatState
    }).on('select2:open', function (e) {
      $(this).parent('span').find('.select2-search__field').val(' ').trigger($.Event('input', { which: 13 })).val('');
    });
  }
}
