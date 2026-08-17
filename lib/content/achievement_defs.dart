/// A snapshot of the game stats achievements are evaluated against. Built once
/// per evaluation by GameLogic so the (data-driven) achievement conditions stay
/// pure functions of state.
class AchStats {
  final double lifetimeEarnings;
  final double lifetimeEverSats; // cosmetic cumulative-ever mined (all eras)
  final bool hasWonGame; // THE LAST SATOSHI: mined a full 21M in one era
  final double totalGovTokensEver;
  final int govTokens;
  final int consensus;
  final int genesisBlocks;
  final int totalRigs;
  final int rigTypesOwned;
  final int rigTypesTotal;
  final int researchCompleted;
  final int researchTotal;
  final int perkLevels;
  final int stashDiscovered;
  final int stashTotal;
  final int chips;
  final int hardForkCount;
  final int softForkCount;
  final int newChainCount;
  final int cratesOpened;
  final int casinoSpins;
  final int casinoJackpots;
  final int eraHalvings; // halvings survived this era (derived from block reward)
  final double globalHashRate;
  final double prestigeMultiplier;
  final int achievementsUnlocked; // for meta ("unlock N achievements")
  final bool Function(String id) ownsArtifact;
  // RPG classes / Mastery + endgame (Phase 6 role achievements).
  final int totalMasteryLevel;
  final int masteredClassCount; // real classes at Mastery >= 1
  final int Function(String className) classMasteryLevel;
  // Back in Time (post-win timed re-mine): best completed time in ms, 0 = none.
  final int speedRunBestMs;
  // How many distinct real classes have a recorded Back-in-Time best (for THE
  // TIMECHAIN capstone).
  final int speedRunClassCount;

  const AchStats({
    required this.lifetimeEarnings,
    required this.lifetimeEverSats,
    required this.hasWonGame,
    required this.totalGovTokensEver,
    required this.govTokens,
    required this.consensus,
    required this.genesisBlocks,
    required this.totalRigs,
    required this.rigTypesOwned,
    required this.rigTypesTotal,
    required this.researchCompleted,
    required this.researchTotal,
    required this.perkLevels,
    required this.stashDiscovered,
    required this.stashTotal,
    required this.chips,
    required this.hardForkCount,
    required this.softForkCount,
    required this.newChainCount,
    required this.cratesOpened,
    required this.casinoSpins,
    required this.casinoJackpots,
    required this.eraHalvings,
    required this.globalHashRate,
    required this.prestigeMultiplier,
    required this.achievementsUnlocked,
    required this.ownsArtifact,
    required this.totalMasteryLevel,
    required this.masteredClassCount,
    required this.classMasteryLevel,
    required this.speedRunBestMs,
    required this.speedRunClassCount,
  });
}

enum AchCategory { earnings, rigs, tech, prestige, collection, meta, secret }

/// A single achievement. [secret] ones are hidden ("???") until earned and grant
/// NO Notoriety (cosmetic only); normal ones each grant Notoriety (a small
/// permanent income bonus, its own lane away from the SKILL/TECH power budget).
class Achievement {
  final String id;
  final String title;
  final String description;
  final AchCategory category;
  final bool secret;
  final bool Function(AchStats s) condition;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.condition,
    this.secret = false,
  });
}

/// The achievement catalogue. Adding one is a single data entry. Conditions are
/// pure functions of [AchStats]. Tiered against actions players already take
/// (anti-grind), per the design plan.
final List<Achievement> kAchievements = [
  // --- Earnings ladder ---
  Achievement(
    id: 'earn_1m',
    title: 'First Satoshis',
    description: 'Mine 1M sats in total.',
    category: AchCategory.earnings,
    condition: (s) => s.lifetimeEarnings >= 1e6,
  ),
  Achievement(
    id: 'earn_1b',
    title: 'Millionaire',
    description: 'Mine 1B sats in total.',
    category: AchCategory.earnings,
    condition: (s) => s.lifetimeEarnings >= 1e9,
  ),
  Achievement(
    id: 'earn_1t',
    title: 'Whale',
    description: 'Mine 1T sats in total.',
    category: AchCategory.earnings,
    condition: (s) => s.lifetimeEarnings >= 1e12,
  ),
  Achievement(
    id: 'earn_100t',
    title: 'Bitcoin Baron',
    description: 'Mine 100T sats in total.',
    category: AchCategory.earnings,
    condition: (s) => s.lifetimeEarnings >= 1e14,
  ),

  // --- Rigs ---
  Achievement(
    id: 'rigs_10',
    title: 'Rig Up',
    description: 'Own 10 mining rigs.',
    category: AchCategory.rigs,
    condition: (s) => s.totalRigs >= 10,
  ),
  Achievement(
    id: 'rigs_100',
    title: 'Mining Farm',
    description: 'Own 100 mining rigs.',
    category: AchCategory.rigs,
    condition: (s) => s.totalRigs >= 100,
  ),
  Achievement(
    id: 'rigs_500',
    title: 'Hash Center',
    description: 'Own 500 mining rigs.',
    category: AchCategory.rigs,
    condition: (s) => s.totalRigs >= 500,
  ),
  Achievement(
    id: 'rigs_alltypes',
    title: 'Diversified',
    description: 'Own at least one of every rig type.',
    category: AchCategory.rigs,
    condition: (s) => s.rigTypesOwned >= s.rigTypesTotal,
  ),

  // --- Tech (tech tree / SKILL) ---
  Achievement(
    id: 'lab_5',
    title: 'Overclocked',
    description: 'Complete 5 tech researches.',
    category: AchCategory.tech,
    condition: (s) => s.researchCompleted >= 5,
  ),
  Achievement(
    id: 'lab_all',
    title: 'Mad Scientist',
    description: 'Complete the entire tech tree.',
    category: AchCategory.tech,
    condition: (s) => s.researchTotal > 0 && s.researchCompleted >= s.researchTotal,
  ),
  Achievement(
    id: 'perks_10',
    title: 'Well Invested',
    description: 'Buy 10 Skill levels.',
    category: AchCategory.tech,
    condition: (s) => s.perkLevels >= 10,
  ),

  // --- Prestige tiers ---
  Achievement(
    id: 'soft_first',
    title: 'Consensus Reached',
    description: 'Perform your first Soft Fork.',
    category: AchCategory.prestige,
    condition: (s) => s.softForkCount >= 1,
  ),
  Achievement(
    id: 'consensus_50',
    title: 'Community Leader',
    description: 'Accumulate 50 Consensus.',
    category: AchCategory.prestige,
    condition: (s) => s.consensus >= 50,
  ),
  Achievement(
    id: 'hard_first',
    title: 'Hard Forker',
    description: 'Perform your first Hard Fork.',
    category: AchCategory.prestige,
    condition: (s) => s.hardForkCount >= 1,
  ),
  Achievement(
    id: 'gov_100',
    title: 'Governor',
    description: 'Mint 100 GovTokens in total.',
    category: AchCategory.prestige,
    condition: (s) => s.totalGovTokensEver >= 100,
  ),
  Achievement(
    id: 'hard_10',
    title: 'Chain Splitter',
    description: 'Perform 10 Hard Forks.',
    category: AchCategory.prestige,
    condition: (s) => s.hardForkCount >= 10,
  ),
  Achievement(
    id: 'chain_first',
    title: 'Genesis',
    description: 'Start your first New Blockchain.',
    category: AchCategory.prestige,
    condition: (s) => s.newChainCount >= 1 || s.genesisBlocks >= 1,
  ),
  Achievement(
    id: 'genesis_5',
    title: 'Protocol Architect',
    description: 'Hold 5 Genesis Blocks.',
    category: AchCategory.prestige,
    condition: (s) => s.genesisBlocks >= 5,
  ),

  // --- Collection (stash / crates / UTXO) ---
  Achievement(
    id: 'stash_10',
    title: 'Collector',
    description: 'Discover 10 stash artifacts.',
    category: AchCategory.collection,
    condition: (s) => s.stashDiscovered >= 10,
  ),
  Achievement(
    id: 'stash_30',
    title: 'Curator',
    description: 'Discover 30 stash artifacts.',
    category: AchCategory.collection,
    condition: (s) => s.stashDiscovered >= 30,
  ),
  Achievement(
    id: 'stash_all',
    title: 'Completionist',
    description: 'Discover every stash artifact.',
    category: AchCategory.collection,
    condition: (s) => s.stashTotal > 0 && s.stashDiscovered >= s.stashTotal,
  ),
  Achievement(
    id: 'crates_25',
    title: 'Lootboxer',
    description: 'Open 25 supply crates.',
    category: AchCategory.collection,
    condition: (s) => s.cratesOpened >= 25,
  ),
  Achievement(
    id: 'chips_5',
    title: 'Bug Hunter',
    description: 'Hold 5 UTXO.',
    category: AchCategory.collection,
    condition: (s) => s.chips >= 5,
  ),
  Achievement(
    id: 'casino_25',
    title: 'Feeling Lucky',
    description: 'Run 25 chain sweeps.',
    category: AchCategory.collection,
    condition: (s) => s.casinoSpins >= 25,
  ),

  // --- Meta ---
  Achievement(
    id: 'meta_20',
    title: 'Renowned',
    description: 'Unlock 20 achievements.',
    category: AchCategory.meta,
    condition: (s) => s.achievementsUnlocked >= 20,
  ),

  // --- Volume expansion 2: deeper ladders ---
  Achievement(
    id: 'earn_1q',
    title: 'Quadrillionaire',
    // 1 quadrillion (1e15) — below the 2.1e15 per-era cap so it is actually
    // reachable in a single era (lifetimeEarnings resets each prestige). The
    // previous 1e16 exceeded the cap and could never unlock.
    description: 'Mine 1Q sats in total.',
    category: AchCategory.earnings,
    condition: (s) => s.lifetimeEarnings >= 1e15,
  ),
  Achievement(
    id: 'rigs_1000',
    title: 'Hash Empire',
    description: 'Own 1000 mining rigs.',
    category: AchCategory.rigs,
    condition: (s) => s.totalRigs >= 1000,
  ),
  Achievement(
    id: 'perks_50',
    title: 'Fully Upgraded',
    description: 'Buy 50 Skill levels.',
    category: AchCategory.tech,
    condition: (s) => s.perkLevels >= 50,
  ),
  Achievement(
    id: 'consensus_500',
    title: 'Supermajority',
    description: 'Accumulate 500 Consensus.',
    category: AchCategory.prestige,
    condition: (s) => s.consensus >= 500,
  ),
  Achievement(
    id: 'hard_50',
    title: 'Fork Lord',
    description: 'Perform 50 Hard Forks.',
    category: AchCategory.prestige,
    condition: (s) => s.hardForkCount >= 50,
  ),
  Achievement(
    id: 'gov_1000',
    title: 'Central Banker',
    description: 'Mint 1000 GovTokens in total.',
    category: AchCategory.prestige,
    condition: (s) => s.totalGovTokensEver >= 1000,
  ),
  Achievement(
    id: 'chain_5',
    title: 'Serial Rebooter',
    description: 'Start 5 New Blockchains.',
    category: AchCategory.prestige,
    condition: (s) => s.newChainCount >= 5,
  ),
  Achievement(
    id: 'crates_100',
    title: 'Whale Watcher',
    description: 'Open 100 supply crates.',
    category: AchCategory.collection,
    condition: (s) => s.cratesOpened >= 100,
  ),
  Achievement(
    id: 'casino_250',
    title: 'High Roller',
    description: 'Run 250 chain sweeps.',
    category: AchCategory.collection,
    condition: (s) => s.casinoSpins >= 250,
  ),
  Achievement(
    id: 'meta_40',
    title: 'Living Legend',
    description: 'Unlock 40 achievements.',
    category: AchCategory.meta,
    condition: (s) => s.achievementsUnlocked >= 40,
  ),
  Achievement(
    id: 'meta_genesis_complete',
    title: 'The Last Satoshi',
    // The true ending: mine one whole 21,000,000-coin supply within a single
    // era — every satoshi that will ever exist, in one run.
    description: 'Mine a full 21,000,000 BTC in one era — the true ending.',
    category: AchCategory.meta,
    condition: (s) => s.hasWonGame,
  ),

  // --- RPG classes / Mastery (the "play them all" hook) ---
  Achievement(
    id: 'class_first',
    title: 'Specialist',
    description: 'Master a class for the first time (finish a chain as a class).',
    category: AchCategory.prestige,
    condition: (s) => s.masteredClassCount >= 1,
  ),
  Achievement(
    id: 'mastery_solo',
    title: 'Garage Legend',
    description: 'Reach Mastery 3 as the Solo Miner.',
    category: AchCategory.prestige,
    condition: (s) => s.classMasteryLevel('soloMiner') >= 3,
  ),
  Achievement(
    id: 'mastery_corp',
    title: 'Boardroom Boss',
    description: 'Reach Mastery 3 as the Corporation.',
    category: AchCategory.prestige,
    condition: (s) => s.classMasteryLevel('corporation') >= 3,
  ),
  Achievement(
    id: 'mastery_og',
    title: "Satoshi's Heir",
    description: 'Reach Mastery 3 as the BTC OG.',
    category: AchCategory.prestige,
    condition: (s) => s.classMasteryLevel('btcOg') >= 3,
  ),
  Achievement(
    id: 'mastery_pool',
    title: 'Better Together',
    description: 'Reach Mastery 3 as the Pool Member.',
    category: AchCategory.prestige,
    condition: (s) => s.classMasteryLevel('poolMember') >= 3,
  ),
  Achievement(
    id: 'class_all',
    title: 'Jack of All Chains',
    description: 'Master all four classes (Mastery 1+ in each).',
    category: AchCategory.meta,
    condition: (s) => s.masteredClassCount >= 4,
  ),
  Achievement(
    id: 'ng_plus',
    title: 'Back in Time',
    description: 'Complete a Back in Time run after winning the game.',
    category: AchCategory.prestige,
    condition: (s) => s.speedRunBestMs > 0,
  ),
  // Time-medal ladder off the best Back-in-Time completion (Blitz <1h is secret,
  // below): Silver < 2h, plus the Satoshi sprint < 30m (secret).
  Achievement(
    id: 'speedrun_silver',
    title: 'Silver Timechain',
    description: 'Re-mine all 21M in under 2 hours, Back in Time.',
    category: AchCategory.prestige,
    condition: (s) => s.speedRunBestMs > 0 && s.speedRunBestMs < 7200000,
  ),
  // THE TIMECHAIN capstone: a recorded Back-in-Time best as all four classes.
  Achievement(
    id: 'the_timechain',
    title: 'The Timechain',
    description: 'Record a Back in Time time as all four classes.',
    category: AchCategory.meta,
    condition: (s) => s.speedRunClassCount >= 4,
  ),

  // --- Secret / endgame ---
  Achievement(
    id: 'secret_sandbox',
    title: 'Blitz of the Blocks',
    description: 'Re-mine all 21,000,000 in under an hour, Back in Time.',
    category: AchCategory.secret,
    secret: true,
    // 0 = never completed; only a real sub-hour record trips this.
    condition: (s) => s.speedRunBestMs > 0 && s.speedRunBestMs < 3600000,
  ),
  Achievement(
    id: 'speedrun_satoshi',
    title: 'Satoshi Sprint',
    description: 'Re-mine all 21,000,000 in under 30 minutes, Back in Time.',
    category: AchCategory.secret,
    secret: true,
    condition: (s) => s.speedRunBestMs > 0 && s.speedRunBestMs < 1800000,
  ),

  // --- Secret / shadow (no Notoriety, hidden until earned) ---
  Achievement(
    id: 'secret_pizza',
    title: 'Bitcoin Pizza',
    description: 'Everyone starts somewhere. (Mine 10,000 sats.)',
    category: AchCategory.secret,
    secret: true,
    condition: (s) => s.lifetimeEarnings >= 1e4,
  ),
  Achievement(
    id: 'secret_diamond',
    title: 'Diamond Hands',
    description: 'Hold through 3 halvings in a single era.',
    category: AchCategory.secret,
    secret: true,
    condition: (s) => s.eraHalvings >= 3,
  ),
  Achievement(
    id: 'secret_moon',
    title: 'To The Moon',
    description: 'Reach 1 GH/s of hash rate.',
    category: AchCategory.secret,
    secret: true,
    condition: (s) => s.globalHashRate >= 1e9,
  ),
  Achievement(
    id: 'secret_ngu',
    title: 'Number Go Up',
    description: 'Reach a x10 prestige multiplier.',
    category: AchCategory.secret,
    secret: true,
    condition: (s) => s.prestigeMultiplier >= 10,
  ),
  Achievement(
    id: 'secret_satoshi',
    title: "Satoshi's Ghost",
    description: 'Possess the legendary Whitepaper.',
    category: AchCategory.secret,
    secret: true,
    condition: (s) => s.ownsArtifact('satoshi_whitepaper'),
  ),
  Achievement(
    id: 'secret_hodl',
    title: 'HODL',
    description: 'Survive 5 halvings in a single era.',
    category: AchCategory.secret,
    secret: true,
    condition: (s) => s.eraHalvings >= 5,
  ),
  Achievement(
    id: 'secret_prophet',
    title: 'Genesis Prophet',
    description: 'Hold 10 Genesis Blocks.',
    category: AchCategory.secret,
    secret: true,
    condition: (s) => s.genesisBlocks >= 10,
  ),
  Achievement(
    id: 'secret_jackpot',
    title: 'Jackpot!',
    description: 'Hit a jackpot in the SWEEP.',
    category: AchCategory.secret,
    secret: true,
    condition: (s) => s.casinoJackpots >= 1,
  ),
  Achievement(
    id: 'secret_ascended',
    title: 'Ascended',
    description: 'Command 25 Genesis Blocks.',
    category: AchCategory.secret,
    secret: true,
    condition: (s) => s.genesisBlocks >= 25,
  ),
  Achievement(
    id: 'secret_gigachad',
    title: 'Gigachad',
    description: 'Reach a x1000 prestige multiplier.',
    category: AchCategory.secret,
    secret: true,
    condition: (s) => s.prestigeMultiplier >= 1000,
  ),
  Achievement(
    id: 'secret_fullnode',
    title: 'Full Node',
    description: 'Max the tech tree and own every rig type at once.',
    category: AchCategory.secret,
    secret: true,
    condition: (s) =>
        s.researchTotal > 0 &&
        s.researchCompleted >= s.researchTotal &&
        s.rigTypesOwned >= s.rigTypesTotal,
  ),
];
