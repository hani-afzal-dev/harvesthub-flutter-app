import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/service_providers.dart';
import '../services/cloudinary_service.dart';

class ImageUploadField extends ConsumerStatefulWidget {
  final String? initialImageUrl;
  final ValueChanged<String?> onUploaded;
  final double size;

  const ImageUploadField({
    super.key,
    required this.onUploaded,
    this.initialImageUrl,
    this.size = 120,
  });

  @override
  ConsumerState<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends ConsumerState<ImageUploadField> {
  String? _imageUrl;
  File? _localPreview;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.initialImageUrl;
  }

  static const int _maxFileSizeBytes = 5 * 1024 * 1024;
  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  Future<void> _pickAndUpload() async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
          source: ImageSource.gallery, imageQuality: 80, maxWidth: 1280);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not open your photos. Allow photo access in Settings and try again.');
      }
      return;
    }
    if (picked == null || !mounted) return;

    final extension = picked.path.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(extension)) {
      setState(() => _error = 'Please choose a JPG, PNG or WebP image.');
      return;
    }

    final file = File(picked.path);
    final sizeBytes = await file.length();
    if (sizeBytes > _maxFileSizeBytes) {
      setState(() =>
          _error = 'That image is too large. Please choose one under 5 MB.');
      return;
    }

    setState(() {
      _localPreview = file;
      _uploading = true;
      _error = null;
    });

    try {
      final cloudinary = ref.read(cloudinaryServiceProvider);
      final url = await cloudinary.uploadImage(file);
      if (!mounted) return;
      setState(() {
        _imageUrl = url;
        _uploading = false;
      });
      widget.onUploaded(url);
    } on CloudinaryUploadException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _localPreview = null;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _localPreview = null;
        _error = 'Something went wrong while uploading the image.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: 'Choose photo',
            child: GestureDetector(
              onTap: _uploading ? null : _pickAndUpload,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF3EA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD8E0CE)),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildPreview(),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _uploading
                ? 'Uploading...'
                : (_imageUrl ?? '').isEmpty
                    ? 'Tap to add photo'
                    : 'Tap to change photo',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7A5E)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB3261E))),
          ],
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_uploading) {
      return const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFF3B6D11)));
    }
    if (_localPreview != null) {
      return Image.file(_localPreview!, fit: BoxFit.cover);
    }
    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _imageUrl!,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => const Icon(
            Icons.image_not_supported_outlined,
            color: Color(0xFF6B7A5E)),
      );
    }
    return const Center(
        child: Icon(Icons.add_a_photo_outlined, color: Color(0xFF6B7A5E)));
  }
}
