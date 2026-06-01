import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ImageWithIconFallback extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final double? iconSize;
  final bool isCircle;

  const ImageWithIconFallback({
    super.key,
    required this.imageUrl,
    this.width,
    this.iconSize,
    this.height,
    this.fit,
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Icon(Icons.image, size: iconSize ?? 28, color: Colors.grey);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => Skeletonizer(
        enabled: true,
        child: isCircle
            ? Container(
          width: width,
          height: height,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        )
            : Container(color: Colors.white, width: width, height: height),
      ),
      errorWidget: (context, url, error) {
        return Icon(Icons.image, size: iconSize ?? 28, color: Colors.grey);
      },
    );
  }
}