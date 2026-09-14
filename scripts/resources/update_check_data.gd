class_name UpdateCheckData
extends Resource
## Where to ask what the newest published build is, and where to send a player who wants it.
##
## The endpoint is itch.io's own, and it needs no API key. It answers `{"latest":"1.0.0"}` with
## exactly the version `butler` was given when the release was pushed, so it follows a release with
## nothing to maintain here and nothing that can drift out of step.
##
## **Not GitHub's releases API**, which would work just as well and would tie a player-facing
## feature to where the source happens to live. The repository moved once already.

## The wharf endpoint. `target` and `channel_name` are added as query parameters.
@export var endpoint: String = "https://itch.io/api/1/x/wharf/latest"
## The itch.io page, as `user/game`. Not the GitHub owner, which is a different name.
@export var target: String = "garden-fence/fight-island"
## The channel to ask about on a platform with no entry in `channels`.
@export var fallback_channel: String = "windows"
## Which channel each platform's build was pushed to, keyed by `OS.get_name()`.
@export var channels: Dictionary = {"macOS": "mac", "Windows": "windows"}
## Where a player goes to get it. Opened in their browser, and never downloaded here.
@export var page: String = "https://garden-fence.itch.io/fight-island"
## How long to wait before giving up and saying nothing. Short on purpose: nobody is waiting on
## this, and a title screen that hangs on the network is a bug wearing a feature's coat.
@export var timeout_seconds: float = 5.0
