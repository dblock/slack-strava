$(document).ready(function() {
  // Slack OAuth
  var code = $.url('?code')
  if (code) {
    SlackStrava.message('Working, please wait ...');
    $('#register').hide();
    $.ajax({
      type: "POST",
      url: "/api/teams",
      data: {
        code: code
      },
      success: function(data) {
        SlackStrava.message('Team successfully registered!<br><br>DM <b>@strava</b> or create a <b>#channel</b> and invite <b>@strava</b> to it.');
      },
      error: SlackStrava.error
    });
  }
});
