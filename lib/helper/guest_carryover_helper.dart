/// Runs at the moment a guest becomes a logged-in user (any soft-sheet login).
///
/// This used to repair the damage done by the browsing seed: a guest browsed
/// on a fabricated Maadi address, so at login we had to detect that and swap
/// in their real coordinates before the fake one was persisted to the account.
///
/// The seed is gone. The saved address is now always a real place — where the
/// user is, or somewhere they deliberately picked — and its zoneIds already
/// say whether we serve it. There is nothing left to carry over, so this is
/// intentionally a no-op, kept as a named hook because login calls it and the
/// name documents why no correction is needed.
class GuestCarryover {
  GuestCarryover._();

  static Future<void> onLogin() async {}
}
