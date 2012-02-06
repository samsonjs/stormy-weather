$(function() {

  $('#contact-form').submit(function() {
    var valid = true
      , focused = false
      , messageField = $('#message')
      , emailField = $('#email')

    if ($.trim(messageField.val()) === '') {
      valid = false
      messageField.addClass('error')
      if (!focused) {
        focused = true
        messageField.focus().select()
      }
    }
    else {
      messageField.removeClass('error')
    }

    if (!window.SI.EmailIsValid(emailField.val())) {
      valid = false
      emailField.addClass('error')
      if (!focused) {
        focused = true
        emailField.focus().select()
      }
    }
    else {
      emailField.removeClass('error')
    }

    if (valid) {
      $('input[type="submit"]').hide()
      $('#contact-spinner').show()
    }

    return valid
  })

})
