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
        SlackStrava.message('Team successfully registered!<br><br>Invite <b>@slava</b> to a channel.');
      },
      error: SlackStrava.error
    });
  }
});
