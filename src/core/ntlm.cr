@[Link(ldflags: "#{__DIR__}/../../core/liblxpen_core.a -lpthread")]
lib LibLxpenCore
  fun lxpen_ntlm_hash(password : UInt8*, len : LibC::SizeT, out : UInt8*) : Void
  fun lxpen_ntlm_batch(passwords : UInt8**, lengths : LibC::SizeT*, count : LibC::SizeT, out : UInt8*) : Void
  fun lxpen_hash_compare(a : UInt8*, b : UInt8*) : LibC::Int
  fun lxpen_crack_batch(target : UInt8*, passwords : UInt8**, lengths : LibC::SizeT*, count : LibC::SizeT, num_threads : LibC::Int) : LibC::Int
  fun lxpen_cpu_count : LibC::Int
  fun lxpen_ram_create(capacity : LibC::SizeT) : Void*
  fun lxpen_ram_destroy(t : Void*) : Void
  fun lxpen_ram_insert(t : Void*, password : UInt8*, len : LibC::SizeT) : Void
  fun lxpen_ram_lookup(t : Void*, hash : UInt8*) : UInt8*
  fun lxpen_ram_size(t : Void*) : LibC::SizeT
  fun lxpen_ram_insert_batch(t : Void*, passwords : UInt8**, lengths : LibC::SizeT*, count : LibC::SizeT) : Void
  fun lxpen_ram_build_mt(t : Void*, passwords : UInt8**, lengths : LibC::SizeT*, count : LibC::SizeT, num_threads : LibC::Int) : Void
  fun lxpen_crack_pattern(targets : UInt8*, active : UInt8*, num_targets : LibC::Int,
                          num_slots : LibC::Int,
                          slot_values_flat : UInt8**, slot_lengths_flat : LibC::SizeT*, slot_counts : LibC::SizeT*,
                          num_threads : LibC::Int,
                          match_pw_idx : LibC::Int*, match_passwords : UInt8*, total_tried : LibC::SizeT*) : LibC::Int
end

module Lxpen
  module Core
    module NTLM
      def self.hash(password : String) : StaticArray(UInt8, 16)
        result = StaticArray(UInt8, 16).new(0_u8)
        LibLxpenCore.lxpen_ntlm_hash(password.to_unsafe, password.bytesize, result.to_unsafe)
        result
      end

      def self.hex(password : String) : String
        h = hash(password)
        h.join { |b| "%02x" % b }
      end

      def self.parse_hex(hex_str : String) : StaticArray(UInt8, 16)
        result = StaticArray(UInt8, 16).new(0_u8)
        16.times do |i|
          result[i] = hex_str[i * 2, 2].to_u8(16)
        end
        result
      end

      def self.compare(a : StaticArray(UInt8, 16), b : StaticArray(UInt8, 16)) : Bool
        LibLxpenCore.lxpen_hash_compare(a.to_unsafe, b.to_unsafe) == 1
      end

      def self.cpu_count : Int32
        LibLxpenCore.lxpen_cpu_count
      end

      def self.crack_batch(target : StaticArray(UInt8, 16), passwords : Array(String), num_threads : Int32) : Int32
        count = passwords.size
        ptrs = passwords.map(&.to_unsafe)
        lens = passwords.map { |p| LibC::SizeT.new(p.bytesize) }
        LibLxpenCore.lxpen_crack_batch(target.to_unsafe, ptrs.to_unsafe, lens.to_unsafe, count, num_threads)
      end
    end

    class RAMTable
      def initialize(capacity : Int64)
        @ptr = LibLxpenCore.lxpen_ram_create(capacity.to_u64)
      end

      def insert(password : String) : Nil
        LibLxpenCore.lxpen_ram_insert(@ptr, password.to_unsafe, password.bytesize)
      end

      def insert_batch(passwords : Array(String)) : Nil
        ptrs = passwords.map(&.to_unsafe)
        lens = passwords.map { |p| LibC::SizeT.new(p.bytesize) }
        LibLxpenCore.lxpen_ram_insert_batch(@ptr, ptrs.to_unsafe, lens.to_unsafe, passwords.size)
      end

      def build_mt(passwords : Array(String), num_threads : Int32) : Nil
        ptrs = passwords.map(&.to_unsafe)
        lens = passwords.map { |p| LibC::SizeT.new(p.bytesize) }
        LibLxpenCore.lxpen_ram_build_mt(@ptr, ptrs.to_unsafe, lens.to_unsafe, passwords.size, num_threads)
      end

      def lookup(target_hash : StaticArray(UInt8, 16)) : String?
        result = LibLxpenCore.lxpen_ram_lookup(@ptr, target_hash.to_unsafe)
        result.null? ? nil : String.new(result)
      end

      def size : UInt64
        LibLxpenCore.lxpen_ram_size(@ptr)
      end

      def destroy : Nil
        LibLxpenCore.lxpen_ram_destroy(@ptr)
      end
    end
  end
end
