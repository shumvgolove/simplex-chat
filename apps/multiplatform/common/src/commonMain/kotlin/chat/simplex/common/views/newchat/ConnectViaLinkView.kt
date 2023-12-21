package chat.simplex.common.views.newchat

import androidx.compose.runtime.*
import chat.simplex.common.model.ChatModel
import chat.simplex.common.model.RemoteHostInfo

enum class ConnectViaLinkTab {
  SCAN, PASTE
}

@Composable
expect fun ConnectViaLinkView(m: ChatModel, rh: RemoteHostInfo?, close: () -> Unit)