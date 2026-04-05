import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../theme/muphone_theme.dart';
import 'device_card.dart';

class DeviceGrid extends StatelessWidget {
  const DeviceGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final devices = state.visibleDevices;
        final grid = state.gridConfig;
        final cols = grid.columns;
        final rows = grid.rows;
        final totalSlots = grid.totalSlots;

        if (state.connection == ServerConnectionState.disconnected && devices.isEmpty) {
          return const _EmptyState();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final availW = constraints.maxWidth;
            final availH = constraints.maxHeight;

            const gap = 6.0;
            const outerPad = 8.0;
            final gridW = availW - outerPad * 2;
            final gridH = availH - outerPad * 2;
            final cellW = (gridW - gap * (cols - 1)) / cols;
            final cellH = (gridH - gap * (rows - 1)) / rows;

            final targetAspect = devices.isNotEmpty && devices.first.width > 0 && devices.first.height > 0
                ? devices.first.width / devices.first.height
                : 9.0 / 20.0;
            final cellAspect = cellW / cellH;
            double cardW, cardH;
            if (cellAspect > targetAspect) {
              cardH = cellH;
              cardW = cellH * targetAspect;
            } else {
              cardW = cellW;
              cardH = cellW / targetAspect;
            }

            final totalGridW = cardW * cols + gap * (cols - 1);
            final totalGridH = cardH * rows + gap * (rows - 1);
            final offsetX = (availW - totalGridW) / 2;
            final offsetY = (availH - totalGridH) / 2;

            return Stack(
              children: List.generate(totalSlots, (index) {
                final col = index % cols;
                final row = index ~/ cols;
                final x = offsetX + col * (cardW + gap);
                final y = offsetY + row * (cardH + gap);

                final hasDevice = index < devices.length;
                final device = hasDevice ? devices[index] : null;

                Widget child;
                if (hasDevice) {
                  child = DeviceCard(device: device!);
                } else {
                  child = _PlaceholderSlot(slotIndex: index);
                }

                return Positioned(
                  left: x, top: y, width: cardW, height: cardH,
                  child: child,
                );
              }),
            );
          },
        );
      },
    );
  }
}

class _PlaceholderSlot extends StatelessWidget {
  const _PlaceholderSlot({required this.slotIndex, this.highlighted = false});
  final int slotIndex;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MUPhoneColors.card.withValues(alpha: highlighted ? 0.5 : 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF42A5F5)
              : MUPhoneColors.border.withValues(alpha: 0.3),
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.phone_android,
          size: 24,
          color: MUPhoneColors.textDisabled.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.devices, size: 64, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text(
            '未連接到伺服器',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '正在嘗試連接 127.0.0.1...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}
