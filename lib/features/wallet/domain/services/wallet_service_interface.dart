import 'package:waddy_app/common/models/transaction_model.dart';
import 'package:waddy_app/features/wallet/domain/models/fund_bonus_model.dart';

abstract class WalletServiceInterface {
  Future<TransactionModel?> getWalletTransactionList(
    String offset,
    String sortingType,
  );
  Future<dynamic> addFundToWallet(double amount, String paymentMethod);
  Future<List<FundBonusModel>?> getWalletBonusList();
  Future<void> setWalletAccessToken(String token);
  String getWalletAccessToken();
  Future<void> setCardAppearance(int index);
  int getCardAppearance();
  Future<void> setCardSymbol(int index);
  int getCardSymbol();
}
