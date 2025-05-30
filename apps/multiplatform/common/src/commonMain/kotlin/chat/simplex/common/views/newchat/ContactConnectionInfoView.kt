package chat.simplex.common.views.newchat

import SectionBottomSpacer
import SectionDividerSpaced
import SectionTextFooter
import SectionView
import SectionViewWithButton
import androidx.compose.desktop.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.*
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.unit.dp
import dev.icerock.moko.resources.compose.painterResource
import dev.icerock.moko.resources.compose.stringResource
import chat.simplex.common.model.*
import chat.simplex.common.ui.theme.*
import chat.simplex.common.views.chat.LocalAliasEditor
import chat.simplex.common.views.chatlist.deleteContactConnectionAlert
import chat.simplex.common.views.helpers.*
import chat.simplex.common.model.ChatModel
import chat.simplex.common.model.PendingContactConnection
import chat.simplex.common.platform.*
import chat.simplex.common.views.usersettings.*
import chat.simplex.res.MR
import kotlinx.coroutines.*

@Composable
fun ContactConnectionInfoView(
  chatModel: ChatModel,
  rhId: Long?,
  connLinkInvitation: CreatedConnLink?,
  contactConnection: PendingContactConnection,
  focusAlias: Boolean,
  close: () -> Unit
) {
  LaunchedEffect(connLinkInvitation) {
    if (connLinkInvitation != null) {
      chatModel.showingInvitation.value = ShowingInvitation(contactConnection.id, connLinkInvitation, false, conn = contactConnection)
    }
  }
  /** When [AddContactLearnMore] is open, we don't need to drop [ChatModel.showingInvitation].
   * Otherwise, it will be called here AFTER [AddContactLearnMore] is launched and will clear the value too soon.
   * It will be dropped automatically when connection established or when user goes away from this screen.
   * It applies only to Android because on Desktop center space will not be overlapped by [AddContactLearnMore]
   **/
  DisposableEffect(Unit) {
    onDispose {
      if (!ModalManager.center.hasModalsOpen() || appPlatform.isDesktop) {
        chatModel.showingInvitation.value = null
      }
    }
  }
  val showShortLink = remember { mutableStateOf(true) }
  ContactConnectionInfoLayout(
    chatModel = chatModel,
    connLink = connLinkInvitation,
    showShortLink = showShortLink,
    contactConnection = contactConnection,
    focusAlias = focusAlias,
    rhId = rhId,
    deleteConnection = { deleteContactConnectionAlert(rhId, contactConnection, chatModel, close) },
    onLocalAliasChanged = { setContactAlias(rhId, contactConnection, it, chatModel) },
    learnMore = {
      ModalManager.end.showModalCloseable { close ->
        AddContactLearnMore(close)
      }
    }
  )
}

@Composable
private fun ContactConnectionInfoLayout(
  chatModel: ChatModel,
  connLink: CreatedConnLink?,
  showShortLink: MutableState<Boolean>,
  contactConnection: PendingContactConnection,
  focusAlias: Boolean,
  rhId: Long?,
  deleteConnection: () -> Unit,
  onLocalAliasChanged: (String) -> Unit,
  learnMore: () -> Unit,
) {
  @Composable fun incognitoEnabled() {
    if (contactConnection.incognito) {
      SettingsActionItemWithContent(
        icon = painterResource(MR.images.ic_theater_comedy_filled),
        text = null,
        click = { ModalManager.end.showModal { IncognitoView() } },
        iconColor = Indigo,
        extraPadding = false
      ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
          Text(stringResource(MR.strings.incognito), Modifier.padding(end = 4.dp))
          Icon(
            painterResource(MR.images.ic_info),
            null,
            tint = MaterialTheme.colors.primary
          )
        }
      }
    }
  }

  ColumnWithScrollBar {
    AppBarTitle(
      stringResource(
        if (contactConnection.initiated) MR.strings.you_invited_a_contact
        else MR.strings.you_accepted_connection
      ),
      hostDevice(rhId)
    )
    Text(
      stringResource(
        if (contactConnection.viaContactUri)
          if (contactConnection.groupLinkId != null) MR.strings.you_will_be_connected_when_group_host_device_is_online
          else MR.strings.you_will_be_connected_when_your_connection_request_is_accepted
        else MR.strings.you_will_be_connected_when_your_contacts_device_is_online
      ),
      Modifier.padding(start = DEFAULT_PADDING, end = DEFAULT_PADDING, bottom = DEFAULT_PADDING)
    )

    if (contactConnection.groupLinkId == null) {
      LocalAliasEditor(contactConnection.id, contactConnection.localAlias, center = false, leadingIcon = true, focus = focusAlias, updateValue = onLocalAliasChanged)
    }

    if (connLink != null && connLink.connFullLink.isNotEmpty() && contactConnection.initiated) {
      Spacer(Modifier.height(DEFAULT_PADDING))
      SectionViewWithButton(
        stringResource(MR.strings.one_time_link).uppercase(),
        titleButton = if (connLink.connShortLink == null) null else {{ ToggleShortLinkButton(showShortLink) }}
      ) {
        SimpleXCreatedLinkQRCode(connLink, short = showShortLink.value)
        incognitoEnabled()
        ShareLinkButton(connLink.simplexChatUri(short = showShortLink.value))
        OneTimeLinkLearnMoreButton(learnMore)
      }
    } else {
      SectionView {
        incognitoEnabled()
        OneTimeLinkLearnMoreButton(learnMore)
      }
    }
    SectionTextFooter(sharedProfileInfo(chatModel, contactConnection.incognito))

    SectionDividerSpaced(maxTopPadding = true, maxBottomPadding = false)

    DeleteButton(deleteConnection)

    SectionBottomSpacer()
  }
}

@Composable
fun ShareLinkButton(linkUri: String) {
  val clipboard = LocalClipboardManager.current
  SettingsActionItem(
    painterResource(MR.images.ic_share),
    stringResource(MR.strings.share_invitation_link),
    click = {
      chatModel.showingInvitation.value = chatModel.showingInvitation.value?.copy(connChatUsed = true)
      clipboard.shareText(simplexChatLink(linkUri))
    },
    iconColor = MaterialTheme.colors.primary,
    textColor = MaterialTheme.colors.primary,
  )
}

@Composable
fun OneTimeLinkLearnMoreButton(onClick: () -> Unit) {
  SettingsActionItem(
    painterResource(MR.images.ic_info),
    stringResource(MR.strings.learn_more),
    onClick,
  )
}

@Composable
fun DeleteButton(onClick: () -> Unit) {
  SettingsActionItem(
    painterResource(MR.images.ic_delete),
    stringResource(MR.strings.delete_verb),
    click = onClick,
    textColor = Color.Red,
    iconColor = Color.Red,
  )
}

private fun setContactAlias(rhId: Long?, contactConnection: PendingContactConnection, localAlias: String, chatModel: ChatModel) = withBGApi {
  chatModel.controller.apiSetConnectionAlias(rhId, contactConnection.pccConnId, localAlias)?.let {
    withContext(Dispatchers.Main) {
      chatModel.chatsContext.updateContactConnection(rhId, it)
    }
  }
}

@Preview/*(
  uiMode = Configuration.UI_MODE_NIGHT_YES,
  showBackground = true,
  name = "Dark Mode"
)*/
@Composable
private fun PreviewContactConnectionInfoView() {
  SimpleXTheme {
    ContactConnectionInfoLayout(
      chatModel = ChatModel,
      connLink = CreatedConnLink("https://simplex.chat/contact#/?v=1&smp=smp%3A%2F%2FPQUV2eL0t7OStZOoAsPEV2QYWt4-xilbakvGUGOItUo%3D%40smp6.simplex.im%2FK1rslx-m5bpXVIdMZg9NLUZ_8JBm8xTt%23MCowBQYDK2VuAyEALDeVe-sG8mRY22LsXlPgiwTNs9dbiLrNuA7f3ZMAJ2w%3D", null),
      showShortLink = remember { mutableStateOf(true) },
      contactConnection = PendingContactConnection.getSampleData(),
      focusAlias = false,
      rhId = null,
      deleteConnection = {},
      onLocalAliasChanged = {},
      learnMore = {}
    )
  }
}
