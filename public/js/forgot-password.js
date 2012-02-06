$(function() {

  $('#email').focus()

  $('#forgot-password-form').submit(function() {
    $('input[type="submit"]', this).hide()
    $('#spinner').show()
  })

})
