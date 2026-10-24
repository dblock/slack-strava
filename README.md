Slava
=====

[![Tests](https://github.com/dblock/slack-strava/actions/workflows/test.yml/badge.svg)](https://github.com/dblock/slack-strava/actions/workflows/test.yml)
[![Coverage](https://img.shields.io/badge/coverage-91.76%25-brightgreen)](https://github.com/dblock/slack-strava)

Integrate Strava into Slack. Hosted at [slava.playplay.io](https://slava.playplay.io/).

## Install

[![Add to Slack](https://platform.slack-edge.com/img/add_to_slack.png)](https://slava.playplay.io)

If Slack reports that the bot account is inactive, Slava deactivates the installation and stops activity delivery. Reinstall using **Add to Slack** to resume with the existing users, Strava connections, and pending activities. No user data is deleted when the installation is deactivated; the existing inactive-team cleanup policy still applies, including purging unsubscribed teams after two weeks.

## Website artwork

The shared website layout uses the editable `public/img/screenshot-background.svg`, adapted from Strata's ribbon artwork with a logo-derived orange palette (base `#E97358`). The SVG preserves `preserveAspectRatio="none"` and is painted on a fixed viewport-sized layer so expanding help does not resize the background. Keep the transparent shoe logo, matching multi-resolution favicon, and original transparent `public/img/notify.png` hero when updating the design.

### Copyright & License

Copyright [Daniel Doubrovkine, Vestris LLC](https://www.vestris.com), 2018-2025

[MIT License](LICENSE)
