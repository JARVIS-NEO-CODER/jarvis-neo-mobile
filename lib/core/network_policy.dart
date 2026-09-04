class NetworkPolicy {
  bool cloudAllowed = true;
  bool localPreferred = false;
  bool sentSensitiveDataToCloud = false;
  bool canUseCloud({required bool sensitive}) => cloudAllowed && (!sensitive || sentSensitiveDataToCloud);
}
