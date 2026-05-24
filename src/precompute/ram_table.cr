require "../core/ntlm"

module Lxpen
  module Precompute
    class RAMTable
      record Entry, hash : StaticArray(UInt8, 16), password : String

      getter size : Int32
      @buckets : Array(Array(Entry))
      @bucket_count : Int32

      def initialize(capacity : Int32 = 1_000_000)
        @bucket_count = next_prime(capacity)
        @buckets = Array.new(@bucket_count) { [] of Entry }
        @size = 0
      end

      def insert(password : String) : Nil
        hash = Core::NTLM.hash(password)
        idx = bucket_index(hash)
        @buckets[idx] << Entry.new(hash, password)
        @size += 1
      end

      def lookup(target_hash : StaticArray(UInt8, 16)) : String?
        idx = bucket_index(target_hash)
        @buckets[idx].each do |entry|
          return entry.password if entry.hash == target_hash
        end
        nil
      end

      def lookup_hex(hex : String) : String?
        target = Core::NTLM.parse_hex(hex)
        lookup(target)
      end

      def memory_estimate_mb : Float64
        (@size * 32.0) / (1024 * 1024)
      end

      def build_from_generator(generator : Generator::CandidateEngine, &on_progress : Int32 ->) : Nil
        count = 0
        generator.each_candidate do |candidate|
          insert(candidate)
          count += 1
          yield count if count % 100_000 == 0
        end
      end

      private def bucket_index(hash : StaticArray(UInt8, 16)) : Int32
        h = hash[0].to_u32 |
            (hash[1].to_u32 << 8) |
            (hash[2].to_u32 << 16) |
            (hash[3].to_u32 << 24)
        (h % @bucket_count).to_i32
      end

      private def next_prime(n : Int32) : Int32
        n += 1 if n.even?
        loop do
          return n if is_prime?(n)
          n += 2
        end
      end

      private def is_prime?(n : Int32) : Bool
        return false if n < 2
        return true if n < 4
        return false if n % 2 == 0 || n % 3 == 0
        i = 5
        while i * i <= n
          return false if n % i == 0 || n % (i + 2) == 0
          i += 6
        end
        true
      end
    end
  end
end
