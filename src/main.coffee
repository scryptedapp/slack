import { ScryptedDeviceBase, ScryptedInterface, ScryptedDeviceType } from '@scrypted/sdk'
import sdk from '@scrypted/sdk'
import { WebClient, ErrorCode } from '@slack/web-api'
import crypto from "crypto";

{ mediaManager, deviceManager } = sdk

class ExtraSlackNotifier extends ScryptedDeviceBase
    constructor: (nativeId, @parent) ->
        super nativeId
        @resolveChannelId()

    slackChannel: ->
        @storage.getItem 'slack_channel'

    resolveChannelId: ->
        @channelId = null
        if @slackChannel()
            try
                apiResponse = await @parent.client.conversations.list()
                channel = apiResponse.channels.find (c) => c.name == @slackChannel()

                unless channel
                    throw new Error "unknown channel #{@slackChannel()}"

                @channelId = channel.id
                @console.info "Resolved channel #{@slackChannel()} to #{@channelId}"
            catch e
                @console.info "Error resolving Slack channel: #{e}"
                @channelId = null

    getSettings: ->
        [
            {
                key: 'slack_channel'
                title: 'Slack Channel'
                value: @slackChannel()
            }
        ]

    putSetting: (key, value) ->
        @storage.setItem key, value
        @resolveChannelId()
        @onDeviceEvent ScryptedInterface.Settings, null

    sendNotification: (title, options, media = null, icon = null) ->
        @parent.sendNotificationImpl @console, @slackChannel(), @channelId, { title, options, media, icon }

class SlackNotifier extends ScryptedDeviceBase
    constructor: (nativeId) ->
        super nativeId
        @initClient()
        @devices = new Map

    initClient: ->
        @client = null
        @channelId = null
        unless @slackToken()
            @console.info 'No Slack token present, not initializing client'
        else unless @slackChannel()
            @console.info 'No Slack channel selected, not initializing client'
        else
            try
                @client = new WebClient @slackToken()
                @console.info 'Initialized Slack client'

                apiResponse = await @client.conversations.list()
                channel = apiResponse.channels.find (c) => c.name == @slackChannel()

                unless channel
                    throw new Error "unknown channel #{@slackChannel()}"

                @channelId = channel.id
                @console.info "Resolved channel #{@slackChannel()} to #{@channelId}"
            catch e
                @console.info "Error initializing Slack client: #{e}"
                @client = null
                @channelId = null

    slackToken: ->
        @storage.getItem 'slack_token'

    slackChannel: ->
        @storage.getItem 'slack_channel'

    getSettings: ->
        [
            {
                key: 'slack_token'
                title: 'Slack Token'
                type: 'password'
                value: @slackToken()
            }
            {
                key: 'slack_channel'
                title: 'Slack Channel'
                value: @slackChannel()
            }
        ]

    putSetting: (key, value) ->
        @storage.setItem key, value
        @initClient()
        @onDeviceEvent ScryptedInterface.Settings, null

    sendNotification: (title, options, media = null, icon = null) ->
        @sendNotificationImpl @console, @slackChannel(), @channelId, { title, options, media, icon }

    sendNotificationImpl: (console, channel, channelId, scryptedOptions) ->
        { title, options, media, icon } = scryptedOptions
        unless @client
            console.info 'Slack client not initialized, cannot send notification'
        else unless channelId and channel
            console.info 'Invalid Slack channel, cannot send message'
        else
            console.info "Starting to send Slack message"

            body = options?.body ? ''
            message = "*#{title}*\n#{body}".trim()

            console.info media

            try
                if typeof media == 'string'
                    media = await mediaManager.createMediaObjectFromUrl media
                if media
                    data = await mediaManager.convertMediaObjectToBuffer media, 'image/png'
                    await @client.files.uploadV2
                        file: data
                        filename: 'image.png'
                        channel_id: channelId
                        initial_comment: message
                        request_file_info: no
                else
                    await @client.chat.postMessage
                        channel: channel
                        text: message

                console.info 'Sent successfully'
            catch e
                console.info "Error sending to Slack: #{e}"
                if e?.code is ErrorCode.PlatformError
                    @console.info e.data

    getCreateDeviceSettings: ->
        [
            {
                title: 'Name',
                key: 'name'
            }
        ]

    createDevice: (settings) ->
        uuid = crypto.randomUUID()
        name = settings?.name?.toString() or "New Slack Notifier"
        await deviceManager.onDeviceDiscovered
            nativeId: uuid
            name: name
            interfaces: [
                ScryptedInterface.Notifier
                ScryptedInterface.Settings
            ]
            type: ScryptedDeviceType.Notifier
        await @getDevice uuid
        uuid

    getDevice: (nativeId) ->
        if @devices.has nativeId
            @devices.get nativeId
        else
            device = new ExtraSlackNotifier nativeId, this
            @devices.set nativeId, device
            device

    releaseDevice: (id, nativeId) -> @devices.delete nativeId

export default SlackNotifier