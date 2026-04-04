import '../models/pet.dart';

double calculatePetCompatibility(Pet pet1, Pet pet2) {
  double score = 0;
  double maxScore = 0;

  maxScore += 25;
  score += 25 * (1 - (pet1.energyLevel - pet2.energyLevel).abs());

  maxScore += 25;
  final minSocial = pet1.socialComfort < pet2.socialComfort
      ? pet1.socialComfort
      : pet2.socialComfort;
  score += 25 * minSocial;

  maxScore += 25;
  final commonStyles =
      pet1.playStyles.where((s) => pet2.playStyles.contains(s)).length;
  final totalStyles = {...pet1.playStyles, ...pet2.playStyles}.length;
  if (totalStyles > 0) {
    score += 25 * (commonStyles / totalStyles);
  }

  maxScore += 25;
  score += 25 * ((pet1.sizeTolerance + pet2.sizeTolerance) / 2);

  return (score / maxScore * 100).clamp(0, 100);
}
