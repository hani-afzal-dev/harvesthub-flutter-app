import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/phone_numbers.dart';
import '../../../core/validators.dart';
import '../../../models/user_model.dart';
import '../../../providers/admin_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../services/admin_service.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/async_error_view.dart';
import '../../../widgets/panel_ui.dart';
import '../../../widgets/phone_number_field.dart';

class AdminCustomersScreen extends ConsumerStatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  ConsumerState<AdminCustomersScreen> createState() =>
      _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends ConsumerState<AdminCustomersScreen> {
  static const _filterLabels = ['All', 'Active', 'Disabled'];

  final _searchController = TextEditingController();
  final Set<String> _busy = {};
  String _query = '';
  int _filter = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilter(UserModel user, int filter) {
    if (filter == 1) return user.isActive;
    if (filter == 2) return !user.isActive;
    return true;
  }

  Future<void> _toggleActive(UserModel user) async {
    if (_busy.contains(user.userId)) return;
    if (user.isActive) {
      final confirmed = await showPanelConfirm(
        context,
        title: 'Disable ${user.name}?',
        message:
            'They will be signed out right away and cannot log in until you enable the account again.',
        confirmLabel: 'Disable',
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _busy.add(user.userId));
    try {
      await ref
          .read(adminServiceProvider)
          .setUserActive(user.userId, !user.isActive);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
        user.isActive ? '${user.name} disabled' : '${user.name} enabled',
        tone: SnackTone.success,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
          'Could not update ${user.name}. Try again.',
          tone: SnackTone.error));
    } finally {
      if (mounted) setState(() => _busy.remove(user.userId));
    }
  }

  void _edit(UserModel user) {
    final adminService = ref.read(adminServiceProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) =>
          _EditCustomerSheet(user: user, adminService: adminService),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync =
        ref.watch(adminUsersByRoleProvider(UserRole.customer));

    Widget body;
    if (customersAsync.hasError && !customersAsync.hasValue) {
      body = AsyncErrorView(
        message: 'Could not load customers.',
        onRetry: () =>
            ref.invalidate(adminUsersByRoleProvider(UserRole.customer)),
      );
    } else if (!customersAsync.hasValue) {
      body = const Center(
          child: CircularProgressIndicator(color: PanelColors.brand));
    } else {
      final customers = customersAsync.value!;
      if (customers.isEmpty) {
        body = const PanelEmptyState(
          icon: Icons.people_alt_outlined,
          title: 'No customers yet',
          message: 'Customers appear here as soon as they sign up.',
        );
      } else {
        final searched = customers
            .where((u) => matchesSearch(_query, [u.name, u.email, u.phone]))
            .toList();
        final counts = List<int>.generate(_filterLabels.length,
            (i) => searched.where((u) => _matchesFilter(u, i)).length);
        final visible =
            searched.where((u) => _matchesFilter(u, _filter)).toList();

        body = CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: PanelSearchField(
                controller: _searchController,
                hint: 'Search by name, email or phone',
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            SliverToBoxAdapter(
              child: FilterChipBar(
                labels: _filterLabels,
                counts: counts,
                selected: _filter,
                onSelected: (i) => setState(() => _filter = i),
              ),
            ),
            if (visible.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: PanelEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                  message: 'Try a different name, email or filter.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final user = visible[index];
                    return _CustomerCard(
                      key: ValueKey('admin_customer_${user.userId}'),
                      user: user,
                      busy: _busy.contains(user.userId),
                      onEdit: () => _edit(user),
                      onToggle: () => _toggleActive(user),
                    );
                  },
                ),
              ),
          ],
        );
      }
    }

    final total = customersAsync.valueOrNull?.length;
    return Scaffold(
      backgroundColor: PanelColors.pageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            PanelHeader(
              title: 'Customers',
              subtitle: total == null
                  ? 'People who shop on HarvestHub'
                  : '$total registered ${total == 1 ? 'customer' : 'customers'}',
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final UserModel user;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _CustomerCard({
    super.key,
    required this.user,
    required this.busy,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PanelAvatar(name: user.name, muted: !user.isActive),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: PanelColors.textMain),
                    ),
                    const SizedBox(height: 4),
                    _Line(icon: Icons.mail_outline_rounded, text: user.email),
                    if (user.phone.isNotEmpty)
                      _Line(icon: Icons.phone_outlined, text: user.phone),
                    if (user.address.trim().isNotEmpty)
                      _Line(
                          icon: Icons.place_outlined,
                          text: user.address.trim()),
                  ],
                ),
              ),
              if (!user.isActive) ...[
                const SizedBox(width: 8),
                const StatusPill(
                  label: 'Disabled',
                  icon: Icons.block_rounded,
                  color: PanelColors.danger,
                  background: PanelColors.dangerBg,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: PanelColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: busy ? null : onEdit,
                style: TextButton.styleFrom(
                    foregroundColor: PanelColors.brand,
                    minimumSize: const Size(0, 44)),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                key: ValueKey('admin_customer_toggle_${user.userId}'),
                onPressed: busy ? null : onToggle,
                style: TextButton.styleFrom(
                  foregroundColor:
                      user.isActive ? PanelColors.danger : PanelColors.brand,
                  minimumSize: const Size(0, 44),
                ),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: PanelColors.brand),
                      )
                    : Icon(
                        user.isActive
                            ? Icons.block_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 18),
                label: Text(user.isActive ? 'Disable' : 'Enable'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Line({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: PanelColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: PanelColors.textBody),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditCustomerSheet extends StatefulWidget {
  final UserModel user;
  final AdminService adminService;

  const _EditCustomerSheet({required this.user, required this.adminService});

  @override
  State<_EditCustomerSheet> createState() => _EditCustomerSheetState();
}

class _EditCustomerSheetState extends State<_EditCustomerSheet> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.user.name);
  late final (DialCountry, String) _storedPhone =
      splitStoredPhone(widget.user.phone);
  late DialCountry _phoneCountry = _storedPhone.$1;
  late final TextEditingController _phoneController =
      TextEditingController(text: _storedPhone.$2);
  late final TextEditingController _addressController =
      TextEditingController(text: widget.user.address);
  bool _saving = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String? get _nameError => Validators.isValidName(_nameController.text)
      ? null
      : 'Use letters and spaces only.';

  String? get _phoneError =>
      Validators.localPhoneError(_phoneCountry, _phoneController.text);

  String? get _addressError => Validators.addressError(_addressController.text);

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (_nameError != null || _phoneError != null || _addressError != null) {
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.adminService.updateCustomer(
        widget.user.userId,
        name: _nameController.text,
        phone: toE164(_phoneCountry, _phoneController.text),
        address: _addressController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(appSnackBar(
          '${_nameController.text.trim()} updated',
          tone: SnackTone.success));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save changes. Check your connection and try again.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final phoneError = _submitted ? _phoneError : null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: PanelColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Edit customer',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: PanelColors.textMain)),
              const SizedBox(height: 4),
              Text(widget.user.email,
                  style: const TextStyle(
                      fontSize: 13, color: PanelColors.textMuted)),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey('admin_customer_name_field'),
                controller: _nameController,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: panelInputDecoration('Full name',
                    icon: Icons.person_outline_rounded,
                    error: _submitted ? _nameError : null),
              ),
              const SizedBox(height: 14),
              PhoneNumberField(
                fieldKey: const ValueKey('admin_customer_phone_field'),
                controller: _phoneController,
                country: _phoneCountry,
                label: 'Phone number',
                onCountryChanged: (country) =>
                    setState(() => _phoneCountry = country),
              ),
              if (phoneError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(phoneError,
                      style: const TextStyle(
                          fontSize: 12, color: PanelColors.danger)),
                ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('admin_customer_address_field'),
                controller: _addressController,
                enabled: !_saving,
                minLines: 2,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: panelInputDecoration('Address',
                    icon: Icons.place_outlined,
                    error: _submitted ? _addressError : null),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error,
                    style: const TextStyle(
                        fontSize: 13, color: PanelColors.danger)),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton(
                  key: const ValueKey('admin_customer_save_button'),
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: PanelColors.brand,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: PanelColors.brand),
                        )
                      : const Text('Save changes',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
