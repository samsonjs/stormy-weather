$(function() {

  $('#change-password-link').click(function() {
    $(this).hide()
    $('#change-password').show()
    $('#password-changed').hide()
    $('#old-password').focus()
    return false
  })

  $('#change-password-button').click(function() {
    changePassword()
    return false
  })

  $('#send-email-verification').click(function() {
    $('#sending-email-verification').show()
    $(this).hide()
    var self = this
    $.post('/account/send-email-verification', function(data) {
      if (data.status === 'ok') {
        $(self)
          .after('Sent! Follow the link in your email to complete the verification.')
          .remove()
      }
      else {
        alert('Failed to send verification email. Try again later.')
      }
    }).error(function() {
      alert('Failed to send verification email. Try again later.')
    }).complete(function() {
      $('#sending-email-verification').hide()
      $(self).show()
    })
    return false
  })

})

function changePassword() {
  var oldPassword = $('#old-password').val()
    , newPassword = $('#new-password').val()
    , confirmation = $('#password-confirmation').val()
  if ($.trim(oldPassword) && $.trim(newPassword) && newPassword === confirmation) {
    $('#change-password-form input[type="password"]').removeClass('error')
    $('#change-password-form input[type="submit"]').hide()
    $('#change-password-form .spinner').show()
    $.post('/account/password', $('#change-password-form').serialize(), function(data) {
      if (data.status === 'ok') {
        $('input[type="password"]').val('')
        $('#change-password').hide()
        $('#change-password-link').show()
        $('#password-changed').show()
      }
      // incorrect old password
      else if (data.reason === 'incorrect') {
        $('#old-password')
          .val('')
          .addClass('error')
          .focus()
      }
      // invalid new password
      else {
        $('#new-password')
          .val('')
          .addClass('error')
          .focus()
        $('#password-confirmation')
          .val('')
          .addClass('error')
      }
    }).error(function(x) {
      alert('Failed to change password. Try again later.')
    }).complete(function() {
      $('#change-password-form input[type="submit"]').show()
      $('#change-password-form .spinner').hide()
    })
  }
  else {
    if ($.trim(newPassword)) {
      $('#password-confirmation')
        .val('')
        .addClass('error')
        .focus()
    }
    else {
      $('input[type="password"]').val('').addClass('error')
      $('#old-password').focus()
    }
  }
}
