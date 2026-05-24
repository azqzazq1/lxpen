require "./spec_helper"

describe "NTLM Hash" do
  it "hashes empty string correctly" do
    hex = Lxpen::Core::NTLM.hex("")
    hex.should eq("31d6cfe0d16ae931b73c59d7e0c089c0")
  end

  it "hashes 'password' correctly" do
    hex = Lxpen::Core::NTLM.hex("password")
    hex.should eq("8846f7eaee8fb117ad06bdd830b7586c")
  end

  it "hashes '123456' correctly" do
    hex = Lxpen::Core::NTLM.hex("123456")
    hex.should eq("32ed87bdb5fdc5e9cba88547376818d4")
  end

  it "parse_hex roundtrips" do
    hex = "8846f7eaee8fb117ad06bdd830b7586c"
    parsed = Lxpen::Core::NTLM.parse_hex(hex)
    result = parsed.join { |b| "%02x" % b }
    result.should eq(hex)
  end

  it "compare works" do
    a = Lxpen::Core::NTLM.hash("password")
    b = Lxpen::Core::NTLM.hash("password")
    c = Lxpen::Core::NTLM.hash("other")
    Lxpen::Core::NTLM.compare(a, b).should be_true
    Lxpen::Core::NTLM.compare(a, c).should be_false
  end
end

describe "MD5 Hash" do
  it "hashes empty string" do
    hex = Lxpen::Core::Hasher.hex("", Lxpen::HashType::MD5)
    hex.should eq("d41d8cd98f00b204e9800998ecf8427e")
  end

  it "hashes 'abc'" do
    hex = Lxpen::Core::Hasher.hex("abc", Lxpen::HashType::MD5)
    hex.should eq("900150983cd24fb0d6963f7d28e17f72")
  end

  it "hashes 'password'" do
    hex = Lxpen::Core::Hasher.hex("password", Lxpen::HashType::MD5)
    hex.should eq("5f4dcc3b5aa765d61d8327deb882cf99")
  end
end

describe "SHA-256 Hash" do
  it "hashes empty string" do
    hex = Lxpen::Core::Hasher.hex("", Lxpen::HashType::SHA256)
    hex.should eq("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
  end

  it "hashes 'abc'" do
    hex = Lxpen::Core::Hasher.hex("abc", Lxpen::HashType::SHA256)
    hex.should eq("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
  end

  it "hashes 'password'" do
    hex = Lxpen::Core::Hasher.hex("password", Lxpen::HashType::SHA256)
    hex.should eq("5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8")
  end
end

describe "HashType" do
  it "parses from string" do
    Lxpen::HashType.from_string("ntlm").should eq(Lxpen::HashType::NTLM)
    Lxpen::HashType.from_string("md5").should eq(Lxpen::HashType::MD5)
    Lxpen::HashType.from_string("sha256").should eq(Lxpen::HashType::SHA256)
    Lxpen::HashType.from_string("SHA-256").should eq(Lxpen::HashType::SHA256)
  end

  it "has correct hash sizes" do
    Lxpen::HashType::NTLM.hash_size.should eq(16)
    Lxpen::HashType::MD5.hash_size.should eq(16)
    Lxpen::HashType::SHA256.hash_size.should eq(32)
  end

  it "has correct hex sizes" do
    Lxpen::HashType::NTLM.hex_size.should eq(32)
    Lxpen::HashType::MD5.hex_size.should eq(32)
    Lxpen::HashType::SHA256.hex_size.should eq(64)
  end
end

describe "Hasher" do
  it "parse_hex roundtrips for MD5" do
    hex = "5f4dcc3b5aa765d61d8327deb882cf99"
    parsed = Lxpen::Core::Hasher.parse_hex(hex, Lxpen::HashType::MD5)
    result = parsed.join { |b| "%02x" % b }
    result.should eq(hex)
  end

  it "parse_hex roundtrips for SHA-256" do
    hex = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    parsed = Lxpen::Core::Hasher.parse_hex(hex, Lxpen::HashType::SHA256)
    result = parsed.join { |b| "%02x" % b }
    result.should eq(hex)
  end
end

describe "Patterns" do
  it "has patterns loaded" do
    Lxpen::Patterns::FrequencyData::PATTERNS.size.should be > 40
  end

  it "patterns have valid frequencies" do
    Lxpen::Patterns::FrequencyData::PATTERNS.each do |p|
      p.frequency.should be > 0.0
      p.frequency.should be <= 1.0
    end
  end

  it "has passphrase patterns" do
    names = Lxpen::Patterns::FrequencyData::PATTERNS.map(&.name)
    names.should contain("lower_lower_lower")
    names.should contain("cap_cap_cap")
    names.should contain("name_name_name")
  end

  it "has LOWER_WORDS with 200+ entries" do
    Lxpen::Patterns::FrequencyData::LOWER_WORDS.size.should be >= 200
  end

  it "has NAMES with 140+ entries" do
    Lxpen::Patterns::FrequencyData::NAMES.size.should be >= 140
  end

  it "slot data includes German/Russian/Arabic names" do
    name_values = Lxpen::Patterns::FrequencyData::NAMES.map(&.value)
    name_values.should contain("hans")
    name_values.should contain("ivan")
    name_values.should contain("mohammed")
  end

  it "slot data includes cultural words" do
    word_values = Lxpen::Patterns::FrequencyData::LOWER_WORDS.map(&.value)
    word_values.should contain("passwort")
    word_values.should contain("spartak")
    word_values.should contain("habibi")
  end
end

describe "CandidateEngine" do
  it "counts candidates > 4M" do
    engine = Lxpen::Generator::CandidateEngine.new
    engine.count_candidates.should be > 4_000_000_i64
  end

  it "each_pattern_data yields valid data" do
    engine = Lxpen::Generator::CandidateEngine.new
    count = 0
    engine.each_pattern_data do |slot_strings, pattern|
      slot_strings.size.should eq(pattern.slots.size)
      slot_strings.each { |entries| entries.size.should be > 0 }
      count += 1
    end
    count.should be > 40
  end
end

describe "CPU" do
  it "detects CPU count" do
    Lxpen::Core::NTLM.cpu_count.should be > 0
  end
end
