import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../config/theme.dart';

class PizzaCommitmentWidget extends StatelessWidget {
  final bool willProvidePizza;
  final bool willProvideDrinks;
  final bool willAccommodateAllergies;
  final bool acknowledgesHostDuty;
  final ValueChanged<bool> onPizzaChanged;
  final ValueChanged<bool> onDrinksChanged;
  final ValueChanged<bool> onAllergiesChanged;
  final ValueChanged<bool> onHostDutyChanged;

  const PizzaCommitmentWidget({
    super.key,
    required this.willProvidePizza,
    required this.willProvideDrinks,
    required this.willAccommodateAllergies,
    required this.acknowledgesHostDuty,
    required this.onPizzaChanged,
    required this.onDrinksChanged,
    required this.onAllergiesChanged,
    required this.onHostDutyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final allChecked = willProvidePizza &&
        willProvideDrinks &&
        willAccommodateAllergies &&
        acknowledgesHostDuty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: allChecked
              ? PawPartyColors.success.withValues(alpha: 0.5)
              : PawPartyColors.divider,
          width: allChecked ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            allChecked ? Icons.check_circle : Icons.local_pizza,
            size: 48,
            color: allChecked ? PawPartyColors.success : PawPartyColors.pizzaGold,
          ),
          const SizedBox(height: 12),
          Text(
            allChecked ? 'You\'re all set!' : 'The host promise',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: allChecked ? PawPartyColors.success : PawPartyColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Every ${AppConstants.appName} host commits to:',
            style: TextStyle(
              fontSize: 13,
              color: PawPartyColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          _commitmentCheckbox(
            'I will provide pizza for all guests',
            Icons.local_pizza,
            willProvidePizza,
            onPizzaChanged,
          ),
          const SizedBox(height: 10),
          _commitmentCheckbox(
            'I will provide drinks (soda, water, juice)',
            Icons.local_drink,
            willProvideDrinks,
            onDrinksChanged,
          ),
          const SizedBox(height: 10),
          _commitmentCheckbox(
            'I will ask about food allergies beforehand',
            Icons.health_and_safety,
            willAccommodateAllergies,
            onAllergiesChanged,
          ),
          const SizedBox(height: 10),
          _commitmentCheckbox(
            'I understand I\'m responsible for a safe, welcoming environment',
            Icons.shield,
            acknowledgesHostDuty,
            onHostDutyChanged,
          ),
        ],
      ),
    );
  }

  Widget _commitmentCheckbox(
    String label,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: value
              ? PawPartyColors.success.withValues(alpha: 0.05)
              : PawPartyColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value
                ? PawPartyColors.success.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: value
                    ? PawPartyColors.success
                    : PawPartyColors.divider,
                shape: BoxShape.circle,
              ),
              child: value
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                  color: value
                      ? PawPartyColors.textPrimary
                      : PawPartyColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
