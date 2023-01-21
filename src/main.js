import "core-js/modules/es6.promise";
import axios from 'axios';

const token = scriptSettings.getString('token');
const channels = (scriptSettings.getString('channels') || '').split(',').map(s => s.trim()).filter(s => s.length);

function alertAndThrow(msg) {
    log.a(msg);
    throw new Error(msg);
}

if (!token || !token.length) {
    alertAndThrow('No Slack token is configured. Enter a value for "token" in the Script Settings.');
}
log.clearAlerts();

if (!channels || !channels.length) {
    alertAndThrow('No Slack channels are configured. Use "channels" in Script Settings to provide a comma separated list of channels.');
}
log.clearAlerts();

function SlackChannel(channel) {
    this.channel = channel;
}

// implementation of Notifier

SlackChannel.prototype.postSlack = function(payload) {
    const headers = {
        'Authorization': `Bearer ${token}`
    };

    return axios.post(`https://slack.com/api/chat.postMessage`, payload, {headers: headers});
}

SlackChannel.prototype.sendNotification = function (title, body, media, mimeType) {
    console.log('sendNotification (media) was called!');

    const attachment = {
        fallback: body,
        title: title,
        text: body,
    }

    mediaConverter.convert(media, mimeType)
        .to('android.net.Uri', mimeType)
        .setCallback((e, result) => {
            if (result) {
                attachment['thumb_url'] = result.toString();
            }

            this.postSlack({channel: this.channel, attachments: [attachment]});
        });
}

function Slack() {
    setImmediate(() => {
        var devices = channels.map(channel => ({
            name: `Slack: ${channel}`,
            id: channel,
            type: 'Notifier',
            interfaces: ['Notifier'],
        }));

        deviceManager.onDevicesChanged({
            devices,
        });
    });
}

Slack.prototype.getDevice = function(id) {
    if (channels.indexOf(id) == -1)
        return null;
    return new SlackChannel(id);
}

export default new Slack();