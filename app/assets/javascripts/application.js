// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/sstephenson/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require jquery_ujs
//Turbo links disabled as temp fix of more/less options on signin/signup pages
// require turbolinks
//= require bootstrap-sprockets
//= require myusa
//= require bootstrap-tokenfield
//= require modal-window

$(function() {
  var menuToggle = $('#js-mobile-menu').unbind();
  $('#js-navigation-menu').removeClass('show');

  menuToggle.on('click', function(e) {
    e.preventDefault();
    $('#js-navigation-menu').slideToggle(function(){
      if($('#js-navigation-menu').is(':hidden')) {
        $('#js-navigation-menu').removeAttr('style');
      }
    });
  });

  $("#contact-form").on("ajax:success", function(e, data, status, xhr) {
     // TODO: should disable the submit button?
     $('#contact-alert p.message').text(data.message);

     if (data.success) {
      $('#contact-alert').removeClass('error').addClass('success')
     }

     $('#contact-alert').show();

  }).on("ajax:error", function(e, data, status, xhr) {

    if (data.message) {
      $('#contact-alert p.message').text(data.message);
    }

    $('#contact-alert').show();
  });
});
