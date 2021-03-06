# Pulled from helper.rb because something in the test suite monkey patches benchmarking

require 'securerandom'
require_relative '../lib/licensee'

def fixtures_base
  File.expand_path 'fixtures', File.dirname(__FILE__)
end

def fixture_path(fixture)
  File.expand_path fixture, fixtures_base
end

def license_from_path(path)
  license = File.read(path, encoding: 'utf-8').match(/\A(---\n.*\n---\n+)?(.*)/m).to_a[2]
  license.sub! '[fullname]', 'Ben Balter'
  license.sub! '[year]', '2014'
  license.sub! '[email]', 'ben@github.invalid'
  license
end

# Add random words to the end of a license to test similarity tollerances
def chaos_monkey(string, count: 5)
  ipsum = %w[lorem ipsum dolor sit amet consectetur adipiscing elit]
  Random.rand(count).times do
    string << " #{ipsum[Random.rand(ipsum.length)]}"
  end
  string
end

def verify_license_file(license, chaos = false, wrap = false)
  expected = File.basename(license, '.txt')

  text = license_from_path(license)
  text = chaos_monkey(text) if chaos
  text = wrap(text, wrap) if wrap

  license_file = Licensee::Project::LicenseFile.new(text)

  detected = license_file.license
  msg = "No match for #{expected}.\n"
  matcher = Licensee::Matchers::Dice.new(license_file)
  matcher.potential_licenses.each do |potential_license|
    msg << "Potential license: #{potential_license.key}\n"
    msg << "Potential similiarity: #{potential_license.similarity(license_file)}\n"
  end
  msg << "Text: #{license_file.content_normalized}"
  assert detected, msg

  msg = "Expeceted #{expected} but got #{detected.key} for .match. "
  msg << "Confidence: #{license_file.confidence}. "
  msg << "Method: #{license_file.matcher.class}"
  assert_equal expected, detected.key, msg
end

def wrap(text, line_width = 80)
  text = text.clone
  copyright = /^#{Licensee::Matchers::Copyright::REGEX}$/i.match(text)
  if copyright
    text.gsub!(/^#{Licensee::Matchers::Copyright::REGEX}$/i, '[COPYRIGHT]')
  end
  text.gsub!(/([^\n])\n([^\n])/, '\1 \2')

  text = text.split("\n").collect do |line|
    if line.length > line_width
      line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip
    else
      line
    end
  end * "\n"
  text.gsub! '[COPYRIGHT]', "\n#{copyright}\n" if copyright
  text.strip
end
