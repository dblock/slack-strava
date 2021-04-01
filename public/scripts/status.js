
$(document).ready(function() {
  $.ajax({
    type: "GET",
    url: "/api/status",
    success: function(data) {
      if (data.total_distance_in_miles_s && data.connected_users_count > 1) {
        SlackStrava.message("Together, " + data.connected_users_count + " athletes logged " + data.total_distance_in_miles_s + " this month!")
      }
    },
  });
});
