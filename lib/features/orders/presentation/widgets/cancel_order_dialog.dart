import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/order_model.dart';
import '../../manager/order_cubit.dart';


class CancelOrderDialog extends StatefulWidget {
  final Order order;

  const CancelOrderDialog({
    super.key,
    required this.order,
  });

  @override
  State<CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<CancelOrderDialog> {
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _cancel() {
    if (_formKey.currentState!.validate()) {
      context.read<OrderCubit>().cancelOrder(
        widget.order.id!,
        _reasonController.text.trim(),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Cancel Order',
        style: AppTextStyles.bold18,
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel order ${widget.order.orderNumber}?',
              style: AppTextStyles.regular14,
            ),
            const SizedBox(height: 16),
            AppTextFormField(
              controller: _reasonController,
              label: 'Cancellation Reason',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide a reason';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)?.cancel ?? 'No'),
        ),
        TextButton(
          onPressed: _cancel,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Yes, Cancel Order'),
        ),
      ],
    );
  }
}