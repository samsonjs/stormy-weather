$(function() {

  $('#password').focus()

  $('#reset-password-form').submit(function() {
    var passwordField = $('#password')
      , confirmationField = $('#password-confirmation')
      , valid = true
      , focused = false

    if ($.trim(passwordField.val()).length === 0) {
      passwordField.addClass('error').val('').focus()
      focused = true
      valid = false
    }
    else {
      passwordField.removeClass('error')
    }

    if (passwordField.val() !== confirmationField.val()) {
      confirmationField.addClass('error').val('')
      valid = false
      if (!focused) {
        confirmationField.focus()
        focused = true
      }
    }
    else {
      confirmationField.removeClass('error')
    }

    if (valid) {
      $('#reset-password-button').hide()
      $('#reset-password-spinner').show()
    }

    return valid
  })

})
