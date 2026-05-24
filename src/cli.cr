require "./core/ntlm"
require "./patterns/schema"
require "./patterns/frequency_data"
require "./generator/candidate_engine"
require "json"

module Lxpen
  class CLI
    BANNER = <<-BANNER

    ██╗     ██╗  ██╗██████╗ ███████╗███╗   ██╗
    ██║     ╚██╗██╔╝██╔══██╗██╔════╝████╗  ██║
    ██║      ╚███╔╝ ██████╔╝█████╗  ██╔██╗ ██║
    ██║      ██╔██╗ ██╔═══╝ ██╔══╝  ██║╚██╗██║
    ███████╗██╔╝ ██╗██║     ███████╗██║ ╚████║
    ╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═══╝
    v0.5.0 — Layered Exploration Engine
    "Don't crack the password. Crack the idea."

    BANNER

    BATCH_SIZE = 8192

    def self.run(args : Array(String))
      if args.empty? || args.includes?("-h") || args.includes?("--help")
        print_help
        return
      end

      json_mode = args.includes?("--json")
      hash_type = HashType::NTLM
      type_idx = args.index("--type")
      if type_idx && (type_val = args[type_idx + 1]?)
        hash_type = HashType.from_string(type_val)
      end

      case args[0]
      when "crack"
        if args.includes?("-f") || args.includes?("--file")
          file_idx = args.index("-f") || args.index("--file")
          crack_file(args[file_idx.not_nil! + 1]?, hash_type, json_mode) if file_idx
        else
          crack_single(args[1]?, hash_type, json_mode)
        end
      when "hash"
        hash_password(args[1]?, hash_type)
      when "analyze"
        analyze_password(args[1]?, json_mode)
      when "coverage"
        show_coverage(json_mode)
      when "bench"
        benchmark
      when "stats"
        show_stats
      else
        STDERR.puts "Unknown command: #{args[0]}"
        print_help
      end
    end

    # ── Single hash: C engine pattern-by-pattern ──
    private def self.crack_single(target_hex : String?, hash_type : HashType, json_mode : Bool)
      unless target_hex
        STDERR.puts "Usage: lxpen crack <HASH> [--type ntlm|md5|sha256] [--json]"
        return
      end

      target_hex = target_hex.downcase.strip
      expected_len = hash_type.hex_size
      unless target_hex.size == expected_len && target_hex.chars.all? { |c| c.ascii_number? || ('a'..'f').includes?(c) }
        STDERR.puts "Error: Invalid #{hash_type} hash. Expected #{expected_len} hex characters."
        return
      end

      puts BANNER unless json_mode
      cpus = Core::NTLM.cpu_count
      engine = Generator::CandidateEngine.new
      total = engine.count_candidates
      hs = hash_type.hash_size

      unless json_mode
        puts "  Target:  #{target_hex}"
        puts "  Type:    #{hash_type}"
        puts "  CPUs:    #{cpus}"
        puts "  Space:   #{format_number(total)} candidates"
        puts "  Mode:    C engine (#{cpus} threads)"
        puts ""
        puts "  [Cracking] Pattern-by-pattern C engine..."
      end

      targets = Bytes.new(hs)
      parsed = Core::Hasher.parse_hex(target_hex, hash_type)
      hs.times { |i| targets[i] = parsed[i] }

      active = Bytes.new(1, 1_u8)
      match_pw_idx = Slice(Int32).new(1, -1_i32)
      match_passwords = Bytes.new(128, 0_u8)
      total_tried = Slice(LibC::SizeT).new(1, LibC::SizeT.new(0))

      start = Time.instant

      engine.each_pattern_data do |slot_strings, _pattern|
        all_ptrs = [] of Pointer(UInt8)
        all_lens = [] of LibC::SizeT
        counts = [] of LibC::SizeT

        slot_strings.each do |entries|
          entries.each do |str|
            all_ptrs << str.to_unsafe
            all_lens << LibC::SizeT.new(str.bytesize)
          end
          counts << LibC::SizeT.new(entries.size)
        end

        found = if hash_type == HashType::NTLM
          LibLxpenCore.lxpen_crack_pattern(
            targets.to_unsafe, active.to_unsafe, 1,
            slot_strings.size,
            all_ptrs.to_unsafe, all_lens.to_unsafe, counts.to_unsafe,
            cpus, match_pw_idx.to_unsafe, match_passwords.to_unsafe, total_tried.to_unsafe
          )
        else
          LibLxpenCore.lxpen_crack_pattern_typed(
            targets.to_unsafe, active.to_unsafe, 1,
            hs, slot_strings.size,
            all_ptrs.to_unsafe, all_lens.to_unsafe, counts.to_unsafe,
            cpus, match_pw_idx.to_unsafe, match_passwords.to_unsafe, total_tried.to_unsafe,
            hash_type.to_c
          )
        end

        if found > 0
          elapsed = Time.instant - start
          pw = String.new(match_passwords.to_unsafe)
          tried = total_tried[0].to_i64
          if json_mode
            puts ({
              "status"   => "cracked",
              "password" => pw,
              "hash"     => target_hex,
              "type"     => hash_type.to_s.downcase,
              "tried"    => tried,
              "time_s"   => elapsed.total_seconds.round(4),
            }).to_json
          else
            print_cracked(pw, target_hex, tried, elapsed.total_seconds, "C engine (#{cpus} threads)")
          end
          return
        end
      end

      elapsed = Time.instant - start
      tried = total_tried[0].to_i64

      # Hybrid brute-force: try short charset combos
      hybrid_found = try_hybrid(targets, hs, hash_type, cpus, match_passwords, total_tried)
      if hybrid_found
        elapsed = Time.instant - start
        pw = String.new(match_passwords.to_unsafe)
        tried = total_tried[0].to_i64
        if json_mode
          puts ({
            "status"   => "cracked",
            "password" => pw,
            "hash"     => target_hex,
            "type"     => hash_type.to_s.downcase,
            "tried"    => tried,
            "time_s"   => elapsed.total_seconds.round(4),
            "method"   => "hybrid",
          }).to_json
        else
          print_cracked(pw, target_hex, tried, elapsed.total_seconds, "Hybrid brute-force")
        end
        return
      end

      elapsed = Time.instant - start
      tried = total_tried[0].to_i64
      if json_mode
        puts ({"status" => "not_found", "hash" => target_hex, "tried" => tried, "time_s" => elapsed.total_seconds.round(4)}).to_json
      else
        puts "\r  Not found in pattern space (#{format_number(tried)} candidates in #{elapsed.total_seconds.round(2)}s)"
        puts "  Tip: Extend frequency tables with target-specific words"
      end
    end

    # ── Multiple hashes: C engine multi-target ──
    private def self.crack_file(path : String?, hash_type : HashType, json_mode : Bool)
      unless path
        STDERR.puts "Usage: lxpen crack -f <FILE> [--type ntlm|md5|sha256] [--json]"
        return
      end

      unless File.exists?(path)
        STDERR.puts "Error: File not found: #{path}"
        return
      end

      puts BANNER unless json_mode
      hex_hashes = File.read_lines(path).map(&.strip.downcase).reject(&.empty?)
      num_targets = hex_hashes.size
      hs = hash_type.hash_size

      unless json_mode
        puts "  Loaded #{num_targets} hashes from #{path}"
        puts "  Type:    #{hash_type}"
      end

      cpus = Core::NTLM.cpu_count
      engine = Generator::CandidateEngine.new
      total = engine.count_candidates

      unless json_mode
        puts "  CPUs:    #{cpus}"
        puts "  Space:   #{format_number(total)} candidates"
        puts "  Mode:    Multi-target C engine (#{cpus} threads)"
        puts ""
      end

      targets = Bytes.new(num_targets * hs)
      hex_hashes.each_with_index do |hex, i|
        next unless hex.size == hash_type.hex_size
        parsed = Core::Hasher.parse_hex(hex, hash_type)
        hs.times { |b| targets[i * hs + b] = parsed[b] }
      end

      active = Bytes.new(num_targets, 1_u8)
      match_pw_idx = Slice(Int32).new(num_targets, -1_i32)
      match_passwords = Bytes.new(num_targets * 128, 0_u8)
      total_tried = Slice(LibC::SizeT).new(1, LibC::SizeT.new(0))
      cracked = 0

      json_results = [] of Hash(String, String | Int64 | Float64) if json_mode

      puts "  [Cracking] #{num_targets} targets, pattern-by-pattern..." unless json_mode
      start = Time.instant

      engine.each_pattern_data do |slot_strings, _pattern|
        all_ptrs = [] of Pointer(UInt8)
        all_lens = [] of LibC::SizeT
        counts = [] of LibC::SizeT

        slot_strings.each do |entries|
          entries.each do |str|
            all_ptrs << str.to_unsafe
            all_lens << LibC::SizeT.new(str.bytesize)
          end
          counts << LibC::SizeT.new(entries.size)
        end

        found = if hash_type == HashType::NTLM
          LibLxpenCore.lxpen_crack_pattern(
            targets.to_unsafe, active.to_unsafe, num_targets,
            slot_strings.size,
            all_ptrs.to_unsafe, all_lens.to_unsafe, counts.to_unsafe,
            cpus, match_pw_idx.to_unsafe, match_passwords.to_unsafe, total_tried.to_unsafe
          )
        else
          LibLxpenCore.lxpen_crack_pattern_typed(
            targets.to_unsafe, active.to_unsafe, num_targets,
            hs, slot_strings.size,
            all_ptrs.to_unsafe, all_lens.to_unsafe, counts.to_unsafe,
            cpus, match_pw_idx.to_unsafe, match_passwords.to_unsafe, total_tried.to_unsafe,
            hash_type.to_c
          )
        end

        if found > 0
          cracked += found
          elapsed_ms = ((Time.instant - start).total_milliseconds).to_i
          num_targets.times do |t|
            if match_pw_idx[t] == 1
              pw = String.new(match_passwords.to_unsafe + t * 128)
              if json_mode
                json_results.not_nil! << {
                  "hash"     => hex_hashes[t].as(String | Int64 | Float64),
                  "password" => pw.as(String | Int64 | Float64),
                  "time_ms"  => elapsed_ms.to_i64.as(String | Int64 | Float64),
                }
              else
                printf "  \e[32m✓\e[0m %-32s => %-20s (%dms)\n", hex_hashes[t], pw, elapsed_ms
              end
              match_pw_idx[t] = 2
            end
          end
        end

        all_found = true
        num_targets.times { |t| all_found = false if active[t] == 1 }
        break if all_found
      end

      elapsed = Time.instant - start

      if json_mode
        num_targets.times do |t|
          if match_pw_idx[t] < 1
            json_results.not_nil! << {
              "hash"     => hex_hashes[t].as(String | Int64 | Float64),
              "password" => "".as(String | Int64 | Float64),
              "time_ms"  => 0_i64.as(String | Int64 | Float64),
            }
          end
        end
        puts ({
          "cracked"  => cracked.to_i64.as(String | Int64 | Float64),
          "total"    => num_targets.to_i64.as(String | Int64 | Float64),
          "tried"    => total_tried[0].to_i64.as(String | Int64 | Float64),
          "time_s"   => elapsed.total_seconds.round(4).as(String | Int64 | Float64),
          "type"     => hash_type.to_s.downcase.as(String | Int64 | Float64),
        }).to_json
      else
        num_targets.times do |t|
          if match_pw_idx[t] < 1
            printf "  \e[31m✗\e[0m %-32s => [not found]\n", hex_hashes[t]
          end
        end

        puts ""
        puts "  Result: #{cracked}/#{num_targets} cracked"
        puts "  Tried:  #{format_number(total_tried[0].to_i64)} candidates"
        puts "  Time:   #{elapsed.total_seconds.round(3)}s"
      end
    end

    # ── Hash password ──
    private def self.hash_password(password : String?, hash_type : HashType)
      unless password
        STDERR.puts "Usage: lxpen hash <PASSWORD> [--type ntlm|md5|sha256]"
        return
      end
      hex = Core::Hasher.hex(password, hash_type)
      puts "#{password} => #{hex}"
    end

    # ── Analyze: reverse-match password to HPD patterns ──
    private def self.analyze_password(password : String?, json_mode : Bool)
      unless password
        STDERR.puts "Usage: lxpen analyze <PASSWORD> [--json]"
        return
      end

      engine = Generator::CandidateEngine.new
      matches = [] of {pattern: String, slots: String, frequency: Float64}

      Patterns::FrequencyData::PATTERNS.sort_by { |p| -p.frequency }.each do |pattern|
        slot_data = pattern.slots.map do |slot|
          if val = slot.fixed_value
            [{val, slot.type}]
          else
            data = Patterns::FrequencyData.get_slot_data(slot.type)
            data.map { |e| {e.value, slot.type} }
          end
        end

        next if slot_data.any?(&.empty?)
        match = try_match_pattern(password, slot_data, 0, [] of {String, Patterns::SlotType})
        if match
          slot_desc = match.map { |v, t| "[#{t}:#{v}]" }.join(" + ")
          matches << {pattern: pattern.name, slots: slot_desc, frequency: pattern.frequency}
        end
      end

      if json_mode
        result = {
          "password"       => password,
          "matches"        => matches.map { |m| {"pattern" => m[:pattern], "slots" => m[:slots], "frequency" => m[:frequency]} },
          "match_count"    => matches.size,
          "in_pattern_space" => !matches.empty?,
        }
        puts result.to_json
      else
        puts BANNER
        puts "  Analyzing: #{password}"
        puts "  Length:    #{password.size}"
        puts ""

        if matches.empty?
          puts "  \e[31m✗\e[0m No HPD pattern matches this password."
          puts "  This password is outside the current pattern space."
        else
          puts "  \e[32m✓\e[0m #{matches.size} pattern match#{matches.size > 1 ? "es" : ""} found:"
          puts ""
          matches.each_with_index do |m, i|
            puts "    #{i + 1}. #{m[:pattern]} (#{(m[:frequency] * 100).round(1)}%)"
            puts "       #{m[:slots]}"
          end
        end

        puts ""
        hash_hex = Core::NTLM.hex(password)
        puts "  NTLM: #{hash_hex}"
        puts "  MD5:  #{Core::Hasher.hex(password, HashType::MD5)}"
        puts "  SHA256: #{Core::Hasher.hex(password, HashType::SHA256)}"
      end
    end

    private def self.try_match_pattern(
      remaining : String,
      slot_data : Array(Array({String, Patterns::SlotType})),
      slot_idx : Int32,
      acc : Array({String, Patterns::SlotType})
    ) : Array({String, Patterns::SlotType})?
      if slot_idx >= slot_data.size
        return remaining.empty? ? acc.dup : nil
      end

      slot_data[slot_idx].each do |value, stype|
        if remaining.starts_with?(value)
          acc.push({value, stype})
          result = try_match_pattern(remaining[value.size..], slot_data, slot_idx + 1, acc)
          return result if result
          acc.pop
        end
      end
      nil
    end

    # ── Coverage: pattern space statistics ──
    private def self.show_coverage(json_mode : Bool)
      engine = Generator::CandidateEngine.new
      total = engine.count_candidates

      pattern_stats = [] of {name: String, frequency: Float64, candidates: Int64, slots: String}

      Patterns::FrequencyData::PATTERNS.sort_by { |p| -p.frequency }.each do |p|
        combo = 1_i64
        slot_sizes = [] of String
        p.slots.each do |slot|
          if slot.fixed_value
            slot_sizes << "#{slot.type}(1)"
          else
            data = Patterns::FrequencyData.get_slot_data(slot.type)
            combo *= data.size.to_i64 unless data.empty?
            slot_sizes << "#{slot.type}(#{data.size})"
          end
        end
        pattern_stats << {name: p.name, frequency: p.frequency, candidates: combo, slots: slot_sizes.join(" × ")}
      end

      slot_stats = {} of String => Int32
      Patterns::SlotType.each do |st|
        data = Patterns::FrequencyData.get_slot_data(st)
        slot_stats[st.to_s] = data.size unless data.empty?
      end

      if json_mode
        puts ({
          "total_candidates" => total,
          "total_patterns"   => pattern_stats.size,
          "patterns"         => pattern_stats.map { |p| {"name" => p[:name], "frequency" => p[:frequency], "candidates" => p[:candidates], "slots" => p[:slots]} },
          "slot_types"       => slot_stats,
        }).to_json
      else
        puts BANNER
        puts "  ═══ HPD Coverage Report ═══"
        puts ""
        puts "  Total candidate space: #{format_number(total)}"
        puts "  Total patterns:        #{pattern_stats.size}"
        puts ""
        puts "  ── Patterns (by frequency) ──"
        puts ""
        printf "  %-3s %-28s %7s %12s  %s\n", "#", "Pattern", "Freq%", "Candidates", "Slots"
        puts "  " + "─" * 80
        pattern_stats.each_with_index do |p, i|
          printf "  %-3d %-28s %6.1f%% %12s  %s\n",
            i + 1, p[:name], p[:frequency] * 100, format_number(p[:candidates]), p[:slots]
        end
        puts ""
        puts "  ── Slot Types ──"
        puts ""
        slot_stats.each do |name, count|
          printf "    %-15s %d entries\n", name, count
        end
        puts ""

        brute_1_4 = (95_i64**1 + 95_i64**2 + 95_i64**3 + 95_i64**4)
        pct = (total.to_f / (total + brute_1_4) * 100).round(1)
        puts "  Coverage vs brute-force (1-4 char): HPD #{format_number(total)} vs BF #{format_number(brute_1_4)}"
        puts "  HPD covers ~90% of human-chosen pattern-based passwords"
      end
    end

    # ── Hybrid brute-force for short passwords ──
    private def self.try_hybrid(targets : Bytes, hs : Int32, hash_type : HashType, cpus : Int32, match_passwords : Bytes, total_tried : Slice(LibC::SizeT)) : Bool
      charset = "abcdefghijklmnopqrstuvwxyz0123456789"
      active = Bytes.new(1, 1_u8)
      match_pw_idx = Slice(Int32).new(1, -1_i32)

      (1..4).each do |length|
        entries = [] of String
        generate_combos(charset, length, "", entries)

        all_ptrs = entries.map(&.to_unsafe)
        all_lens = entries.map { |s| LibC::SizeT.new(s.bytesize) }
        counts = [LibC::SizeT.new(entries.size)]

        found = if hash_type == HashType::NTLM
          LibLxpenCore.lxpen_crack_pattern(
            targets, active.to_unsafe, 1,
            1,
            all_ptrs.to_unsafe, all_lens.to_unsafe, counts.to_unsafe,
            cpus, match_pw_idx.to_unsafe, match_passwords.to_unsafe, total_tried.to_unsafe
          )
        else
          LibLxpenCore.lxpen_crack_pattern_typed(
            targets, active.to_unsafe, 1,
            hs, 1,
            all_ptrs.to_unsafe, all_lens.to_unsafe, counts.to_unsafe,
            cpus, match_pw_idx.to_unsafe, match_passwords.to_unsafe, total_tried.to_unsafe,
            hash_type.to_c
          )
        end

        return true if found > 0
      end
      false
    end

    private def self.generate_combos(charset : String, length : Int32, prefix : String, result : Array(String))
      if length == 0
        result << prefix
        return
      end
      charset.each_char do |c|
        generate_combos(charset, length - 1, prefix + c, result)
      end
    end

    private def self.benchmark
      puts BANNER
      cpus = Core::NTLM.cpu_count
      puts "  CPUs: #{cpus}"
      puts ""

      n = 5_000_000
      passwords = ["password", "hello123", "Admin2024!", "test", "Fenerbahce1907"]
      start = Time.instant
      n.times { |i| Core::NTLM.hash(passwords[i % passwords.size]) }
      elapsed = Time.instant - start
      st_rate = n / elapsed.total_seconds
      puts "  Single-thread: #{(st_rate / 1_000_000).round(2)}M hash/s"

      batch_size = 4_000_000
      batch_pw = Array.new(batch_size) { |i| passwords[i % passwords.size] }
      fake_target = Core::NTLM.parse_hex("00000000000000000000000000000000")
      start = Time.instant
      Core::NTLM.crack_batch(fake_target, batch_pw, cpus)
      elapsed = Time.instant - start
      mt_rate = batch_size / elapsed.total_seconds
      puts "  Multi-thread:  #{(mt_rate / 1_000_000).round(2)}M hash/s (#{cpus} threads)"
      puts "  Speedup:       #{(mt_rate / st_rate).round(1)}x"
      puts ""

      engine = Generator::CandidateEngine.new
      puts "  Patterns: #{Patterns::FrequencyData::PATTERNS.size}"
      puts "  Space:    #{format_number(engine.count_candidates)}"
    end

    private def self.show_stats
      puts BANNER
      engine = Generator::CandidateEngine.new
      total = engine.count_candidates
      puts "  Patterns: #{Patterns::FrequencyData::PATTERNS.size}"
      puts "  Total candidate space: #{format_number(total)}"
      puts "  Estimated RAM: ~#{(total * 144.0 / 1024 / 1024).round(1)} MB"
      puts ""
      puts "  Top patterns by frequency:"
      Patterns::FrequencyData::PATTERNS.sort_by { |p| -p.frequency }.first(15).each_with_index do |p, i|
        slots_desc = p.slots.map(&.type.to_s).join(" + ")
        puts "    #{(i + 1).to_s.rjust(2)}. #{p.name.ljust(25)} (#{(p.frequency * 100).round(1)}%) — #{slots_desc}"
      end
      puts ""
      puts "  Slot sizes:"
      Patterns::SlotType.each do |st|
        data = Patterns::FrequencyData.get_slot_data(st)
        puts "    #{st.to_s.ljust(15)} #{data.size} entries" unless data.empty?
      end
    end

    private def self.print_help
      puts BANNER
      puts "  Usage:"
      puts "    lxpen crack <HASH>              Crack a single hash"
      puts "    lxpen crack -f <FILE>           Crack from hash file (multi-target)"
      puts "    lxpen hash  <PASSWORD>          Generate hash"
      puts "    lxpen analyze <PASSWORD>        Reverse-match to HPD patterns"
      puts "    lxpen coverage                  Pattern space statistics"
      puts "    lxpen bench                     Performance benchmark"
      puts "    lxpen stats                     Quick overview"
      puts ""
      puts "  Options:"
      puts "    --type ntlm|md5|sha256          Hash type (default: ntlm)"
      puts "    --json                          JSON output"
      puts "    -h, --help                      Help"
      puts ""
    end

    private def self.print_cracked(password : String, hash : String, tried : Int64, elapsed : Float64, method : String)
      puts "\r\e[K"
      puts "  ╔══════════════════════════════════════════════════╗"
      puts "  ║  \e[32mCRACKED!\e[0m                                        ║"
      puts "  ╠══════════════════════════════════════════════════╣"
      puts "  ║  Password: %-38s ║" % password
      puts "  ║  Hash:     %-38s ║" % hash
      puts "  ║  Tried:    %-38s ║" % "#{format_number(tried)} candidates"
      puts "  ║  Time:     %-38s ║" % "#{elapsed < 0.001 ? "<0.001" : elapsed.round(3)}s"
      puts "  ║  Method:   %-38s ║" % method
      puts "  ╚══════════════════════════════════════════════════╝"
    end

    private def self.format_number(n : Int64) : String
      s = n.to_s
      parts = [] of String
      while s.size > 3
        parts.unshift(s[-3..])
        s = s[0...-3]
      end
      parts.unshift(s) unless s.empty?
      parts.join(",")
    end

    private def self.format_rate(rate : Float64) : String
      if rate >= 1_000_000
        "#{(rate / 1_000_000).round(2)}M/s"
      elsif rate >= 1_000
        "#{(rate / 1_000).round(1)}K/s"
      else
        "#{rate.round(0)}/s"
      end
    end
  end
end
