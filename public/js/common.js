$(function() {

  $('#sign-out-link').click(function() {
    $('#sign-out-form').submit()
    return false
  })

  $('#flash').append('<button id="hide-flash">OK</button>')

  $('#hide-flash').click(function() {
    $(this).fadeOut()
    $('#flash').fadeOut()
  })

  // global Stormy Weather object
  window.SI = window.SI || {}
  window.SI.EmailRegex = /^[^@]+@[^.@]+(\.[^.@]+)+$/
  window.SI.EmailIsValid = function(v) { return window.SI.EmailRegex.test(v) }

  $('input[placeholder], textarea[placeholder]').placeholder()

})
