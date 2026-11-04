enum GunKind { pistol, rifle, shotgun }

class GunSpec {
  const GunSpec(
    this.name,
    this.magazine,
    this.reserveCap,
    this.damage,
    this.interval,
    this.reloadSeconds,
    this.range,
    this.speed, {
    this.pellets = 1,
    this.spread = 0,
  });
  final String name;
  final int magazine, reserveCap, pellets;
  final double damage, interval, reloadSeconds, range, speed, spread;
  static const all = [
    GunSpec('SÚNG LỤC', 12, 96, 32, .34, 1.05, 480, 1050),
    GunSpec('SÚNG TRƯỜNG', 24, 180, 28, .18, 1.65, 800, 950),
    GunSpec('SHOTGUN', 6, 36, 10, .9, 2.2, 330, 850, pellets: 8, spread: .22),
  ];
  static GunSpec of(GunKind kind) => all[kind.index];
}

class GunSlot {
  GunSlot({this.owned = false, this.ammo = 0, this.reserve = 0});
  bool owned;
  int ammo, reserve;
}
