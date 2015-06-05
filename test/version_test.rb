require_relative 'test_helper'

class VersionTest < Minitest::Test

  def test_version
    version = File.read(File.expand_path('../VERSION'))
    assert_equal version, ActiveMedusa::VERSION.to_s
    assert_equal version.split('.'), ActiveMedusa::VERSION.to_a
  end

end
