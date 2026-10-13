/// Built-in destination knowledge base used by the rule-based recommender.
/// NOTE: daily costs are rough, illustrative per-person estimates in INR
/// (stay + food + local transport, excluding long-distance travel).
/// They are not live prices.
class Destination {
  final String name;
  final String country;
  final String emoji;
  final String description;
  final int dailyCost;
  final List<String> types;
  final int minDays;
  final int maxDays;
  final List<String> highlights;

  const Destination({
    required this.name,
    required this.country,
    required this.emoji,
    required this.description,
    required this.dailyCost,
    required this.types,
    required this.minDays,
    required this.maxDays,
    required this.highlights,
  });
}

const List<String> kTravelTypes = [
  'Beach',
  'Adventure',
  'Culture',
  'Nature',
  'Relaxation',
];

const List<Destination> kDestinations = [
  Destination(
    name: 'Goa',
    country: 'India',
    emoji: '🏖️',
    description: 'Sun, sand, Portuguese-era heritage and a relaxed coastal vibe.',
    dailyCost: 3500,
    types: ['Beach', 'Relaxation'],
    minDays: 3,
    maxDays: 6,
    highlights: ['Baga and Palolem beaches', 'Old Goa churches', 'Water sports'],
  ),
  Destination(
    name: 'Munnar',
    country: 'India',
    emoji: '🍃',
    description: 'Rolling tea estates and cool misty hills in the Western Ghats.',
    dailyCost: 2800,
    types: ['Nature', 'Relaxation'],
    minDays: 2,
    maxDays: 4,
    highlights: ['Tea plantations', 'Eravikulam National Park', 'Mattupetty Dam'],
  ),
  Destination(
    name: 'Jaipur',
    country: 'India',
    emoji: '🏰',
    description: 'The Pink City: forts, palaces and vibrant bazaars.',
    dailyCost: 3000,
    types: ['Culture'],
    minDays: 2,
    maxDays: 4,
    highlights: ['Amber Fort', 'City Palace', 'Johari Bazaar'],
  ),
  Destination(
    name: 'Manali',
    country: 'India',
    emoji: '🏔️',
    description: 'Himalayan valleys with trekking, snow activities and cafes.',
    dailyCost: 3200,
    types: ['Adventure', 'Nature'],
    minDays: 4,
    maxDays: 7,
    highlights: ['Solang Valley', 'Old Manali', 'Hadimba Temple'],
  ),
  Destination(
    name: 'Rishikesh',
    country: 'India',
    emoji: '🧘',
    description: 'Yoga capital on the Ganga with rafting and spiritual calm.',
    dailyCost: 2500,
    types: ['Adventure', 'Relaxation', 'Culture'],
    minDays: 3,
    maxDays: 5,
    highlights: ['River rafting', 'Ganga Aarti', 'Yoga ashrams'],
  ),
  Destination(
    name: 'Alleppey',
    country: 'India',
    emoji: '🛶',
    description: 'Slow backwater cruises through Kerala canals and villages.',
    dailyCost: 3500,
    types: ['Relaxation', 'Nature'],
    minDays: 2,
    maxDays: 3,
    highlights: ['Houseboat stay', 'Canoe village tour', 'Alappuzha beach'],
  ),
  Destination(
    name: 'Andaman Islands',
    country: 'India',
    emoji: '🏝️',
    description: 'Clear water, coral reefs and quiet island beaches.',
    dailyCost: 5000,
    types: ['Beach', 'Adventure', 'Nature'],
    minDays: 5,
    maxDays: 7,
    highlights: ['Havelock beaches', 'Scuba diving', 'Cellular Jail'],
  ),
  Destination(
    name: 'Varanasi',
    country: 'India',
    emoji: '🪔',
    description: 'One of the oldest living cities, centred on the Ganga ghats.',
    dailyCost: 2200,
    types: ['Culture'],
    minDays: 2,
    maxDays: 4,
    highlights: ['Evening Ganga Aarti', 'Dawn boat ride', 'Old city lanes'],
  ),
  Destination(
    name: 'Pondicherry',
    country: 'India',
    emoji: '🎨',
    description: 'French-colonial streets, seaside cafes and Auroville.',
    dailyCost: 3000,
    types: ['Beach', 'Culture', 'Relaxation'],
    minDays: 2,
    maxDays: 4,
    highlights: ['French Quarter', 'Auroville', 'Promenade Beach'],
  ),
  Destination(
    name: 'Hampi',
    country: 'India',
    emoji: '🗿',
    description: 'Ruins of the Vijayanagara empire among giant boulders.',
    dailyCost: 2000,
    types: ['Culture', 'Adventure'],
    minDays: 2,
    maxDays: 3,
    highlights: ['Virupaksha Temple', 'Vittala Temple', 'Boulder trails'],
  ),
  Destination(
    name: 'Leh-Ladakh',
    country: 'India',
    emoji: '🏞️',
    description: 'High-altitude desert, monasteries and dramatic road trips.',
    dailyCost: 4500,
    types: ['Adventure', 'Nature', 'Culture'],
    minDays: 6,
    maxDays: 9,
    highlights: ['Pangong Lake', 'Nubra Valley', 'Thiksey Monastery'],
  ),
  Destination(
    name: 'Darjeeling',
    country: 'India',
    emoji: '🚂',
    description: 'Tea gardens, toy train rides and Kanchenjunga sunrises.',
    dailyCost: 2800,
    types: ['Nature', 'Relaxation', 'Culture'],
    minDays: 3,
    maxDays: 5,
    highlights: ['Tiger Hill sunrise', 'Toy train', 'Tea estates'],
  ),
  Destination(
    name: 'Bali',
    country: 'Indonesia',
    emoji: '🌴',
    description: 'Beaches, temples, rice terraces and wellness retreats.',
    dailyCost: 6500,
    types: ['Beach', 'Culture', 'Relaxation', 'Adventure'],
    minDays: 5,
    maxDays: 8,
    highlights: ['Ubud rice terraces', 'Uluwatu temple', 'Surfing'],
  ),
  Destination(
    name: 'Phuket',
    country: 'Thailand',
    emoji: '⛵',
    description: 'Island hopping, snorkelling and lively beach towns.',
    dailyCost: 6000,
    types: ['Beach', 'Adventure'],
    minDays: 4,
    maxDays: 6,
    highlights: ['Phi Phi island tour', 'Snorkelling', 'Old Phuket Town'],
  ),
  Destination(
    name: 'Singapore',
    country: 'Singapore',
    emoji: '🌆',
    description: 'A clean, compact city mixing cultures, food and futuristic parks.',
    dailyCost: 12000,
    types: ['Culture'],
    minDays: 3,
    maxDays: 5,
    highlights: ['Gardens by the Bay', 'Hawker centres', 'Little India'],
  ),
];

/// Optional interests the traveller can pick in the planner and profile.
const List<String> kPreferences = [
  'Food & cuisine',
  'History & heritage',
  'Shopping',
  'Nightlife',
  'Photography',
  'Wildlife',
  'Trekking',
  'Water sports',
  'Spiritual',
  'Wellness & spa',
  'Family friendly',
];

/// Travel types that suit each interest (used by the rule-based engines).
const Map<String, List<String>> kPreferenceTypes = {
  'Food & cuisine': ['Culture', 'Beach'],
  'History & heritage': ['Culture'],
  'Shopping': ['Culture'],
  'Nightlife': ['Beach'],
  'Photography': ['Nature', 'Culture', 'Adventure'],
  'Wildlife': ['Nature'],
  'Trekking': ['Adventure', 'Nature'],
  'Water sports': ['Beach', 'Adventure'],
  'Spiritual': ['Culture', 'Relaxation'],
  'Wellness & spa': ['Relaxation'],
  'Family friendly': ['Beach', 'Nature', 'Relaxation'],
};

/// Shown in the "Popular destinations" strip on the dashboard.
const List<String> kPopularDestinationNames = [
  'Goa',
  'Manali',
  'Jaipur',
  'Munnar',
  'Andaman Islands',
  'Leh-Ladakh',
  'Varanasi',
  'Bali',
];
