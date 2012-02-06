$(function() {

  if (window.SI.errors) {
    for (var name in window.SI.errors) {
      $('input[name="' + name + '"]').addClass('error')
    }
  }

  var Validators = {
    email: window.SI.EmailIsValid
  , password_confirmation: function(v) { return v === $('input[name="password"]').val() }
  }

  // TODO validate password confirmation on each keypress

  $('#sign-up-form').submit(function() {
    var valid = true
      , focused = false

    // Presence check
    $.each(['first_name', 'last_name', 'email', 'password', 'password_confirmation'], function(i, name) {
      var field = $('input[name="' + name + '"]')
        , value = $.trim(field.val())
        , validator = Validators[name]
      if (value.length === 0 || (validator && !validator(value))) {
        field.addClass('error')
        if (!focused) {
          focused = true
          field.focus().select()
        }
        valid = false
      }
      else {
        field.removeClass('error')
      }
    })

    if (!$('input[name="terms"]').attr('checked')) {
      valid = false
      $('#terms-cell').addClass('error')
    }
    else {
      $('#terms-cell').removeClass('error')
    }

    if (valid) {
      $('#sign-up-button').hide()
      $('#sign-up-spinner').show()
    }

    return valid
  })

  $('#sign-in-button').click(function() {
    $(this).hide()
    $('#sign-in-spinner').show()
  })

})
