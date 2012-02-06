$(function() {

  var editableOptions = {
    indicator: '<img src="/images/spinner.gif"> Saving...'
  , submit: 'OK'
  , cancel: 'Cancel'
  , tooltip: 'Click to edit'
  , select: true
  , onblur: 'ignore'
  , placeholder: '(none)'
  }

  $('.editable').editable('/account/update', $.extend({}, editableOptions, {
    onsubmit: function(options, el) {
      var $input = $('input', el)
      var value = $input.val()
      if ($.trim(value)) {
        $input.removeClass('error')
        return true
      }
      else {
        $input.addClass('error')
        return false
      }
    }
  }))

  var updaters = {

    email: updaterForField({
      type: 'email address'
    , name: 'email'
    , validate: window.SI.EmailIsValid
    , failHandlers: {
        taken: function(type, name) {
          $(this).after('<p id="email-taken" class="error">That email address is already taken.</p>')
        }
      }
    })

  }

  $.each(['email'], function(i, id) {
    var $el = $('#' + id)
    $el
      .data('original', $el.text())
      .editable(updaters[id], $.extend({}, editableOptions, {
        oncancel: function(options) {
          $('#' + id + '-taken').remove()
          $('#' + id + '-invalid').remove()
          $('.edit-instructions').show()
        }
      }))
  })

})

function invalidHTMLFor(type, name) {
  return '<p id="' + name + '-invalid" class="error">Invalid ' + type + '.</p>'
}

// options: type, name, validate, [failHandlers]
function updaterForField(options) {
  var name = options.name
    , type = options.type
    , validate = options.validate
    , failHandlers = options.failHandlers || {}

  return function(value, options) {
    $('#' + name + '-taken').remove()
    $('#' + name + '-invalid').remove()

    var $el = $('#' + name)
      , self = this

    value = $.trim(value)

    if (value === $.trim($el.data('original'))) {
      $('.edit-instructions').show()
      return value || '(none)'
    }

    function restoreInput(options) {
      options = options || {}
      self.editing = false
      $(self)
        .html($el.data('original'))
        .trigger('click')
      var input = $('input', self)
      input.val(value)
      if (options.error) {
        input
          .addClass('error')
          .focus()
          .select()
      }
    }

    if (!validate(value)) {
      restoreInput({ error: true })
      $(this).after(invalidHTMLFor(type, name))
    }
    else {
      $('input', this).removeClass('error')
      $(this).html(options.indicator)

      $.post('/account/update.json', { 'id': name, 'value': value }, function(data) {
        if (data.status === 'ok') {
          var previousValue = $.trim($(self).data('original'))
          value = $.trim(value)

          $(self)
            .html(value || '(none)')
            .data('original', value)
          self.editing = false
          $('.edit-instructions').show()

          if (name === 'email') {
            if (previousValue.toLowerCase() !== value.toLowerCase()) {
              $('#email-verified').hide()
              $('#email-verification').show()
            }
          }
        }
        else {
          restoreInput({ error: true })

          // custom handler
          if (data.reason in failHandlers) {
            failHandlers[data.reason].call(self, type, name)
          }

          // default, invalid
          else {
            $(self).after(invalidHTMLFor(type, name))
          }
        }
      }).error(function() {
        restoreInput()
        alert('Failed to update ' + type + '. Try again later.')
      })
    }
    return false
  }
}
