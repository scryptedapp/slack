from slack_sdk.web.async_client import AsyncWebClient

import scrypted_sdk
from scrypted_sdk import ScryptedDeviceBase
from scrypted_sdk.types import Settings, Notifier, Setting, SettingValue, MediaObject
from typing import List, Union

class SlackNotifier(ScryptedDeviceBase, Settings, Notifier):
    client: AsyncWebClient = None

    def __init__(self, nativeId: Union[str, None] = None) -> None:
        super().__init__(nativeId=nativeId)
        self.init_client()

    def print(self, *args, **kwargs) -> None:
        """Overrides the print() from ScryptedDeviceBase to avoid double-printing in the main plugin console."""
        print(*args, **kwargs)

    def init_client(self) -> None:
        self.client = None
        if not self.slack_token:
            self.print("No Slack token present, not initializing client")
            return
        if not self.slack_channel:
            self.print("No Slack channel selected, not initializing client")

        try:
            self.client = AsyncWebClient(token=self.slack_token)
            self.print("Initialized Slack client")
        except Exception as e:
            self.print(f"Error initializing Slack client: {e}")

    @property
    def slack_token(self) -> str:
        return self.storage.getItem("slack_token")

    @property
    def slack_channel(self) -> str:
        return self.storage.getItem("slack_channel")

    async def getSettings(self) -> List[Setting]:
        return [
            {
                "key": "slack_token",
                "title": "Slack Token",
                "type": "password",
                "value": self.slack_token,
            },
            {
                "key": "slack_channel",
                "title": "Slack Channel",
                "value": self.slack_channel,
            },
        ]

    async def putSetting(self, key: str, value: SettingValue) -> None:
        self.storage.setItem(key, value)
        self.init_client()

    async def sendNotification(self, title: str, options: dict, media: Union[str, MediaObject] = None, icon: Union[str, MediaObject] = None) -> None:
        if not self.client:
            self.print("Slack client not initialized, cannot send notification")
            return

        self.print("Starting to send Slack message")

        body = options.get("body", "")
        message = f"*{title}*\n{body}".strip()

        self.print(media)

        try:
            if type(media) == str:
                media = await scrypted_sdk.mediaManager.createMediaObjectFromUrl(media)
            if media:
                data = await scrypted_sdk.mediaManager.convertMediaObjectToBuffer(media, "image/png")
                response = await self.client.files_upload(
                    file=data,
                    filename="image.png",
                    channels=self.slack_channel,
                    initial_comment=message,
                )
                response.validate()
            else:
                response = await self.client.chat_postMessage(
                    channel=self.slack_channel,
                    text=message,
                )
                response.validate()
        except Exception as e:
            self.print(f"Error sending to Slack: {e}")
        else:
            self.print("Sent successfully")


def create_scrypted_plugin() -> ScryptedDeviceBase:
    return SlackNotifier()