import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_logger.dart';
import '../../../models/farmer_model.dart';
import '../../../providers/follow_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../providers/session_providers.dart';
import '../../../widgets/async_error_view.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/app_snackbar.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _brandDark = Color(0xFF2E4A0F);
const Color _textMain = Color(0xFF22301A);
const Color _textMuted = Color(0xFF6B7A5E);
const Color _tint = Color(0xFFEFF3EA);

class MyFarmersScreen extends ConsumerWidget {
  const MyFarmersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) {
      return const Scaffold(
          body: Center(
              child: Text('Please log in to see the farmers you follow.')));
    }
    final farmersAsync = ref.watch(followedFarmersProvider(uid));

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F3),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const PageHeader(title: 'Farmers you follow'),
            Expanded(
              child: farmersAsync.when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => AsyncErrorView(
                  message:
                      'Could not load your farmers. Check your connection and try again.',
                  onRetry: () => ref.invalidate(followedFarmerIdsProvider(uid)),
                ),
                data: (farmers) {
                  if (farmers.isEmpty) return const _EmptyFarmers();
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 10),
                            child: Text(
                              "You'll get restock alerts from ${farmers.length} farm${farmers.length == 1 ? '' : 's'}.",
                              style: const TextStyle(
                                  fontSize: 13, color: _textMuted),
                            ),
                          ),
                          for (final farmer in farmers) ...[
                            _FarmerCard(uid: uid, farmer: farmer),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FarmerCard extends ConsumerStatefulWidget {
  final String uid;
  final FarmerModel farmer;

  const _FarmerCard({required this.uid, required this.farmer});

  @override
  ConsumerState<_FarmerCard> createState() => _FarmerCardState();
}

class _FarmerCardState extends ConsumerState<_FarmerCard> {
  bool _busy = false;

  Future<void> _unfollow() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final followService = ref.read(followServiceProvider);
    final uid = widget.uid;
    final farmerId = widget.farmer.farmerId;
    final name = widget.farmer.businessName;
    try {
      await followService.toggleFollow(uid, farmerId);
      messenger.showSnackBar(
        appSnackBar('You unfollowed $name.',
            tone: SnackTone.success,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                try {
                  await followService.toggleFollow(uid, farmerId);
                } catch (e, stack) {
                  AppLogger.error('Follow undo failed', e, stack);
                  messenger.showSnackBar(appSnackBar(
                      'Could not follow $name again.',
                      tone: SnackTone.error));
                }
              },
            )),
      );
    } catch (e, stack) {
      AppLogger.error('Unfollow failed', e, stack);
      messenger.showSnackBar(appSnackBar('Could not unfollow $name. Try again.',
          tone: SnackTone.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmer = widget.farmer;
    final hasRating = farmer.ratingCount > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _brandDark.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFA6CF6B), Color(0xFF6E9A3A)],
                  ),
                ),
                child: const Icon(Icons.agriculture_outlined,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            farmer.businessName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _textMain),
                          ),
                        ),
                        if (farmer.isVerified) ...[
                          const SizedBox(width: 6),
                          const Tooltip(
                            message: 'Verified farm',
                            child: Icon(Icons.verified_rounded,
                                size: 18,
                                color: _brand,
                                semanticLabel: 'Verified'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 16, color: Color(0xFFEF9F27)),
                        const SizedBox(width: 3),
                        Text(
                          hasRating ? farmer.rating.toStringAsFixed(1) : 'New',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _textMain),
                        ),
                        if (hasRating)
                          Text(
                            '  (${farmer.ratingCount} rating${farmer.ratingCount == 1 ? '' : 's'})',
                            style: const TextStyle(
                                fontSize: 12, color: _textMuted),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (farmer.description.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              farmer.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, height: 1.4, color: Color(0xFF4C5943)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                      color: _tint, borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    children: [
                      Icon(Icons.notifications_active_outlined,
                          size: 16, color: _brand),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Restock alerts on',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _brand),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                key: ValueKey('unfollow_${farmer.farmerId}'),
                onPressed: _busy ? null : _unfollow,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD64545),
                  side: const BorderSide(color: Color(0xFFF0C4C4)),
                  minimumSize: const Size(96, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFFD64545)),
                      )
                    : const Text('Unfollow',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyFarmers extends StatelessWidget {
  const _EmptyFarmers();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, color: _tint),
                child:
                    Icon(Icons.agriculture_outlined, size: 44, color: _brand),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'No farmers followed yet',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _textMain),
            ),
            SizedBox(height: 6),
            Text(
              'Follow a farmer from any product page to get restock alerts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
