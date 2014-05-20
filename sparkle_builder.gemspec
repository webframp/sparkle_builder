$:.unshift File.join(File.expand_path(File.dirname(__FILE__)), 'lib')

require 'sparkle_builder/version'

Gem::Specification.new do |s|
  s.name = 'sparkle_builder'
  s.version = SparkleBuilder::VERSION.version
  s.summary = 'Sparkle Builder'
  s.author = 'Chris Roberts'
  s.email = 'chris@hw-ops.com'
  s.homepage = 'https://github.com/heavywater/sparkle_builder'
  s.description = 'Build sparkle based templates'
  s.require_path = 'lib'
  s.files = Dir['**/*']

  s.add_dependency 'rails', '~> 4.0.0'
  s.add_dependency 'sparkle_formation'
  s.add_dependency 'fog'
end
