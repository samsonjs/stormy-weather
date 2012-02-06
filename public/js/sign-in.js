$(function() {

  $('input[name="email"]').focus()

  $('#forgot-password-link').click(function() {
    window.location.href = '/forgot-password/' + $('#email').val()
    return false
  })

  $('#sign-in-form').submit(function() {
    var emailField = $('input[name="email"]')
      , passwordField = $('input[name="password"]')
      , valid = true
      , focused = false

    if ($.trim(emailField.val()).length === 0) {
      emailField.addClass('error').val('').focus()
      focused = true
      valid = false
    }
    if ($.trim(passwordField.val()).length === 0) {
      passwordField.addClass('error').val('')
      valid = false
      if (!focused) {
        passwordField.focus()
        focused = true
      }
    }

    if (valid) {
      emailField.removeClass('error')
      passwordField.removeClass('error')
      $('#sign-in-button').hide()
      $('#sign-in-spinner').show()
    }

    return valid
  })

})
