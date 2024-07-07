### Changelog

* 2024/07/07: Fixed duplicate activities from concurrent updates - [@dblock](https://github.com/dblock).
* 2024/02/17: Added `leaderboard` - [@dblock](https://github.com/dblock).
* 2024/01/07: Added Title, Description, Url, User, Athlete and Date field options - [@dblock](https://github.com/dblock).
* 2023/01/21: Upgraded to Ruby 2.7.7 - [@dblock](https://github.com/dblock).
* 2022/07/16: Fixed [#112](https://github.com/dblock/slack-strava/issues/112), handle archived channels - [@dblock](https://github.com/dblock).
* 2022/07/16: [#137](https://github.com/dblock/slack-strava/issues/137), Added `set units imperial` and `set units metric` - [@dblock](https://github.com/dblock).
* 2022/07/16: Fixed [#136](https://github.com/dblock/slack-strava/issues/136), Mongo::Error::OperationFailure: [11000]: E11000 duplicate key error - [@dblock](https://github.com/dblock).
* 2022/06/22: Fixed [#133](https://github.com/dblock/slack-strava/issues/133), improve fetching channels list - [@dblock](https://github.com/dblock).
* 2021/06/24: Do not brag activities for the first time on updates - [@dblock](https://github.com/dblock).
* 2021/06/24: Fixed club subscriptions on multiple channels - [@dblock](https://github.com/dblock).
* 2021/04/01: Do not store activities for more than 30 days - [@dblock](https://github.com/dblock).
* 2021/01/08: Mark unfurled activities bragged, and do not reset `activities_at` to the past - [@dblock](https://github.com/dblock).
* 2021/01/03: Added support for posting into private channels - [@dblock](https://github.com/dblock).
* 2020/11/08: Flush club activities out to prevent old activities on a new connection - [@dblock](https://github.com/dblock).
* 2020/07/13: Don't post activities for teams with expired subscriptions - [@dblock](https://github.com/dblock).
* 2020/07/09: Swapped Puma for Unicorn and fixed map posting - [@dblock](https://github.com/dblock).
* 2020/07/08: Improve performance of map database lookups - [@dblock](https://github.com/dblock).
* 2020/06/26: Brag or rebrag the activity being updated when pushed from Strava - [@dblock](https://github.com/dblock).
* 2020/06/26: Repost activities that flip privacy settings - [@dblock](https://github.com/dblock).
* 2020/06/25: Toggle whether to sync followers only activities - [@dblock](https://github.com/dblock).
* 2020/06/05: Added setting units to `both` - [@dblock](https://github.com/dblock).
* 2020/05/05: Do not post private activities coming from club feeds when user is also connected - [@dblock](https://github.com/dblock).
* 2020/05/17: Added current weather field - [@dblock](https://github.com/dblock).
* 2020/05/07: Do not post activities for users deactivated in Slack - [@dblock](https://github.com/dblock).
* 2020/04/19: Inform admins and users on restricted channel errors - [@dblock](https://github.com/dblock).
* 2020/04/18: Fixed missing club activities - [@dblock](https://github.com/dblock).
* 2020/04/16: Help users through authorization problems - [@dblock](https://github.com/dblock).
* 2020/04/02: Added team `stats` that returns stats in channel - [@dblock](https://github.com/dblock).
* 2020/03/29: Added Default fields setting - [@dblock](https://github.com/dblock).
* 2020/03/29: Prevent non-admins from changing global team settings - [@dblock](https://github.com/dblock).
* 2020/03/29: Added Max Speed, Elevation, Heart Rate, Max Heart Rate, PR Count and Calories - [@dblock](https://github.com/dblock).
* 2020/03/28: Sync Strava events in near-real-time - [@dblock](https://github.com/dblock).
* 2019/03/22: Added unsubscribe - [@dblock](https://github.com/dblock).
* 2019/03/11: Don't sync old activities when reconnecting or toggling sync - [@dblock](https://github.com/dblock).
* 2019/01/18: Unfurl Strava URLs - [@dblock](https://github.com/dblock).
* 2019/01/05: Added `/slava connect` and `/slava disconnect` - [@dblock](https://github.com/dblock).
* 2019/01/05: Added `set sync` to enable/disable sync - [@dblock](https://github.com/dblock).
* 2018/11/27: Do not duplicate notifications from users and clubs - [@dblock](https://github.com/dblock).
* 2018/12/08: Update activities in Slack during the next 24 hours - [@dblock](https://github.com/dblock).
* 2018/10/08: Announce when someone connects to Strava - [@dblock](https://github.com/dblock).
* 2018/10/08: Only send activities since user joined a channel - [@dblock](https://github.com/dblock).
* 2018/06/05: Added `set fields` to choose which fields to display - [@dblock](https://github.com/dblock).
* 2018/06/05: Display both speed and pace - [@dblock](https://github.com/dblock).
* 2018/05/28: Update activity labels according to the strava API - [@gmiossec](https://github.com/gmiossec).
* 2018/05/28: Ride activities pace is displayed in km/h if units is km - [@gmiossec](https://github.com/gmiossec).
* 2018/05/24: Swim activities are displayed in meters if units is km - [@gmiossec](https://github.com/gmiossec).
* 2018/05/12: Fixed [#37](https://github.com/dblock/slack-strava/issues/037), don't list clubs from /slava clubs unless bot is a member of the channel - [@dblock](https://github.com/dblock).
* 2018/05/11: List club channels and provide instructions for connecting clubs in /slava clubs - [@dblock](https://github.com/dblock).
* 2018/05/10: Fixed trying and failing to resend club activities if a bot was kicked out of a channel - [@dblock](https://github.com/dblock).
* 2018/05/10: Fixed [#36](https://github.com/dblock/slack-strava/issues/036), a user who didn't connect right away gets all their old activities synced up - [@dblock](https://github.com/dblock).
* 2018/05/07: Don't sync private activities - [@dblock](https://github.com/dblock).
* 2018/05/01: Lowered bot price to $9.99/yr - [@dblock](https://github.com/dblock).
* 2018/04/27: Added support for clubs with `/slava clubs` - [@dblock](https://github.com/dblock).
* 2018/04/23: Added `disconnect` for users - [@dblock](https://github.com/dblock).
* 2018/04/23: Separated `help` and `info`, removed GIFs - [@dblock](https://github.com/dblock).
* 2018/04/18: Display miles logged on the web - [@dblock](https://github.com/dblock).
* 2018/04/15: Welcome users after the bot is installed  - [@dblock](https://github.com/dblock).
* 2018/04/14: Only post into channels with both the user and the bot  - [@dblock](https://github.com/dblock).
* 2018/04/06: Support swims with distances in yards - [@dblock](https://github.com/dblock).
* 2018/04/05: Added activity emoji - [@dblock](https://github.com/dblock).
* 2018/04/05: Display date/time of runs - [@dblock](https://github.com/dblock).
* 2018/04/05: Support time elapsed, moving time and elevation - [@dblock](https://github.com/dblock).
* 2018/03/28: Initial public release - [@dblock](https://github.com/dblock).
