import '../models/news_event.dart';

/// Flavour text for the top ticker. Purely cosmetic crypto-culture jokes for the
/// idle stream, plus per-event-type message pools so the same buff/debuff reads
/// differently each time it fires.
class NewsFlavor {
  /// Rotating idle headlines (no gameplay effect). Keep them short & funny.
  static const List<String> idle = [
    "Elon tweeted a dog again.",
    "Whale wallet moved 1 sat — analysts baffled.",
    "'This time it's different,' says everyone.",
    "Grandma bought the top. Again.",
    "Diamond hands trending on ChainTok.",
    "Mempool congested with cat JPEGs.",
    "Fed prints more — number go up, probably.",
    "Laser eyes detected on 4 new profile pics.",
    "Someone paid 10,000 BTC for a pizza. Ouch.",
    "GPU prices up 300%; gamers riot.",
    "New all-time high in unread whitepapers.",
    "'HODL' officially added to the dictionary.",
    "Miner finds block, forgets wallet password.",
    "Rug pull rug-pulled by a bigger rug.",
    "Stablecoin briefly unstable, then re-stable.",
    "Regulators 'looking into it', as usual.",
    "Anon predicts \$1M. Also predicted \$0.",
    "DeFi protocol audited by a guy named Chad.",
    "NFT of this headline sold for 3 ETH.",
    "Satoshi still anonymous, still rich.",
    "Hash rate up; electricity bill up more.",
    "Trader touches grass, immediately regrets it.",
    "Exchange 'temporarily' pauses withdrawals.",
    "Cat walks on keyboard, accidentally forks chain.",
    "Metaverse land now 90% off.",
    "'Not financial advice' — famous last words.",
    "Quantum computer threatens crypto, busy playing solitaire.",
    "Halving countdown: soon™.",
    "Meme coin overtakes GDP of small nation.",
    "Influencer deletes tweet; price recovers.",
    "Blockchain confirmed to be a chain of blocks.",
    "Wen moon? Analysts say: yes.",
    "Dev pushes to prod on a Friday. Chaos ensues.",
    "Local maxi explains Bitcoin at dinner, uninvited next year.",
    "Cold wallet lost in a landfill; search continues.",
    "Bull market vibes: unconfirmed but strongly felt.",
    "Small nation adopts BTC as legal tender.",
    "Lightning Network now faster than your ex's replies.",
  ];

  /// Message variants per event type — triggerRandom picks one at random.
  static const Map<EventType, List<String>> byType = {
    EventType.bullRun: [
      "BULL RUN: Institutional investors entering!",
      "MOON MISSION: retail FOMO in full swing!",
      "GREEN CANDLES as far as the eye can see!",
      "Whales accumulating — suddenly everyone's a genius!",
      "PUMP INCOMING: 'few understand this,' they post.",
    ],
    EventType.marketCrash: [
      "MARKET CRASH: panic sellers flooding the market.",
      "RED WEDDING: over-leveraged traders liquidated.",
      "FUD STORM tanks sentiment across the board.",
      "'It's just a dip,' they whisper, sweating.",
      "BLOOD IN THE STREETS: portfolios in shambles.",
    ],
    EventType.hack: [
      "SECURITY BREACH: hot wallet compromised!",
      "PHISHING ATTACK drains the careless.",
      "EXCHANGE HACKED — again. Shocking no one.",
      "RUG PULL! The devs have vanished with the funds.",
      "PRIVATE KEY LEAKED on a screenshot. Classic.",
    ],
    EventType.cheapEnergy: [
      "Surplus energy: electricity is dirt cheap.",
      "Solar boom slashes mining costs.",
      "Government briefly subsidizes miners.",
      "Geothermal plant online — rigs run cheap.",
      "Off-peak rates: mine now, pay later.",
    ],
    EventType.costSpike: [
      "ENERGY CRISIS: grid prices spike — rigs cost a fortune.",
      "Heatwave: cooling bills through the roof.",
      "Chip shortage — hardware markups everywhere.",
      "Grid operator hikes rates; miners groan.",
      "Peak demand: every watt now premium-priced.",
    ],
    EventType.airdrop: [
      "AIRDROP! A forgotten wallet resurfaces in your name.",
      "DUST SWEEP: stray UTXOs consolidate into your wallet.",
      "Faucet glitch pays out — finders keepers.",
      "Old cold wallet cracked open — jackpot in sats!",
      "Someone fat-fingered a transfer. Straight to your address.",
    ],
  };
}
