# encoding: UTF-8

require 'yaml'
require 'stringex/localization'


  # NORMALIZE SCRIPT UNICODE RANGES
  #########################################################
    ##### LATIN #####
    # Basic Latin, 0000–007F. This block corresponds to ASCII.
    # Latin-1 Supplement, 0080–00FF
    # Latin Extended-A, 0100–017F
    # Latin Extended-B, 0180–024F
    # Latin Extended Additional, 1E00–1EFF
    # Alphabetic Presentation Forms (Latin ligatures) FB00–FB06
    # Halfwidth and Fullwidth Forms (fullwidth Latin letters) FF00–FF5E
    ##### OTHER SCRIPTS #####
    # Combining Diacritical Marks, 0300-036F
    # Greek, 0384-03CE
    # Cyrillic, 0400-045F
    # Armenian, 0531-0587


NORMALIZE_RANGES = [0..0x24F, 0x1E00..0x1EFF, 0xFB00..0xFB06, 0xFF00..0xFF5E, 0x0300..0x036F, 0x0384..0x03CE, 0x0400..0x045F, 0x0531..0x0587]

def charnorm(ch)
  NORMALIZE_RANGES.each do |subrange|
    return true if subrange.cover?(ch.unpack('U*0')[0])
  end
  return false
end

module Stringex
  module Unidecoder
    # Contains Unicode codepoints, loading as needed from YAML files
    CODEPOINTS = Hash.new{|h, k|
      h[k] = ::YAML.load_file(File.join(File.expand_path(File.dirname(__FILE__)), "unidecoder_data", "#{k}.yml"))
    } unless defined?(CODEPOINTS)

    class << self
      # Returns string with its UTF-8 characters transliterated to ASCII ones
      #
      # You're probably better off just using the added String#to_ascii
      def decode(string)
        string.chars.map{|char| decoded(char)}.join
      end

      # Returns character for the given Unicode codepoint
      def encode(codepoint)
        ["0x#{codepoint}".to_i(16)].pack("U")
      end

      # Returns Unicode codepoint for the given character
      def get_codepoint(character)
        "%04x" % character.unpack("U")[0]
      end

      # Returns string indicating which file (and line) contains the
      # transliteration value for the character
      def in_yaml_file(character)
        unpacked = character.unpack("U")[0]
        "#{code_group(unpacked)}.yml (line #{grouped_point(unpacked) + 2})"
      end

    private

      def decoded(character)
        if charnorm(character)
          localized(character) || from_yaml(character)
        else
          character
        end
      end

      def localized(character)
        Localization.translate(:transliterations, character)
      end

      def from_yaml(character)
        return character unless character.ord > 128
        unpacked = character.unpack("U")[0]
        CODEPOINTS[code_group(unpacked)][grouped_point(unpacked)]
      rescue
        # Hopefully this won't come up much
        # TODO: Make this note something to the user that is reportable to me perhaps
        "?"
      end

      # Returns the Unicode codepoint grouping for the given character
      def code_group(unpacked_character)
        "x%02x" % (unpacked_character >> 8)
      end

      # Returns the index of the given character in the YAML file for its codepoint group
      def grouped_point(unpacked_character)
        unpacked_character & 255
      end
    end
  end
end

module Stringex
  module StringExtensions
    module PublicInstanceMethods
      # Returns string with its UTF-8 characters transliterated to ASCII ones. Example:
      #
      #   "⠋⠗⠁⠝⠉⠑".to_ascii #=> "france"
      def to_ascii
        Stringex::Unidecoder.decode(self)
      end
    end
  end
end
