module Lxpen
  module Core
    struct MD4
      @state : StaticArray(UInt32, 4)
      @buffer : StaticArray(UInt8, 64)
      @buffer_pos : Int32
      @total_len : UInt64

      def initialize
        @state = StaticArray[0x67452301_u32, 0xefcdab89_u32, 0x98badcfe_u32, 0x10325476_u32]
        @buffer = StaticArray(UInt8, 64).new(0_u8)
        @buffer_pos = 0
        @total_len = 0_u64
      end

      def self.digest(data : Bytes) : StaticArray(UInt8, 16)
        md4 = new
        md4.update(data)
        md4.final_hash
      end

      def self.ntlm(password : String) : StaticArray(UInt8, 16)
        utf16le = password.encode("UTF-16LE")
        digest(utf16le)
      end

      def self.ntlm_hex(password : String) : String
        hash = ntlm(password)
        hash.join { |b| "%02x" % b }
      end

      def self.ntlm_into(password : String, output : Bytes) : Nil
        hash = ntlm(password)
        16.times { |i| output[i] = hash[i] }
      end

      def update(data : Bytes) : self
        @total_len += data.size.to_u64
        offset = 0

        if @buffer_pos > 0
          space = 64 - @buffer_pos
          copy_len = Math.min(space, data.size)
          copy_len.times { |i| @buffer[@buffer_pos + i] = data[i] }
          @buffer_pos += copy_len
          offset += copy_len

          if @buffer_pos == 64
            transform
            @buffer_pos = 0
          end
        end

        while offset + 64 <= data.size
          64.times { |i| @buffer[i] = data[offset + i] }
          transform
          offset += 64
        end

        remaining = data.size - offset
        remaining.times { |i| @buffer[@buffer_pos + i] = data[offset + i] }
        @buffer_pos += remaining

        self
      end

      def final_hash : StaticArray(UInt8, 16)
        bit_len = @total_len * 8

        @buffer[@buffer_pos] = 0x80_u8
        @buffer_pos += 1

        if @buffer_pos > 56
          (@buffer_pos...64).each { |i| @buffer[i] = 0_u8 }
          transform
          @buffer_pos = 0
        end

        (@buffer_pos...56).each { |i| @buffer[i] = 0_u8 }

        8.times do |i|
          @buffer[56 + i] = ((bit_len >> (i * 8)) & 0xff).to_u8
        end

        transform

        result = StaticArray(UInt8, 16).new(0_u8)
        4.times do |i|
          result[i * 4] = (@state[i] & 0xff).to_u8
          result[i * 4 + 1] = ((@state[i] >> 8) & 0xff).to_u8
          result[i * 4 + 2] = ((@state[i] >> 16) & 0xff).to_u8
          result[i * 4 + 3] = ((@state[i] >> 24) & 0xff).to_u8
        end

        result
      end

      private def transform
        x = StaticArray(UInt32, 16).new(0_u32)
        16.times do |i|
          x[i] = @buffer[i * 4].to_u32 |
                 (@buffer[i * 4 + 1].to_u32 << 8) |
                 (@buffer[i * 4 + 2].to_u32 << 16) |
                 (@buffer[i * 4 + 3].to_u32 << 24)
        end

        a, b, c, d = @state[0], @state[1], @state[2], @state[3]

        # Round 1
        a = r1(a, b, c, d, x[0], 3)
        d = r1(d, a, b, c, x[1], 7)
        c = r1(c, d, a, b, x[2], 11)
        b = r1(b, c, d, a, x[3], 19)
        a = r1(a, b, c, d, x[4], 3)
        d = r1(d, a, b, c, x[5], 7)
        c = r1(c, d, a, b, x[6], 11)
        b = r1(b, c, d, a, x[7], 19)
        a = r1(a, b, c, d, x[8], 3)
        d = r1(d, a, b, c, x[9], 7)
        c = r1(c, d, a, b, x[10], 11)
        b = r1(b, c, d, a, x[11], 19)
        a = r1(a, b, c, d, x[12], 3)
        d = r1(d, a, b, c, x[13], 7)
        c = r1(c, d, a, b, x[14], 11)
        b = r1(b, c, d, a, x[15], 19)

        # Round 2
        a = r2(a, b, c, d, x[0], 3)
        d = r2(d, a, b, c, x[4], 5)
        c = r2(c, d, a, b, x[8], 9)
        b = r2(b, c, d, a, x[12], 13)
        a = r2(a, b, c, d, x[1], 3)
        d = r2(d, a, b, c, x[5], 5)
        c = r2(c, d, a, b, x[9], 9)
        b = r2(b, c, d, a, x[13], 13)
        a = r2(a, b, c, d, x[2], 3)
        d = r2(d, a, b, c, x[6], 5)
        c = r2(c, d, a, b, x[10], 9)
        b = r2(b, c, d, a, x[14], 13)
        a = r2(a, b, c, d, x[3], 3)
        d = r2(d, a, b, c, x[7], 5)
        c = r2(c, d, a, b, x[11], 9)
        b = r2(b, c, d, a, x[15], 13)

        # Round 3
        a = r3(a, b, c, d, x[0], 3)
        d = r3(d, a, b, c, x[8], 9)
        c = r3(c, d, a, b, x[4], 11)
        b = r3(b, c, d, a, x[12], 15)
        a = r3(a, b, c, d, x[2], 3)
        d = r3(d, a, b, c, x[10], 9)
        c = r3(c, d, a, b, x[6], 11)
        b = r3(b, c, d, a, x[14], 15)
        a = r3(a, b, c, d, x[1], 3)
        d = r3(d, a, b, c, x[9], 9)
        c = r3(c, d, a, b, x[5], 11)
        b = r3(b, c, d, a, x[13], 15)
        a = r3(a, b, c, d, x[3], 3)
        d = r3(d, a, b, c, x[11], 9)
        c = r3(c, d, a, b, x[7], 11)
        b = r3(b, c, d, a, x[15], 15)

        @state[0] &+= a
        @state[1] &+= b
        @state[2] &+= c
        @state[3] &+= d
      end

      @[AlwaysInline]
      private def r1(a : UInt32, b : UInt32, c : UInt32, d : UInt32, x : UInt32, s : Int32) : UInt32
        f = (b & c) | ((~b) & d)
        rotate_left(a &+ f &+ x, s)
      end

      @[AlwaysInline]
      private def r2(a : UInt32, b : UInt32, c : UInt32, d : UInt32, x : UInt32, s : Int32) : UInt32
        g = (b & c) | (b & d) | (c & d)
        rotate_left(a &+ g &+ x &+ 0x5a827999_u32, s)
      end

      @[AlwaysInline]
      private def r3(a : UInt32, b : UInt32, c : UInt32, d : UInt32, x : UInt32, s : Int32) : UInt32
        h = b ^ c ^ d
        rotate_left(a &+ h &+ x &+ 0x6ed9eba1_u32, s)
      end

      @[AlwaysInline]
      private def rotate_left(value : UInt32, count : Int32) : UInt32
        (value << count) | (value >> (32 - count))
      end
    end
  end
end
