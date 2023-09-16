# Slack Notifier Plugin for Scrypted

Notifier to post messages and images to Slack channels.

The root plugin device is a Scrypted Notifier and can post messages to a single channel. If more channels are desired, manually add additional devices under this plugin and configure them to publish to different channels. All notifiers under this plugin will use the same token.

- Create a new App in Slack
- Add your App to your Slack workspace
- Add your App to the desired channel
- Generate an OAuth token for your workspace
- Enter the token as the "Slack token" setting
- Enter the desired channel to post to as the "Slack channel" setting
