require "./schema"

module Lxpen
  module Patterns
    module FrequencyData
      PATTERNS = [
        # Single slot
        Pattern.new("lower_only", [Slot.new(SlotType::LowerWord)], 0.118),
        Pattern.new("digits_only", [Slot.new(SlotType::SeqDigits)], 0.038),
        Pattern.new("keyboard_only", [Slot.new(SlotType::Keyboard)], 0.019),
        Pattern.new("name_only", [Slot.new(SlotType::Name)], 0.025),
        Pattern.new("cap_only", [Slot.new(SlotType::CapWord)], 0.020),

        # Word + digits
        Pattern.new("lower_digits", [Slot.new(SlotType::LowerWord), Slot.new(SlotType::SeqDigits)], 0.224),
        Pattern.new("cap_digits", [Slot.new(SlotType::CapWord), Slot.new(SlotType::SeqDigits)], 0.141),
        Pattern.new("upper_digits", [Slot.new(SlotType::UpperWord), Slot.new(SlotType::SeqDigits)], 0.018),
        Pattern.new("name_digits", [Slot.new(SlotType::Name), Slot.new(SlotType::SeqDigits)], 0.062),
        Pattern.new("cap_name_digits", [Slot.new(SlotType::CapName), Slot.new(SlotType::SeqDigits)], 0.045),

        # Word + year
        Pattern.new("lower_year", [Slot.new(SlotType::LowerWord), Slot.new(SlotType::Year)], 0.089),
        Pattern.new("name_year", [Slot.new(SlotType::Name), Slot.new(SlotType::Year)], 0.072),
        Pattern.new("cap_name_year", [Slot.new(SlotType::CapName), Slot.new(SlotType::Year)], 0.048),
        Pattern.new("cap_word_year", [Slot.new(SlotType::CapWord), Slot.new(SlotType::Year)], 0.040),
        Pattern.new("upper_year", [Slot.new(SlotType::UpperWord), Slot.new(SlotType::Year)], 0.012),

        # Word + digits + symbol
        Pattern.new("lower_digits_sym", [Slot.new(SlotType::LowerWord), Slot.new(SlotType::SeqDigits), Slot.new(SlotType::SymbolSuffix)], 0.035),
        Pattern.new("name_digits_sym", [Slot.new(SlotType::Name), Slot.new(SlotType::SeqDigits), Slot.new(SlotType::SymbolSuffix)], 0.058),
        Pattern.new("cap_digits_sym", [Slot.new(SlotType::CapWord), Slot.new(SlotType::SeqDigits), Slot.new(SlotType::SymbolSuffix)], 0.032),
        Pattern.new("cap_name_digits_sym", [Slot.new(SlotType::CapName), Slot.new(SlotType::SeqDigits), Slot.new(SlotType::SymbolSuffix)], 0.028),

        # Word + year + symbol
        Pattern.new("cap_year_sym", [Slot.new(SlotType::CapWord), Slot.new(SlotType::Year), Slot.new(SlotType::SymbolSuffix)], 0.047),
        Pattern.new("name_year_sym", [Slot.new(SlotType::Name), Slot.new(SlotType::Year), Slot.new(SlotType::SymbolSuffix)], 0.031),
        Pattern.new("cap_name_year_sym", [Slot.new(SlotType::CapName), Slot.new(SlotType::Year), Slot.new(SlotType::SymbolSuffix)], 0.025),
        Pattern.new("lower_year_sym", [Slot.new(SlotType::LowerWord), Slot.new(SlotType::Year), Slot.new(SlotType::SymbolSuffix)], 0.022),

        # Keyboard combos
        Pattern.new("keyboard_digits", [Slot.new(SlotType::Keyboard), Slot.new(SlotType::SeqDigits)], 0.041),
        Pattern.new("keyboard_sym", [Slot.new(SlotType::Keyboard), Slot.new(SlotType::SymbolSuffix)], 0.010),

        # L33t speak
        Pattern.new("l33t_digits", [Slot.new(SlotType::L33t), Slot.new(SlotType::SeqDigits)], 0.024),
        Pattern.new("l33t_only", [Slot.new(SlotType::L33t)], 0.015),
        Pattern.new("l33t_sym", [Slot.new(SlotType::L33t), Slot.new(SlotType::SymbolSuffix)], 0.012),
        Pattern.new("l33t_digits_sym", [Slot.new(SlotType::L33t), Slot.new(SlotType::SeqDigits), Slot.new(SlotType::SymbolSuffix)], 0.010),

        # Digits + word (reversed order)
        Pattern.new("digits_lower", [Slot.new(SlotType::SeqDigits), Slot.new(SlotType::LowerWord)], 0.016),
        Pattern.new("digits_cap", [Slot.new(SlotType::SeqDigits), Slot.new(SlotType::CapWord)], 0.011),
        Pattern.new("year_name", [Slot.new(SlotType::Year), Slot.new(SlotType::Name)], 0.009),

        # Symbol prefix
        Pattern.new("sym_lower_digits", [Slot.new(SlotType::SymbolSuffix), Slot.new(SlotType::LowerWord), Slot.new(SlotType::SeqDigits)], 0.008),
        Pattern.new("sym_cap_digits", [Slot.new(SlotType::SymbolSuffix), Slot.new(SlotType::CapWord), Slot.new(SlotType::SeqDigits)], 0.006),

        # Double word
        Pattern.new("lower_lower", [Slot.new(SlotType::LowerWord), Slot.new(SlotType::LowerWord)], 0.014),
        Pattern.new("name_name", [Slot.new(SlotType::Name), Slot.new(SlotType::Name)], 0.008),

        # Passphrases (multi-word)
        Pattern.new("lower_lower_lower", [Slot.new(SlotType::LowerWord), Slot.new(SlotType::LowerWord), Slot.new(SlotType::LowerWord)], 0.004),
        Pattern.new("cap_cap_cap", [Slot.new(SlotType::CapWord), Slot.new(SlotType::CapWord), Slot.new(SlotType::CapWord)], 0.002),
        Pattern.new("name_name_name", [Slot.new(SlotType::Name), Slot.new(SlotType::Name), Slot.new(SlotType::Name)], 0.001),

        # Name + word combos
        Pattern.new("name_lower_digits", [Slot.new(SlotType::Name), Slot.new(SlotType::LowerWord), Slot.new(SlotType::SeqDigits)], 0.006),

        # Capitalized l33t
        Pattern.new("capl33t_digits", [Slot.new(SlotType::CapL33t), Slot.new(SlotType::SeqDigits)], 0.018),
        Pattern.new("capl33t_only", [Slot.new(SlotType::CapL33t)], 0.010),
        Pattern.new("capl33t_sym", [Slot.new(SlotType::CapL33t), Slot.new(SlotType::SymbolSuffix)], 0.008),
        Pattern.new("capl33t_digits_sym", [Slot.new(SlotType::CapL33t), Slot.new(SlotType::SeqDigits), Slot.new(SlotType::SymbolSuffix)], 0.006),

        # L33t + year
        Pattern.new("l33t_year", [Slot.new(SlotType::L33t), Slot.new(SlotType::Year)], 0.010),
        Pattern.new("l33t_year_sym", [Slot.new(SlotType::L33t), Slot.new(SlotType::Year), Slot.new(SlotType::SymbolSuffix)], 0.006),
        Pattern.new("capl33t_year", [Slot.new(SlotType::CapL33t), Slot.new(SlotType::Year)], 0.008),
        Pattern.new("capl33t_year_sym", [Slot.new(SlotType::CapL33t), Slot.new(SlotType::Year), Slot.new(SlotType::SymbolSuffix)], 0.005),
      ]

      LOWER_WORDS = [
        # Top common passwords
        SlotEntry.new("password", 0.032), SlotEntry.new("dragon", 0.011),
        SlotEntry.new("master", 0.010), SlotEntry.new("monkey", 0.009),
        SlotEntry.new("shadow", 0.008), SlotEntry.new("sunshine", 0.007),
        SlotEntry.new("princess", 0.007), SlotEntry.new("football", 0.006),
        SlotEntry.new("charlie", 0.006), SlotEntry.new("welcome", 0.005),
        SlotEntry.new("michael", 0.005), SlotEntry.new("daniel", 0.005),
        SlotEntry.new("love", 0.005), SlotEntry.new("summer", 0.004),
        SlotEntry.new("soccer", 0.004), SlotEntry.new("batman", 0.004),
        SlotEntry.new("hunter", 0.004), SlotEntry.new("trustno", 0.003),
        SlotEntry.new("killer", 0.003), SlotEntry.new("jordan", 0.003),
        SlotEntry.new("robert", 0.003), SlotEntry.new("pepper", 0.003),
        SlotEntry.new("access", 0.003), SlotEntry.new("thunder", 0.003),
        SlotEntry.new("ginger", 0.002), SlotEntry.new("admin", 0.008),
        SlotEntry.new("letmein", 0.006), SlotEntry.new("mustang", 0.003),
        SlotEntry.new("secret", 0.004), SlotEntry.new("test", 0.005),
        # Common English words
        SlotEntry.new("hello", 0.004), SlotEntry.new("angel", 0.003),
        SlotEntry.new("diamond", 0.003), SlotEntry.new("orange", 0.002),
        SlotEntry.new("flower", 0.002), SlotEntry.new("tiger", 0.003),
        SlotEntry.new("silver", 0.002), SlotEntry.new("golden", 0.002),
        SlotEntry.new("purple", 0.002), SlotEntry.new("cookie", 0.002),
        SlotEntry.new("matrix", 0.002), SlotEntry.new("legend", 0.002),
        SlotEntry.new("rocket", 0.002), SlotEntry.new("guitar", 0.002),
        SlotEntry.new("ninja", 0.002), SlotEntry.new("magic", 0.002),
        SlotEntry.new("zombie", 0.002), SlotEntry.new("victor", 0.002),
        SlotEntry.new("phoenix", 0.002), SlotEntry.new("falcon", 0.002),
        SlotEntry.new("cyber", 0.002), SlotEntry.new("hacker", 0.002),
        SlotEntry.new("system", 0.002), SlotEntry.new("network", 0.001),
        SlotEntry.new("server", 0.002), SlotEntry.new("gaming", 0.002),
        SlotEntry.new("player", 0.002), SlotEntry.new("legend", 0.001),
        SlotEntry.new("super", 0.002), SlotEntry.new("power", 0.002),
        SlotEntry.new("lucky", 0.002), SlotEntry.new("happy", 0.002),
        SlotEntry.new("money", 0.002), SlotEntry.new("apple", 0.002),
        SlotEntry.new("house", 0.001), SlotEntry.new("music", 0.001),
        SlotEntry.new("black", 0.002), SlotEntry.new("white", 0.001),
        SlotEntry.new("green", 0.001), SlotEntry.new("blue", 0.001),
        SlotEntry.new("storm", 0.002), SlotEntry.new("wolf", 0.002),
        SlotEntry.new("eagle", 0.002), SlotEntry.new("ghost", 0.002),
        SlotEntry.new("night", 0.001), SlotEntry.new("dark", 0.002),
        SlotEntry.new("light", 0.001), SlotEntry.new("fire", 0.002),
        SlotEntry.new("stone", 0.001), SlotEntry.new("steel", 0.001),
        SlotEntry.new("blade", 0.001), SlotEntry.new("spark", 0.001),
        SlotEntry.new("king", 0.002), SlotEntry.new("queen", 0.002),
        SlotEntry.new("knight", 0.001), SlotEntry.new("boss", 0.001),
        SlotEntry.new("chief", 0.001), SlotEntry.new("hero", 0.001),
        SlotEntry.new("sniper", 0.001), SlotEntry.new("marine", 0.001),
        SlotEntry.new("soldier", 0.001), SlotEntry.new("warrior", 0.001),
        SlotEntry.new("samurai", 0.001), SlotEntry.new("pirate", 0.001),
        # Sports / teams
        SlotEntry.new("arsenal", 0.002), SlotEntry.new("liverpool", 0.002),
        SlotEntry.new("chelsea", 0.002), SlotEntry.new("baseball", 0.001),
        SlotEntry.new("hockey", 0.001), SlotEntry.new("tennis", 0.001),
        SlotEntry.new("lakers", 0.001), SlotEntry.new("cowboys", 0.001),
        SlotEntry.new("yankees", 0.001), SlotEntry.new("eagles", 0.001),
        # Turkish words
        SlotEntry.new("galatasaray", 0.003), SlotEntry.new("fenerbahce", 0.003),
        SlotEntry.new("besiktas", 0.002), SlotEntry.new("trabzonspor", 0.001),
        SlotEntry.new("turkiye", 0.002), SlotEntry.new("istanbul", 0.002),
        SlotEntry.new("ankara", 0.001), SlotEntry.new("antalya", 0.001),
        SlotEntry.new("izmir", 0.001), SlotEntry.new("sifre", 0.001),
        SlotEntry.new("parola", 0.001), SlotEntry.new("merhaba", 0.001),
        SlotEntry.new("sevgi", 0.001), SlotEntry.new("hayat", 0.001),
        SlotEntry.new("guzel", 0.001), SlotEntry.new("mutlu", 0.001),
        SlotEntry.new("yildiz", 0.001), SlotEntry.new("aslan", 0.001),
        SlotEntry.new("kartal", 0.001), SlotEntry.new("kurt", 0.001),
        SlotEntry.new("bozkurt", 0.001), SlotEntry.new("sahin", 0.001),
        SlotEntry.new("deniz", 0.001), SlotEntry.new("bulut", 0.001),
        SlotEntry.new("melek", 0.001), SlotEntry.new("cicek", 0.001),
        SlotEntry.new("gunes", 0.001), SlotEntry.new("yagmur", 0.001),
        # German words
        SlotEntry.new("passwort", 0.002), SlotEntry.new("geheim", 0.001),
        SlotEntry.new("liebe", 0.001), SlotEntry.new("schatz", 0.002),
        SlotEntry.new("berlin", 0.001), SlotEntry.new("bayern", 0.002),
        SlotEntry.new("dortmund", 0.001), SlotEntry.new("schalke", 0.001),
        # Russian words (transliterated)
        SlotEntry.new("parol", 0.002), SlotEntry.new("lyubov", 0.001),
        SlotEntry.new("moskva", 0.001), SlotEntry.new("rossiya", 0.001),
        SlotEntry.new("spartak", 0.002), SlotEntry.new("zenit", 0.001),
        # Arabic words (transliterated)
        SlotEntry.new("salam", 0.002), SlotEntry.new("habibi", 0.002),
        SlotEntry.new("allah", 0.002), SlotEntry.new("yalla", 0.001),
        SlotEntry.new("inshallah", 0.001), SlotEntry.new("mashallah", 0.001),
        # Tech / gaming
        SlotEntry.new("minecraft", 0.002), SlotEntry.new("fortnite", 0.002),
        SlotEntry.new("valorant", 0.002), SlotEntry.new("roblox", 0.002),
        SlotEntry.new("pokemon", 0.001), SlotEntry.new("naruto", 0.001),
        SlotEntry.new("sasuke", 0.001), SlotEntry.new("itachi", 0.001),
        SlotEntry.new("goku", 0.001), SlotEntry.new("vegeta", 0.001),
        SlotEntry.new("chrome", 0.001), SlotEntry.new("windows", 0.001),
        SlotEntry.new("linux", 0.001), SlotEntry.new("android", 0.001),
        SlotEntry.new("iphone", 0.001), SlotEntry.new("samsung", 0.001),
        SlotEntry.new("google", 0.001), SlotEntry.new("amazon", 0.001),
        SlotEntry.new("facebook", 0.001), SlotEntry.new("twitter", 0.001),
        SlotEntry.new("instagram", 0.001), SlotEntry.new("tiktok", 0.001),
        SlotEntry.new("spotify", 0.001), SlotEntry.new("netflix", 0.001),
        # Common short
        SlotEntry.new("abc", 0.002), SlotEntry.new("xyz", 0.001),
        SlotEntry.new("pass", 0.003), SlotEntry.new("pwd", 0.001),
        SlotEntry.new("god", 0.002), SlotEntry.new("sex", 0.002),
        SlotEntry.new("fuck", 0.002), SlotEntry.new("shit", 0.001),
        SlotEntry.new("damn", 0.001), SlotEntry.new("cool", 0.001),
        SlotEntry.new("real", 0.001), SlotEntry.new("true", 0.001),
        # Missing common top-200
        SlotEntry.new("butterfly", 0.004), SlotEntry.new("superman", 0.005),
        SlotEntry.new("iloveyou", 0.006), SlotEntry.new("starwars", 0.003),
        SlotEntry.new("trustno", 0.003), SlotEntry.new("whatever", 0.003),
        SlotEntry.new("freedom", 0.003), SlotEntry.new("nothing", 0.002),
        SlotEntry.new("computer", 0.002), SlotEntry.new("ginger", 0.002),
        SlotEntry.new("pokemon", 0.003), SlotEntry.new("internet", 0.002),
        SlotEntry.new("banana", 0.002), SlotEntry.new("chicken", 0.002),
        SlotEntry.new("yankee", 0.002), SlotEntry.new("dallas", 0.002),
        SlotEntry.new("ranger", 0.002), SlotEntry.new("buster", 0.003),
        SlotEntry.new("hammer", 0.002), SlotEntry.new("corvette", 0.001),
      ]

      NAMES = [
        # English male
        SlotEntry.new("james", 0.012), SlotEntry.new("john", 0.011),
        SlotEntry.new("robert", 0.010), SlotEntry.new("michael", 0.010),
        SlotEntry.new("david", 0.009), SlotEntry.new("richard", 0.007),
        SlotEntry.new("thomas", 0.007), SlotEntry.new("daniel", 0.007),
        SlotEntry.new("matthew", 0.006), SlotEntry.new("andrew", 0.006),
        SlotEntry.new("joshua", 0.005), SlotEntry.new("chris", 0.005),
        SlotEntry.new("joseph", 0.005), SlotEntry.new("william", 0.005),
        SlotEntry.new("anthony", 0.004), SlotEntry.new("mark", 0.004),
        SlotEntry.new("paul", 0.004), SlotEntry.new("steven", 0.004),
        SlotEntry.new("kevin", 0.004), SlotEntry.new("brian", 0.004),
        SlotEntry.new("jason", 0.003), SlotEntry.new("george", 0.003),
        SlotEntry.new("ryan", 0.003), SlotEntry.new("alex", 0.005),
        SlotEntry.new("adam", 0.003), SlotEntry.new("mike", 0.003),
        SlotEntry.new("nick", 0.003), SlotEntry.new("jack", 0.003),
        SlotEntry.new("eric", 0.003), SlotEntry.new("tyler", 0.003),
        SlotEntry.new("brandon", 0.003), SlotEntry.new("justin", 0.003),
        SlotEntry.new("kyle", 0.002), SlotEntry.new("jake", 0.002),
        SlotEntry.new("max", 0.002), SlotEntry.new("charlie", 0.002),
        SlotEntry.new("sam", 0.002), SlotEntry.new("ben", 0.002),
        # English female
        SlotEntry.new("jessica", 0.005), SlotEntry.new("ashley", 0.005),
        SlotEntry.new("jennifer", 0.004), SlotEntry.new("amanda", 0.004),
        SlotEntry.new("nicole", 0.004), SlotEntry.new("sarah", 0.004),
        SlotEntry.new("stephanie", 0.003), SlotEntry.new("melissa", 0.003),
        SlotEntry.new("emily", 0.003), SlotEntry.new("hannah", 0.003),
        SlotEntry.new("emma", 0.003), SlotEntry.new("rachel", 0.002),
        SlotEntry.new("laura", 0.002), SlotEntry.new("lisa", 0.002),
        SlotEntry.new("anna", 0.002), SlotEntry.new("maria", 0.003),
        SlotEntry.new("sophia", 0.002), SlotEntry.new("natalie", 0.002),
        SlotEntry.new("victoria", 0.002), SlotEntry.new("grace", 0.002),
        # Turkish male
        SlotEntry.new("ali", 0.008), SlotEntry.new("mehmet", 0.007),
        SlotEntry.new("mustafa", 0.006), SlotEntry.new("ahmet", 0.006),
        SlotEntry.new("emre", 0.005), SlotEntry.new("burak", 0.004),
        SlotEntry.new("can", 0.004), SlotEntry.new("cem", 0.003),
        SlotEntry.new("deniz", 0.003), SlotEntry.new("eren", 0.003),
        SlotEntry.new("hasan", 0.003), SlotEntry.new("huseyin", 0.003),
        SlotEntry.new("ibrahim", 0.003), SlotEntry.new("ismail", 0.003),
        SlotEntry.new("murat", 0.003), SlotEntry.new("osman", 0.003),
        SlotEntry.new("serkan", 0.002), SlotEntry.new("kemal", 0.002),
        SlotEntry.new("yusuf", 0.002), SlotEntry.new("omer", 0.003),
        SlotEntry.new("fatih", 0.003), SlotEntry.new("selim", 0.002),
        SlotEntry.new("onur", 0.002), SlotEntry.new("tolga", 0.002),
        SlotEntry.new("volkan", 0.002), SlotEntry.new("sinan", 0.002),
        SlotEntry.new("baris", 0.002), SlotEntry.new("caner", 0.002),
        SlotEntry.new("umut", 0.002), SlotEntry.new("kaan", 0.002),
        SlotEntry.new("arda", 0.002), SlotEntry.new("berk", 0.002),
        SlotEntry.new("doruk", 0.001), SlotEntry.new("efe", 0.002),
        SlotEntry.new("yigit", 0.001), SlotEntry.new("oguz", 0.001),
        SlotEntry.new("tuna", 0.001), SlotEntry.new("alp", 0.002),
        # Turkish female
        SlotEntry.new("ayse", 0.004), SlotEntry.new("fatma", 0.003),
        SlotEntry.new("elif", 0.003), SlotEntry.new("zeynep", 0.003),
        SlotEntry.new("emine", 0.002), SlotEntry.new("hatice", 0.002),
        SlotEntry.new("merve", 0.002), SlotEntry.new("esra", 0.002),
        SlotEntry.new("selin", 0.002), SlotEntry.new("busra", 0.002),
        SlotEntry.new("ece", 0.002), SlotEntry.new("irem", 0.002),
        SlotEntry.new("defne", 0.001), SlotEntry.new("beyza", 0.001),
        SlotEntry.new("nur", 0.002), SlotEntry.new("asli", 0.002),
        SlotEntry.new("gamze", 0.001), SlotEntry.new("tugba", 0.001),
        SlotEntry.new("derya", 0.001), SlotEntry.new("ceren", 0.001),
        SlotEntry.new("ebru", 0.001), SlotEntry.new("ozge", 0.001),
        SlotEntry.new("pinar", 0.001), SlotEntry.new("gizem", 0.001),
        SlotEntry.new("damla", 0.001), SlotEntry.new("dilara", 0.001),
        # German names
        SlotEntry.new("hans", 0.003), SlotEntry.new("klaus", 0.002),
        SlotEntry.new("wolfgang", 0.002), SlotEntry.new("petra", 0.002),
        SlotEntry.new("heidi", 0.002), SlotEntry.new("stefan", 0.003),
        SlotEntry.new("andreas", 0.003), SlotEntry.new("frank", 0.002),
        SlotEntry.new("sabine", 0.002), SlotEntry.new("monika", 0.002),
        # Russian names (transliterated)
        SlotEntry.new("ivan", 0.004), SlotEntry.new("dmitri", 0.003),
        SlotEntry.new("sergei", 0.003), SlotEntry.new("natasha", 0.003),
        SlotEntry.new("olga", 0.002), SlotEntry.new("vladimir", 0.002),
        SlotEntry.new("andrei", 0.003), SlotEntry.new("alexei", 0.002),
        SlotEntry.new("tatiana", 0.002), SlotEntry.new("ekaterina", 0.002),
        # Arabic names (transliterated)
        SlotEntry.new("mohammed", 0.008), SlotEntry.new("ahmed", 0.006),
        SlotEntry.new("omar", 0.004), SlotEntry.new("fatima", 0.004),
        SlotEntry.new("hassan", 0.003), SlotEntry.new("hussein", 0.003),
        SlotEntry.new("khalid", 0.002), SlotEntry.new("aisha", 0.003),
        SlotEntry.new("maryam", 0.002),
      ]

      YEARS = [
        SlotEntry.new("2026", 0.020), SlotEntry.new("2025", 0.030),
        SlotEntry.new("2024", 0.035), SlotEntry.new("2023", 0.032),
        SlotEntry.new("2022", 0.028), SlotEntry.new("2021", 0.022),
        SlotEntry.new("2020", 0.020), SlotEntry.new("2019", 0.016),
        SlotEntry.new("2018", 0.014), SlotEntry.new("2017", 0.012),
        SlotEntry.new("2016", 0.011), SlotEntry.new("2015", 0.010),
        SlotEntry.new("2014", 0.009), SlotEntry.new("2013", 0.008),
        SlotEntry.new("2012", 0.008), SlotEntry.new("2011", 0.007),
        SlotEntry.new("2010", 0.007), SlotEntry.new("2009", 0.006),
        SlotEntry.new("2008", 0.006), SlotEntry.new("2007", 0.005),
        SlotEntry.new("2006", 0.005), SlotEntry.new("2005", 0.005),
        SlotEntry.new("2004", 0.005), SlotEntry.new("2003", 0.004),
        SlotEntry.new("2002", 0.004), SlotEntry.new("2001", 0.004),
        SlotEntry.new("2000", 0.015), SlotEntry.new("1234", 0.018),
        SlotEntry.new("1999", 0.014), SlotEntry.new("1998", 0.013),
        SlotEntry.new("1997", 0.012), SlotEntry.new("1996", 0.011),
        SlotEntry.new("1995", 0.011), SlotEntry.new("1994", 0.010),
        SlotEntry.new("1993", 0.009), SlotEntry.new("1992", 0.009),
        SlotEntry.new("1991", 0.008), SlotEntry.new("1990", 0.008),
        SlotEntry.new("1989", 0.007), SlotEntry.new("1988", 0.007),
        SlotEntry.new("1987", 0.006), SlotEntry.new("1986", 0.006),
        SlotEntry.new("1985", 0.005), SlotEntry.new("1984", 0.005),
        SlotEntry.new("1983", 0.004), SlotEntry.new("1982", 0.004),
        SlotEntry.new("1981", 0.004), SlotEntry.new("1980", 0.004),
        SlotEntry.new("1979", 0.003), SlotEntry.new("1978", 0.003),
        SlotEntry.new("1977", 0.003), SlotEntry.new("1976", 0.003),
        SlotEntry.new("1975", 0.003), SlotEntry.new("1970", 0.002),
        SlotEntry.new("1907", 0.004), SlotEntry.new("1903", 0.003),
        SlotEntry.new("1905", 0.003), SlotEntry.new("1881", 0.002),
        SlotEntry.new("1923", 0.002), SlotEntry.new("1071", 0.001),
        SlotEntry.new("1453", 0.002),
      ]

      SEQ_DIGITS = [
        SlotEntry.new("1", 0.025), SlotEntry.new("2", 0.008),
        SlotEntry.new("3", 0.006), SlotEntry.new("5", 0.005),
        SlotEntry.new("7", 0.005), SlotEntry.new("0", 0.004),
        SlotEntry.new("01", 0.012), SlotEntry.new("07", 0.005),
        SlotEntry.new("10", 0.005), SlotEntry.new("11", 0.007),
        SlotEntry.new("12", 0.022), SlotEntry.new("13", 0.006),
        SlotEntry.new("21", 0.006), SlotEntry.new("22", 0.004),
        SlotEntry.new("23", 0.005), SlotEntry.new("33", 0.003),
        SlotEntry.new("34", 0.003), SlotEntry.new("42", 0.002),
        SlotEntry.new("44", 0.002), SlotEntry.new("55", 0.002),
        SlotEntry.new("66", 0.002), SlotEntry.new("69", 0.015),
        SlotEntry.new("77", 0.004), SlotEntry.new("88", 0.004),
        SlotEntry.new("99", 0.009), SlotEntry.new("00", 0.008),
        SlotEntry.new("007", 0.010), SlotEntry.new("111", 0.005),
        SlotEntry.new("123", 0.045), SlotEntry.new("143", 0.003),
        SlotEntry.new("222", 0.003), SlotEntry.new("321", 0.004),
        SlotEntry.new("333", 0.002), SlotEntry.new("420", 0.005),
        SlotEntry.new("456", 0.003), SlotEntry.new("555", 0.003),
        SlotEntry.new("666", 0.004), SlotEntry.new("777", 0.004),
        SlotEntry.new("786", 0.003), SlotEntry.new("888", 0.003),
        SlotEntry.new("911", 0.002), SlotEntry.new("999", 0.003),
        SlotEntry.new("000", 0.003),
        SlotEntry.new("1234", 0.038), SlotEntry.new("4321", 0.003),
        SlotEntry.new("1111", 0.004), SlotEntry.new("2222", 0.002),
        SlotEntry.new("4444", 0.001), SlotEntry.new("5555", 0.001),
        SlotEntry.new("6666", 0.001), SlotEntry.new("7777", 0.002),
        SlotEntry.new("8888", 0.002), SlotEntry.new("9999", 0.002),
        SlotEntry.new("0000", 0.002),
        SlotEntry.new("12345", 0.032), SlotEntry.new("54321", 0.002),
        SlotEntry.new("11111", 0.002),
        SlotEntry.new("123456", 0.028), SlotEntry.new("654321", 0.002),
        SlotEntry.new("1234567", 0.015), SlotEntry.new("12345678", 0.012),
        SlotEntry.new("123456789", 0.010),
      ]

      SYMBOLS = [
        SlotEntry.new("!", 0.340), SlotEntry.new("!!", 0.025),
        SlotEntry.new("!!!", 0.008), SlotEntry.new("!@", 0.010),
        SlotEntry.new("!@#", 0.015), SlotEntry.new("!@#$", 0.008),
        SlotEntry.new(".", 0.180), SlotEntry.new("..", 0.005),
        SlotEntry.new("@", 0.120), SlotEntry.new("@@", 0.003),
        SlotEntry.new("#", 0.085), SlotEntry.new("##", 0.003),
        SlotEntry.new("*", 0.060), SlotEntry.new("**", 0.004),
        SlotEntry.new("$", 0.050), SlotEntry.new("$$", 0.003),
        SlotEntry.new("?", 0.040), SlotEntry.new("??", 0.003),
        SlotEntry.new("_", 0.035), SlotEntry.new("-", 0.030),
        SlotEntry.new("&", 0.008), SlotEntry.new("+", 0.007),
        SlotEntry.new("~", 0.004), SlotEntry.new("^", 0.003),
        SlotEntry.new("%", 0.005),
      ]

      KEYBOARDS = [
        SlotEntry.new("qwerty", 0.120), SlotEntry.new("qwer", 0.065),
        SlotEntry.new("qwert", 0.035), SlotEntry.new("qwertyuiop", 0.020),
        SlotEntry.new("asdf", 0.055), SlotEntry.new("asdfgh", 0.030),
        SlotEntry.new("asdfghjkl", 0.015), SlotEntry.new("asd", 0.020),
        SlotEntry.new("zxcv", 0.040), SlotEntry.new("zxcvbn", 0.018),
        SlotEntry.new("zxcvbnm", 0.012), SlotEntry.new("zxc", 0.015),
        SlotEntry.new("qazwsx", 0.035), SlotEntry.new("qazwsxedc", 0.010),
        SlotEntry.new("qweasd", 0.025), SlotEntry.new("qweasdzxc", 0.008),
        SlotEntry.new("abcdef", 0.012), SlotEntry.new("abcabc", 0.005),
        SlotEntry.new("aaaaaa", 0.008), SlotEntry.new("abcd", 0.010),
        SlotEntry.new("abc123", 0.025), SlotEntry.new("aa", 0.003),
        SlotEntry.new("aaaa", 0.003), SlotEntry.new("zaq", 0.005),
      ]

      L33T_WORDS = [
        SlotEntry.new("p@ssw0rd", 0.085), SlotEntry.new("p@ss", 0.045),
        SlotEntry.new("p@55w0rd", 0.020), SlotEntry.new("p@55", 0.012),
        SlotEntry.new("@dmin", 0.035), SlotEntry.new("@dm1n", 0.015),
        SlotEntry.new("l3tme1n", 0.025), SlotEntry.new("l3tm31n", 0.010),
        SlotEntry.new("h4ck3r", 0.020), SlotEntry.new("h4ck", 0.012),
        SlotEntry.new("m@ster", 0.018), SlotEntry.new("m@st3r", 0.010),
        SlotEntry.new("s3cur1ty", 0.015), SlotEntry.new("s3cur3", 0.008),
        SlotEntry.new("r00t", 0.012), SlotEntry.new("r00tk1t", 0.005),
        SlotEntry.new("sh@dow", 0.010), SlotEntry.new("sh4d0w", 0.006),
        SlotEntry.new("dr@gon", 0.008), SlotEntry.new("dr4g0n", 0.005),
        SlotEntry.new("k1ll3r", 0.008), SlotEntry.new("t3st", 0.005),
        SlotEntry.new("s3rv3r", 0.004), SlotEntry.new("n1nja", 0.004),
        SlotEntry.new("w@rr10r", 0.003), SlotEntry.new("z3r0", 0.004),
        SlotEntry.new("ph03n1x", 0.003), SlotEntry.new("cyb3r", 0.003),
      ]

      def self.get_slot_data(slot_type : SlotType) : Array(SlotEntry)
        case slot_type
        when .lower_word?    then LOWER_WORDS
        when .upper_word?    then LOWER_WORDS.map { |e| SlotEntry.new(e.value.upcase, e.frequency) }
        when .cap_word?      then LOWER_WORDS.map { |e| SlotEntry.new(e.value.capitalize, e.frequency) }
        when .name?          then NAMES
        when .cap_name?      then NAMES.map { |e| SlotEntry.new(e.value.capitalize, e.frequency) }
        when .number?        then SEQ_DIGITS
        when .year?          then YEARS
        when .seq_digits?    then SEQ_DIGITS
        when .symbol?        then SYMBOLS
        when .symbol_suffix? then SYMBOLS
        when .keyboard?      then KEYBOARDS
        when .l33t?          then L33T_WORDS
        when .cap_l33t?      then L33T_WORDS.map { |e| SlotEntry.new(e.value.capitalize, e.frequency) }
        else                      [] of SlotEntry
        end
      end
    end
  end
end
