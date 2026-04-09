import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_app_bar.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/widgets/prize_card_widget.dart';

class XpPrizesScreen extends StatefulWidget {
  const XpPrizesScreen({super.key});

  @override
  State<XpPrizesScreen> createState() => _XpPrizesScreenState();
}

class _XpPrizesScreenState extends State<XpPrizesScreen> {
  final List<String> _filterTabs = ['all', 'claimable', 'claimed', 'expired'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<XpController>().getPrizes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'prizes'.tr),
      body: GetBuilder<XpController>(
        builder: (xpController) {
          return Column(
            children: [
              // Filter tabs
              _buildFilterTabs(context, xpController),
              // Stats
              if (xpController.prizeModel != null)
                _buildPrizeStats(context, xpController),
              // Prizes grid
              Expanded(
                child:
                    xpController.isPrizesLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildPrizesGrid(context, xpController),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context, XpController xpController) {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filterTabs.length,
        itemBuilder: (context, index) {
          final isSelected = xpController.selectedPrizeFilter == index;
          return GestureDetector(
            onTap: () => xpController.changePrizeFilter(index),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  _filterTabs[index].tr,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrizeStats(BuildContext context, XpController xpController) {
    final prizeModel = xpController.prizeModel;
    if (prizeModel == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.1),
            Theme.of(context).primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            Icons.lock_open,
            prizeModel.totalUnlocked.toString(),
            'unlocked'.tr,
            Colors.blue,
          ),
          Container(width: 1, height: 30, color: Colors.grey.shade300),
          _buildStatItem(
            context,
            Icons.check_circle,
            prizeModel.totalClaimed.toString(),
            'claimed'.tr,
            Colors.green,
          ),
          Container(width: 1, height: 30, color: Colors.grey.shade300),
          _buildStatItem(
            context,
            Icons.card_giftcard,
            prizeModel.claimablePrizes.length.toString(),
            'claimable'.tr,
            Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildPrizesGrid(BuildContext context, XpController xpController) {
    final prizes = xpController.filteredPrizes;

    if (prizes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.card_giftcard_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'no_prizes_available'.tr,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => xpController.getPrizes(reload: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: prizes.length,
        itemBuilder: (context, index) {
          final prize = prizes[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PrizeCardWidget(
              prize: prize,
              isLoading: xpController.isClaimingPrizeId(prize.id),
              onClaim:
                  prize.canClaim
                      ? () => xpController.claimPrize(prize.id)
                      : null,
            ),
          );
        },
      ),
    );
  }
}
