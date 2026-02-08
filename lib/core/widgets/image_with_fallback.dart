import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ImageWithIconFallback extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final double? iconSize;

  const ImageWithIconFallback({
    super.key,
    required this.imageUrl,
    this.width,
    this.iconSize,
    this.height,
    this.fit,
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
        child: Container(color: Colors.white, width: width, height: height),
      ),
      errorWidget: (context, url, error) {
        return Icon(Icons.image, size: iconSize ?? 28, color: Colors.grey);
      },
    );
  }
}