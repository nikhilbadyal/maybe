#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require 'rubygems'
require 'rubygems/version'
require 'rubygems/requirement'
require 'pathname'
require 'thread'

# Simple helper for timestamped logs
def log(message)
  puts "[#{Time.now.strftime('%H:%M:%S')}] #{message}"
end

class GemSpecLine
  attr_reader :name, :requirements, :options, :raw

  def initialize(name:, requirements:, options:, raw:)
    @name = name
    @requirements = requirements
    @options = options
    @raw = raw
  end

  def git_or_path?
    options.key?('github') || options.key?('git') || options.key?('path')
  end
end

class GemCheckResult
  attr_reader :name, :current_req, :latest_version, :status, :note

  def initialize(name:, current_req:, latest_version:, status:, note:)
    @name = name
    @current_req = current_req
    @latest_version = latest_version
    @status = status
    @note = note
  end
end

def read_gemfile(path_str)
  log "Reading Gemfile from #{path_str}"
  path = Pathname.new(path_str)
  abort("Gemfile not found: #{path}") unless path.exist?
  path.read
end

def parse_gem_lines(gemfile_content)
  log 'Parsing Gemfile for gem declarations...'
  lines = gemfile_content.each_line
  gem_lines = []

  buffer = +''
  in_multiline = false

  lines.each do |line|
    stripped = line.strip
    if stripped.start_with?('gem ')
      buffer = line.dup
      in_multiline = stripped.end_with?(',')
      unless in_multiline
        gem_lines << buffer
        buffer = +''
      end
      next
    end

    if in_multiline
      buffer << line
      in_multiline = stripped.end_with?(',')
      unless in_multiline
        gem_lines << buffer
        buffer = +''
      end
    end
  end

  if gem_lines.empty?
    gem_lines = gemfile_content.lines.select { |l| l.strip.start_with?('gem ') }
  end

  log "Found #{gem_lines.size} gem declarations"
  gem_lines.map { |raw| parse_gem_declaration(raw) }.compact
end

def parse_gem_declaration(raw_line)
  return nil if raw_line.strip.start_with?('#')

  code = raw_line.strip
  wrapper = <<~RUBY
    args = nil
    def __cap_gem__(*a, **k); [a, k]; end
    args = begin
      #{code.sub(/^gem /, '__cap_gem__ ')}
    rescue Exception => e
      e
    end
    args
  RUBY

  a, k = eval(wrapper) # rubocop:disable Security/Eval
  return nil if a.is_a?(Exception)

  name = a[0].to_s
  reqs = a[1..].select { |x| x.is_a?(String) }
  options = k.transform_keys(&:to_s)

  GemSpecLine.new(name: name, requirements: reqs, options: options, raw: raw_line)
rescue StandardError
  nil
end

def fetch_latest_version(gem_name)
  log "Fetching latest version for '#{gem_name}' from RubyGems..."
  url = URI("https://rubygems.org/api/v1/gems/#{gem_name}.json")
  res = Net::HTTP.get_response(url)
  if res.is_a?(Net::HTTPSuccess)
    data = JSON.parse(res.body)
    return data['version'].to_s if data['version']
  end

  url2 = URI("https://rubygems.org/api/v1/versions/#{gem_name}/latest.json")
  res2 = Net::HTTP.get_response(url2)
  if res2.is_a?(Net::HTTPSuccess)
    data2 = JSON.parse(res2.body)
    return data2['version'].to_s if data2['version']
  end

  nil
end

def compare_requirement_to_latest(reqs, latest_version)
  return [false, 'No latest version found'] unless latest_version

  latest = Gem::Version.new(latest_version)
  requirement =
    if reqs.nil? || reqs.empty?
      Gem::Requirement.new('>= 0')
    else
      Gem::Requirement.new(*reqs)
    end

  if requirement.satisfied_by?(latest)
    [true, 'Up to date with constraint']
  else
    [false, 'Constraint does not allow latest']
  end
rescue StandardError => e
  [false, "Comparison error: #{e.message}"]
end

def check_gems(specs, workers: 5)
  log "Checking #{specs.size} gems with #{workers} workers..."
  results = Queue.new
  tasks   = Queue.new

  # Enqueue all specs
  specs.each { |spec| tasks << spec }
  workers.times { tasks << :done } # poison pills

  threads = workers.times.map do
    Thread.new do
      loop do
        spec = tasks.pop
        break if spec == :done

        log "Worker #{Thread.current.object_id} -> #{spec.name}"

        if spec.git_or_path?
          results << GemCheckResult.new(
            name: spec.name,
            current_req: spec.requirements.join(', ').empty? ? '(none)' : spec.requirements.join(', '),
            latest_version: '(n/a for git/path)',
            status: 'unknown',
            note: 'Git/path/github-sourced gem; version not resolved from RubyGems'
          )
          next
        end

        latest = fetch_latest_version(spec.name)
        if latest.nil?
          results << GemCheckResult.new(
            name: spec.name,
            current_req: spec.requirements.join(', ').empty? ? '(none)' : spec.requirements.join(', '),
            latest_version: '(unknown)',
            status: 'unknown',
            note: 'Could not fetch latest version from RubyGems'
          )
          next
        end

        ok, note = compare_requirement_to_latest(spec.requirements, latest)
        status = ok ? 'up_to_date' : 'outdated'
        results << GemCheckResult.new(
          name: spec.name,
          current_req: spec.requirements.join(', ').empty? ? '(none)' : spec.requirements.join(', '),
          latest_version: latest,
          status: status,
          note: note
        )
      end
    end
  end

  threads.each(&:join)
  results.size.times.map { results.pop } # collect results
end

def print_report(results)
  log 'Generating report...'
  puts "\nGem version status (based on constraints in Gemfile):\n\n"

  outdated = results.select { |r| r.status == 'outdated' }
  up_to_date = results.select { |r| r.status == 'up_to_date' }
  unknown = results.select { |r| r.status == 'unknown' }

  unless outdated.empty?
    puts 'Outdated:'
    outdated.each do |r|
      puts "- #{r.name}: constraint #{r.current_req} -> latest #{r.latest_version} (#{r.note})"
    end
    puts
  end

  unless up_to_date.empty?
    puts 'Up-to-date:'
    up_to_date.each do |r|
      puts "- #{r.name}: constraint #{r.current_req} allows latest #{r.latest_version}"
    end
    puts
  end

  unless unknown.empty?
    puts 'Unknown/Skipped:'
    unknown.each do |r|
      puts "- #{r.name}: #{r.note}"
    end
  end
end

def main
  log 'Script started'
  gemfile_path = ARGV[0] || 'Gemfile'
  content = read_gemfile(gemfile_path)
  specs = parse_gem_lines(content)
  results = check_gems(specs)
  print_report(results)
  log 'Script finished'
end

if __FILE__ == $PROGRAM_NAME
  main
end
