$(function() {

  initTmpl()

  $('#name').blur(function() {
    var name = $.trim($(this).val())
    if (name === this.placeholder) name = ''
    $('.save-button').val('Save ' + (name || 'This Project'))
  })

  $('form#project').submit(validateProject)

  initLightBox()

  $('#photos').dragsort({
    dragSelector: 'li.photo'
  , itemSelector: 'li.photo'
  , dragEnd: updatePhotoOrder
  , placeHolderTemplate: '<li class="placeholder"><div></div></li>'
  , itemClicked: function(item) { $('a.thumbnail', item).click() }
  })

  var $photos = $('#photos-container')
    , $addPhotoBox = $('#add-photo-box')
    , $photoUploader = $('#photo-uploader')

  // fuck IE
  if ($.browser.msie) {
    $('#ie-photo-uploader').uploadify({
      'uploader'   : '/uploadify/uploadify.swf',
      'script'     : '/uploadify',
      'multi'      : false,
      'buttonImg'  : '/images/add-photo.png',
      'method'     : 'post',
      'cancelImg'  : '/uploadify/cancel.png',
      'auto'       : true,
      'fileExt'    : ['jpg', 'jpeg', 'png'],
      'sizeLimit'  : 10 * 1024 * 1024 * 1024, // 10 MB is way more than enough
      'scriptData' : { id: window.SI.projectId },

      'onComplete': function(_a, _b, _c, text) {
        completePhotoUpload(text)
      },
      'onError': function() {
        completePhotoUpload('fail')
      },
      'onOpen': function() {
        $('#add-photo-spinner').remove()
        $addPhotoBox.addClass('hidden').before('<li id="add-photo-spinner"><img src="/images/spinner.gif"></li>')
      }
    })
  }

  $('.add-photo').click(function() {
    $photoUploader.focus().click()
    return false
  })

  $photoUploader.change(function() {
    $addPhotoBox.addClass('hidden').before('<li id="add-photo-spinner"><img src="/images/spinner.gif"></li>')
    $('#photo-form').submit()
    return false
  })

  $('#upload-target').load(function() {
    completePhotoUpload($(this).contents().text())
  })

  var photoTemplate = window.SI.tmpl($('#photo-template').html())

  function completePhotoUpload(text) {
    $('#add-photo-spinner').remove()
    var photoForm = $('#photo-form').get(0)
    if (photoForm) photoForm.reset()
    try {
      var response = JSON.parse(text)
      if (response.status === 'ok') {
        $addPhotoBox.before(photoTemplate(response.data.photo))
        initLightBox()
        if (response.data.n >= 10) {
          $addPhotoBox.addClass('hidden')
        }
        else {
          $addPhotoBox.removeClass('hidden')
        }
      }
      else {
        $addPhotoBox.removeClass('hidden')
        alert('Failed to add photo. Try again later.')
      }
    }
    catch (e) {
      $addPhotoBox.removeClass('hidden')
      alert('Failed to add photo. Try again later.')
    }
  }


  var removeCount = 0
  $('.remove-photo').live('click', function() {
    var id = this.id
      , photoId = id.replace(/^remove-photo-/, '')
      , data = { id: window.SI.projectId, photo_id: photoId }
      , spinnerId = 'remove-photo-spinner-' + photoId
      , $this = $(this)
    $this.hide().after('<img id="' + spinnerId + '" src="/images/spinner.gif">')
    removeCount += 1
    $.post('/project/remove-photo', data, function(response) {
      removeCount -= 1
      if (response.status === 'ok' && removeCount === 0) {
        $addPhotoBox.removeClass('hidden')
        $('li.photo').remove()

        $.each(response.data.photos, function(i, photo) {
          $addPhotoBox.before(photoTemplate(photo))
        })

        initLightBox()
      }
      else {
        if (removeCount === 0) {
          $('#' + spinnerId).remove()
          $this.show()
          alert('Failed to remove photo. Try again later.')
        }
      }
    }).error(function() {
      removeCount -= 1
      if (removeCount === 0) {
        $('#' + spinnerId).remove()
        $this.show()
        alert('Failed to remove photo. Try again later.')
      }
    })
    return false
  })

})

function initLightBox() {
  $('#photos a.thumbnail').lightBox()
  $('#photos a.thumbnail').live('click', function(){ console.dir(this) })
}

// Simple JavaScript Templating
// John Resig - http://ejohn.org/ - MIT Licensed
// http://ejohn.org/blog/javascript-micro-templating/
function initTmpl() {
  var cache = {}

  window.SI = window.SI || {}
  window.SI.tmpl = function tmpl(str, data) {
    // Figure out if we're getting a template, or if we need to
    // load the template - and be sure to cache the result.
    var fn = !/\W/.test(str) ?
      cache[str] = cache[str] ||
        tmpl($('#' + str).html()) :

      // Generate a reusable function that will serve as a template
      // generator (and which will be cached).
      new Function("obj",
        "var p=[],print=function(){p.push.apply(p,arguments)};" +

        // Introduce the data as local variables using with(){}
        "with(obj){p.push('" +

        // Convert the template into pure JavaScript
        str
          .replace(/[\r\t\n]/g, " ")
          .split("<%").join("\t")
          .replace(/((^|%>)[^\t]*)'/g, "$1\r")
          .replace(/\t=(.*?)%>/g, "',$1,'")
          .split("\t").join("');")
          .split("%>").join("p.push('")
          .split("\r").join("\\'")
      + "')}return p.join('')")

    // Provide some basic currying to the user
    return data ? fn( data ) : fn
  }
}

function updatePhotoOrder() {
  initLightBox()
  var ids = []
  $('#photos li.photo').each(function() {
    ids.push(this.id.replace('photo-', ''))
  })
  var data = { id: window.SI.projectId, order: ids }
  $.post('/project/photo-order', data, function(response) {
    // noop
  }).error(function() {
    alert('Failed to reorder photos. Try again later.')
  })
}

function validateProject() {
  var valid = true
    , nameField = $('#name')

  if ($.trim(nameField.val()).length === 0) {
    valid = false
    nameField.addClass('error').focus().select()
  }
  else {
    nameField.removeClass('error')
  }

  if (valid) {
    $('.save-button').hide()
    $('.save-button-spinner').show()
  }

  return valid
}
