require "./core/ntlm"
require "./patterns/schema"
require "./patterns/frequency_data"
require "./generator/candidate_engine"

module Lxpen
  class CLI
    BANNER = <<-BANNER

    ██╗     ██╗  ██╗██████╗ ███████╗███╗   ██╗
    ██║     ╚██╗██╔╝██╔══██╗██╔════╝████╗  ██║
    ██║      ╚███╔╝ ██████╔╝█████╗  ██╔██╗ ██║
    ██║      ██╔██╗ ██╔═══╝ ██╔══╝  ██║╚██╗██║
    ███████╗██╔╝ ██╗██║     ███████╗██║ ╚████║
    ╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═══╝
    v0.4.0 — Layered Exploration Engine
    "Don't crack the password. Crack the idea."

    BANNER

    BATCH_SIZE = 8192

    def self.run(args : Array(String))
      if args.empty? || args.includes?("-h") || args.includes?("--help")
        print_help
        return
      end

      case args[0]
      when "crack"
        if args.includes?("-f") || args.includes?("--file")
          file_idx = args.index("-f") || args.index("--file")
          crack_file(args[file_idx.not_nil! + 1]?) if file_idx
        else
          crack_single(args[1]?)
        end
      when "hash"
        hash_password(args[1]?)
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
    private def self.crack_single(target_hex : String?)
      unless target_hex
        STDERR.puts "Usage: lxpen crack <NTLM_HASH>"
        return
      end

      target_hex = target_hex.downcase.strip
      unless target_hex.size == 32 && target_hex.chars.all? { |c| c.ascii_number? || ('a'..'f').includes?(c) }
        STDERR.puts "Error: Invalid NTLM hash. Expected 32 hex characters."
        return
      end

      puts BANNER
      cpus = Core::NTLM.cpu_count
      engine = Generator::CandidateEngine.new
      total = engine.count_candidates

      puts "  Target:  #{target_hex}"
      puts "  CPUs:    #{cpus}"
      puts "  Space:   #{format_number(total)} candidates"
      puts "  Mode:    C engine (#{cpus} threads)"
      puts ""
      puts "  [Cracking] Pattern-by-pattern C engine..."

      targets = Bytes.new(16)
      parsed = Core::NTLM.parse_hex(target_hex)
      16.times { |i| targets[i] = parsed[i] }

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

        found = LibLxpenCore.lxpen_crack_pattern(
          targets.to_unsafe, active.to_unsafe, 1,
          slot_strings.size,
          all_ptrs.to_unsafe, all_lens.to_unsafe, counts.to_unsafe,
          cpus, match_pw_idx.to_unsafe, match_passwords.to_unsafe, total_tried.to_unsafe
        )

        if found > 0
          elapsed = Time.instant - start
          pw = String.new(match_passwords.to_unsafe)
          tried = total_tried[0].to_i64
          print_cracked(pw, target_hex, tried, elapsed.total_seconds, "C engine (#{cpus} threads)")
          return
        end
      end

      elapsed = Time.instant - start
      tried = total_tried[0].to_i64
      puts "\r  Not found in pattern space (#{format_number(tried)} candidates in #{elapsed.total_seconds.round(2)}s)"
      puts "  Tip: Extend frequency tables with target-specific words"
    end

    # ── Multiple hashes: C engine multi-target ──
    private def self.crack_file(path : String?)
      unless path
        STDERR.puts "Usage: lxpen crack -f <FILE>"
        return
      end

      unless File.exists?(path)
        STDERR.puts "Error: File not found: #{path}"
        return
      end

      puts BANNER
      hex_hashes = File.read_lines(path).map(&.strip.downcase).reject(&.empty?)
      num_targets = hex_hashes.size
      puts "  Loaded #{num_targets} hashes from #{path}"

      cpus = Core::NTLM.cpu_count
      engine = Generator::CandidateEngine.new
      total = engine.count_candidates
      puts "  CPUs:    #{cpus}"
      puts "  Space:   #{format_number(total)} candidates"
      puts "  Mode:    Multi-target C engine (#{cpus} threads)"
      puts ""

      targets = Bytes.new(num_targets * 16)
      hex_hashes.each_with_index do |hex, i|
        next unless hex.size == 32
        parsed = Core::NTLM.parse_hex(hex)
        16.times { |b| targets[i * 16 + b] = parsed[b] }
      end

      active = Bytes.new(num_targets, 1_u8)
      match_pw_idx = Slice(Int32).new(num_targets, -1_i32)
      match_passwords = Bytes.new(num_targets * 128, 0_u8)
      total_tried = Slice(LibC::SizeT).new(1, LibC::SizeT.new(0))
      cracked = 0

      puts "  [Cracking] #{num_targets} targets, pattern-by-pattern..."
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

        found = LibLxpenCore.lxpen_crack_pattern(
          targets.to_unsafe, active.to_unsafe, num_targets,
          slot_strings.size,
          all_ptrs.to_unsafe, all_lens.to_unsafe, counts.to_unsafe,
          cpus, match_pw_idx.to_unsafe, match_passwords.to_unsafe, total_tried.to_unsafe
        )

        if found > 0
          cracked += found
          elapsed_ms = ((Time.instant - start).total_milliseconds).to_i
          num_targets.times do |t|
            if match_pw_idx[t] == 1
              pw = String.new(match_passwords.to_unsafe + t * 128)
              printf "  \e[32m✓\e[0m %-32s => %-20s (%dms)\n", hex_hashes[t], pw, elapsed_ms
              match_pw_idx[t] = 2
            end
          end
        end

        all_found = true
        num_targets.times { |t| all_found = false if active[t] == 1 }
        break if all_found
      end

      elapsed = Time.instant - start

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

    private def self.hash_password(password : String?)
      unless password
        STDERR.puts "Usage: lxpen hash <PASSWORD>"
        return
      end
      puts "#{password} => #{Core::NTLM.hex(password)}"
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
      puts "    lxpen crack <NTLM_HASH>       Crack a single hash (streaming)"
      puts "    lxpen crack -f <FILE>          Crack from file (precompute RAM)"
      puts "    lxpen hash  <PASSWORD>         Generate NTLM hash"
      puts "    lxpen bench                    Performance benchmark"
      puts "    lxpen stats                    Pattern statistics"
      puts "    lxpen -h                       Help"
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
