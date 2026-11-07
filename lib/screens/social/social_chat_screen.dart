import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/models/xmpp_models.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/providers/xmpp_provider.dart';
import 'package:valorant_thunai/screens/profile/player_search_screen.dart';
import 'package:valorant_thunai/utils/format_utils.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

const List<String> _fallbackAgentIds = [
  'add64435-ae81-439b-1615-51d6506c47e6',
  'a3dead5e-4b47-497d-92ec-a0680f425b0e',
  'ade2b615-47db-330c-e346-ae877947466e',
  '117ed9e3-49f3-6512-3ccf-00ad78bb7d80',
];

String _fallbackAgentIconFor(String? name) {
  final agentId =
      _fallbackAgentIds[(name ?? '').hashCode % _fallbackAgentIds.length];
  return 'https://media.valorant-api.com/agents/$agentId/displayicon.png';
}

class SocialChatScreen extends ConsumerStatefulWidget {
  final String? initialRecipientPuuid;
  final String? initialRecipientName;

  const SocialChatScreen({
    super.key,
    this.initialRecipientPuuid,
    this.initialRecipientName,
  });

  @override
  ConsumerState<SocialChatScreen> createState() => _SocialChatScreenState();
}

class _SocialChatScreenState extends ConsumerState<SocialChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoConnectXmpp();
    });
  }

  Future<void> _autoConnectXmpp() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final xmppState = ref.read(xmppProvider);
    if (!xmppState.isConnected) {
      await ref.read(xmppProvider.notifier).connect(user);
    }
    await ref.read(xmppProvider.notifier).resolveAllFriendNames();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final recipientPuuid = widget.initialRecipientPuuid;
    final text = _messageController.text.trim();
    if (text.isEmpty || recipientPuuid == null) return;

    ref.read(xmppProvider.notifier).sendMessage(recipientPuuid, text);
    _messageController.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openProfile() {
    final xmppState = ref.read(xmppProvider);
    final recipientPuuid = widget.initialRecipientPuuid;
    final presence = recipientPuuid != null
        ? xmppState.friendPresences[recipientPuuid]
        : null;
    final displayName =
        presence?.gameName ?? widget.initialRecipientName ?? recipientPuuid;
    final riotId = (presence != null && (presence.tagline ?? '').isNotEmpty)
        ? '${presence.gameName}#${presence.tagline}'
        : (widget.initialRecipientName ?? displayName);
    if (riotId != null && riotId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PlayerSearchPage(initialQuery: riotId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final xmppState = ref.watch(xmppProvider);
    final user = ref.watch(authProvider).user;
    final displaySettings = ref.watch(displaySettingsProvider);
    final recipientPuuid = widget.initialRecipientPuuid;

    final presence = recipientPuuid != null
        ? xmppState.friendPresences[recipientPuuid]
        : null;
    final displayName =
        presence?.gameName ?? widget.initialRecipientName ?? recipientPuuid;
    final activeMessages = recipientPuuid != null
        ? xmppState.conversations[recipientPuuid] ?? <ChatMessage>[]
        : <ChatMessage>[];

    final isOnline = presence?.isOnline ?? false;
    final statusSubtitle = presence != null
        ? [
            presence.formattedStatus,
            if (presence.formattedSubStatus.isNotEmpty)
              presence.formattedSubStatus,
          ].join(' • ')
        : (isOnline ? 'Online' : 'Offline');

    final agentIconUrl = _fallbackAgentIconFor(displayName);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 2,
        titleSpacing: 0,
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _openProfile,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: agentIconUrl,
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 38,
                          height: 38,
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 38,
                          height: 38,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.person,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -1,
                      right: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(1.5),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isOnline
                                ? (presence?.sessionLoop == 'INGAME'
                                      ? Colors.redAccent
                                      : Colors.greenAccent)
                                : theme.colorScheme.outline,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName ?? l10n.valorantLiveSocialTitle,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (statusSubtitle.isNotEmpty)
                        Text(
                          statusSubtitle,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: (presence?.sessionLoop == 'INGAME')
                                ? Colors.redAccent
                                : (isOnline
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface),
            color: theme.colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (val) {
              if (val == 'profile') {
                _openProfile();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(
                      Icons.account_circle_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.openProfileButton,
                      style: GoogleFonts.inter(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: recipientPuuid == null
          ? Center(
              child: Text(
                l10n.selectFriendToChat,
                style: GoogleFonts.inter(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              children: [
                if (!xmppState.isConnected)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.statusLabelPrefix(xmppState.status),
                            style: GoogleFonts.inter(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (user != null)
                          TextButton.icon(
                            onPressed: () =>
                                ref.read(xmppProvider.notifier).connect(user),
                            icon: Icon(
                              Icons.refresh,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            label: Text(
                              l10n.connectButton,
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                Expanded(
                  child: activeMessages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 48,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l10n.noMessagesYetSayHi,
                                style: GoogleFonts.inter(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: activeMessages.length,
                          itemBuilder: (context, index) {
                            final msg = activeMessages[index];
                            final timeStr = FormatUtils.formatTime(
                              msg.timestamp,
                              displaySettings,
                            );
                            final isMe = msg.isMe;

                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? theme.colorScheme.primaryContainer
                                      : theme.colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      msg.body,
                                      style: GoogleFonts.inter(
                                        color: isMe
                                            ? theme
                                                  .colorScheme
                                                  .onPrimaryContainer
                                            : theme.colorScheme.onSurface,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      timeStr,
                                      style: GoogleFonts.inter(
                                        color:
                                            (isMe
                                                    ? theme
                                                          .colorScheme
                                                          .onPrimaryContainer
                                                    : theme
                                                          .colorScheme
                                                          .onSurfaceVariant)
                                                .withValues(alpha: 0.7),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: _messageController,
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurface,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: l10n.typeMessageHint,
                                hintStyle: GoogleFonts.inter(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                          ),
                          icon: const Icon(Icons.send_rounded, size: 20),
                          onPressed: _sendMessage,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
